#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-issue-implement-state.sh /path/to/watcher.env}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
load_watcher_env "$env_file"

require_env WATCHER_BIN REPO_FULL_NAME TARGET_WORKDIR APP_SERVER_HOST APP_SERVER_PORT IMPLEMENTERS_ROOT ISSUE_NUMBER
require_tool python3

: "${APP_SERVER_PATH:=/}"
: "${ISSUE_BRANCH:=${BRANCH_PREFIX:-codex/issue-}$ISSUE_NUMBER}"
: "${ISSUE_WORKER_THREAD_ID:=issue-worker-$ISSUE_NUMBER}"
: "${POLL_SECONDS:=30}"

PROJECT_SLUG="$(watcher_repo_slug "$REPO_FULL_NAME")"
issue_state_dir="$IMPLEMENTERS_ROOT/${PROJECT_SLUG}__issue${ISSUE_NUMBER}"
mkdir -p "$issue_state_dir"

events="$issue_state_dir/events.jsonl"
write_event_if_missing "$events" \
  "$(python3 - "$REPO_FULL_NAME" "$ISSUE_NUMBER" "$ISSUE_BRANCH" "$ISSUE_WORKER_THREAD_ID" <<'PY'
import json
import sys

repo_full_name, issue_number, branch, worker_thread_id = sys.argv[1:]
print(json.dumps({
    "type": "issue_implement_initialized",
    "repoFullName": repo_full_name,
    "issueNumber": int(issue_number),
    "branch": branch,
    "workerThreadId": worker_thread_id,
}, separators=(",", ":")))
PY
)"

python3 - "$REPO_FULL_NAME" "$ISSUE_NUMBER" "$ISSUE_BRANCH" "$ISSUE_WORKER_THREAD_ID" "$issue_state_dir" "$events" "$TARGET_WORKDIR" > "$issue_state_dir/config.json" <<'PY'
import json
import sys

repo_full_name, issue_number, branch, thread_id, state_dir, events_path, workdir = sys.argv[1:]
json.dump({
    "repoFullName": repo_full_name,
    "issueNumber": int(issue_number),
    "branch": branch,
    "threadId": thread_id,
    "stateDir": state_dir,
    "eventsPath": events_path,
    "workdir": workdir,
}, sys.stdout, indent=2)
print()
PY

write_command_script "$issue_state_dir/dry-run-command.sh" \
  "$WATCHER_BIN" run-issue-implement \
  --events "$events" \
  --state-dir "$issue_state_dir" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH"

write_command_script "$issue_state_dir/restart-command.sh" \
  "$WATCHER_BIN" run-issue-implement \
  --events "$events" \
  --state-dir "$issue_state_dir" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH" \
  --poll-seconds "$POLL_SECONDS" \
  --pid-file "$issue_state_dir/issue-implement-watcher.pid" \
  --execute \
  --loop

printf '%s\n' "$issue_state_dir"
