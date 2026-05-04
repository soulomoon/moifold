#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-pr-review-state.sh /path/to/watcher.env}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
load_watcher_env "$env_file"

require_env WATCHER_BIN REPO_FULL_NAME TARGET_WORKDIR APP_SERVER_HOST APP_SERVER_PORT PR_REVIEW_ROOT PR_NUMBER ISSUE_BRANCH
require_tool python3

: "${APP_SERVER_PATH:=/}"
: "${PR_WORKER_THREAD_ID:=pr-worker-$PR_NUMBER}"
: "${PR_REVIEWER_THREAD_ID:=pr-reviewer-$PR_NUMBER}"
: "${POLL_SECONDS:=30}"

PROJECT_SLUG="$(watcher_repo_slug "$REPO_FULL_NAME")"
pr_state_dir="$PR_REVIEW_ROOT/${PROJECT_SLUG}__pr${PR_NUMBER}"
mkdir -p "$pr_state_dir"

events="$pr_state_dir/events.jsonl"
write_event_if_missing "$events" \
  "$(python3 - "$REPO_FULL_NAME" "$PR_NUMBER" "$ISSUE_BRANCH" "$PR_WORKER_THREAD_ID" "$PR_REVIEWER_THREAD_ID" <<'PY'
import json
import sys

repo_full_name, pr_number, branch, worker_thread_id, reviewer_thread_id = sys.argv[1:]
print(json.dumps({
    "type": "pr_review_initialized",
    "repoFullName": repo_full_name,
    "prNumber": int(pr_number),
    "branch": branch,
    "workerThreadId": worker_thread_id,
    "reviewerThreadId": reviewer_thread_id,
}, separators=(",", ":")))
PY
)"

python3 - "$REPO_FULL_NAME" "$PR_NUMBER" "$ISSUE_BRANCH" "$PR_WORKER_THREAD_ID" "$PR_REVIEWER_THREAD_ID" "$pr_state_dir" "$events" "$TARGET_WORKDIR" > "$pr_state_dir/config.json" <<'PY'
import json
import sys

repo_full_name, pr_number, branch, thread_id, reviewer_thread_id, state_dir, events_path, workdir = sys.argv[1:]
json.dump({
    "repoFullName": repo_full_name,
    "prNumber": int(pr_number),
    "branch": branch,
    "threadId": thread_id,
    "reviewerThreadId": reviewer_thread_id,
    "stateDir": state_dir,
    "eventsPath": events_path,
    "workdir": workdir,
}, sys.stdout, indent=2)
print()
PY

write_command_script "$pr_state_dir/dry-run-command.sh" \
  "$WATCHER_BIN" run-pr-review \
  --events "$events" \
  --state-dir "$pr_state_dir" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH"

write_command_script "$pr_state_dir/restart-command.sh" \
  "$WATCHER_BIN" run-pr-review \
  --events "$events" \
  --state-dir "$pr_state_dir" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH" \
  --poll-seconds "$POLL_SECONDS" \
  --pid-file "$pr_state_dir/pr-review-watcher.pid" \
  --execute \
  --loop

printf '%s\n' "$pr_state_dir"
