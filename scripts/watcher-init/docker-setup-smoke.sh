#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image="${WATCHER_SETUP_IMAGE:-moifold-watcher-setup:local}"
builddir="${WATCHER_DOCKER_CABAL_BUILDDIR:-/tmp/moifold-dist}"

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker is required for this smoke test\n' >&2
  exit 127
fi

docker build \
  -f "$repo_root/docker/watcher-setup/Dockerfile" \
  -t "$image" \
  "$repo_root"

docker run --rm \
  -v "$repo_root:/work/moifold" \
  -w /work/moifold \
  -e WATCHER_DOCKER_CABAL_BUILDDIR="$builddir" \
  "$image" \
  bash -lc '
set -euo pipefail

builddir="${WATCHER_DOCKER_CABAL_BUILDDIR:-/tmp/moifold-dist}"
state_root=/tmp/watcher-state-smoke
rm -rf "$state_root"
mkdir -p "$state_root"

python3 - <<'"'"'PY'"'"' &
import socket

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", 4500))
server.listen(16)

while True:
    conn, _addr = server.accept()
    conn.close()
PY
server_pid=$!
trap "kill $server_pid >/dev/null 2>&1 || true" EXIT

cabal update
cabal "--builddir=$builddir" build all
watcher_bin="$(cabal "--builddir=$builddir" list-bin moifold)"

cat > /tmp/watcher-smoke.env <<EOF
WATCHER_REPO=/work/moifold
WATCHER_BIN=$watcher_bin
REPO_FULL_NAME=example/project
TARGET_WORKDIR=/work/moifold
APP_SERVER_HOST=127.0.0.1
APP_SERVER_PORT=4500
APP_SERVER_PATH=/
APP_SERVER_CHECK_MODE=tcp
STATE_ROOT=$state_root
PLANNER_STATE_DIR=$state_root/issue-planners/example_project
IMPLEMENTERS_ROOT=$state_root/issue-implementers
PR_REVIEW_ROOT=$state_root/pr-review-watchers
ISSUE_WORKDIR_ROOT=$state_root/issue-workdirs
BRANCH_PREFIX=codex/issue-
THREAD_PREFIX=issue-worker-
POLL_SECONDS=1
MAX_PARALLEL=1
ISSUE_NUMBER=123
PR_NUMBER=456
ISSUE_BRANCH=codex/issue-123
ISSUE_WORKER_THREAD_ID=issue-worker-123
PR_WORKER_THREAD_ID=pr-worker-456
PR_REVIEWER_THREAD_ID=pr-reviewer-456
PLANNER_THREAD_ID=planner-example-project
EOF

scripts/watcher-init/check-app-server.sh /tmp/watcher-smoke.env
scripts/watcher-init/check-project-setup.sh /tmp/watcher-smoke.env

planner_state="$(scripts/watcher-init/init-issue-planning-state.sh /tmp/watcher-smoke.env)"
issue_state="$(scripts/watcher-init/init-issue-implement-state.sh /tmp/watcher-smoke.env)"
pr_state="$(scripts/watcher-init/init-pr-review-state.sh /tmp/watcher-smoke.env)"

bash -n "$planner_state/restart-command.sh"
bash -n "$issue_state/restart-command.sh"
bash -n "$pr_state/restart-command.sh"
bash -n "$planner_state/dry-run-command.sh"
bash -n "$issue_state/dry-run-command.sh"
bash -n "$pr_state/dry-run-command.sh"

"$watcher_bin" replay-events "$planner_state/events.jsonl" >/tmp/planner-replay.txt
"$watcher_bin" replay-events "$issue_state/events.jsonl" >/tmp/issue-replay.txt
"$watcher_bin" replay-events "$pr_state/events.jsonl" >/tmp/pr-replay.txt

"$watcher_bin" run-issue-planning --help >/tmp/run-issue-planning-help.txt
"$watcher_bin" run-issue-implement --help >/tmp/run-issue-implement-help.txt
"$watcher_bin" run-pr-review --help >/tmp/run-pr-review-help.txt

printf "docker watcher setup smoke passed\n"
printf "planner_state=%s\n" "$planner_state"
printf "issue_state=%s\n" "$issue_state"
printf "pr_state=%s\n" "$pr_state"
'
