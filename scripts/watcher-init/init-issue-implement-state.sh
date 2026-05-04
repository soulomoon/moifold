#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-issue-implement-state.sh /path/to/watcher.env}"
set -a
source "$env_file"
set +a

: "${WATCHER_BIN:?}"
: "${REPO_FULL_NAME:?}"
: "${PROJECT_KEY:?}"
: "${TARGET_WORKDIR:?}"
: "${APP_SERVER_HOST:?}"
: "${APP_SERVER_PORT:?}"
: "${APP_SERVER_PATH:=/}"
: "${IMPLEMENTERS_ROOT:?}"
: "${ISSUE_NUMBER:?}"
: "${ISSUE_BRANCH:=${BRANCH_PREFIX:-codex/issue-}$ISSUE_NUMBER}"
: "${WORKER_THREAD_ID:=issue-worker-$ISSUE_NUMBER}"
: "${POLL_SECONDS:=30}"

issue_state_dir="$IMPLEMENTERS_ROOT/${PROJECT_KEY}__issue${ISSUE_NUMBER}"
mkdir -p "$issue_state_dir"

events="$issue_state_dir/events.jsonl"
if [[ ! -e "$events" ]]; then
  printf '{"type":"issue_implement_initialized","repoFullName":"%s","issueNumber":%s,"branch":"%s","workerThreadId":"%s"}\n' \
    "$REPO_FULL_NAME" "$ISSUE_NUMBER" "$ISSUE_BRANCH" "$WORKER_THREAD_ID" > "$events"
fi

cat > "$issue_state_dir/config.json" <<JSON
{
  "repoFullName": "$REPO_FULL_NAME",
  "issueNumber": $ISSUE_NUMBER,
  "branch": "$ISSUE_BRANCH",
  "threadId": "$WORKER_THREAD_ID",
  "stateDir": "$issue_state_dir",
  "eventsPath": "$events",
  "workdir": "$TARGET_WORKDIR"
}
JSON

cat > "$issue_state_dir/restart-command.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
exec '$WATCHER_BIN' run-issue-implement \\
  --events '$events' \\
  --state-dir '$issue_state_dir' \\
  --repo '$REPO_FULL_NAME' \\
  --workdir '$TARGET_WORKDIR' \\
  --app-server-host '$APP_SERVER_HOST' \\
  --app-server-port '$APP_SERVER_PORT' \\
  --app-server-path '$APP_SERVER_PATH' \\
  --poll-seconds '$POLL_SECONDS' \\
  --pid-file '$issue_state_dir/issue-implement-watcher.pid' \\
  --execute \\
  --loop
SH
chmod +x "$issue_state_dir/restart-command.sh"

printf '%s\n' "$issue_state_dir"

