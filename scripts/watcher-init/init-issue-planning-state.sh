#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-issue-planning-state.sh /path/to/watcher.env}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"
load_watcher_env "$env_file"

require_env WATCHER_BIN REPO_FULL_NAME TARGET_WORKDIR APP_SERVER_HOST APP_SERVER_PORT PLANNER_THREAD_ID ISSUE_NUMBER IMPLEMENTERS_ROOT ISSUE_WORKDIR_ROOT
require_tool python3

: "${APP_SERVER_PATH:=/}"
: "${STATE_ROOT:=/workspace/artifacts}"
: "${MAX_PARALLEL:=3}"
: "${POLL_SECONDS:=30}"
: "${BRANCH_PREFIX:=codex/issue-}"
: "${THREAD_PREFIX:=issue-worker-}"

PROJECT_SLUG="$(watcher_repo_slug "$REPO_FULL_NAME")"
: "${PLANNER_STATE_DIR:=$STATE_ROOT/issue-planners/$PROJECT_SLUG}"

mkdir -p "$PLANNER_STATE_DIR"

events="$PLANNER_STATE_DIR/events.jsonl"
write_event_if_missing "$events" \
  "$(python3 - "$REPO_FULL_NAME" "$MAX_PARALLEL" "$ISSUE_NUMBER" <<'PY'
import json
import sys

repo_full_name, max_parallel, issue_number = sys.argv[1:]
print(json.dumps({
    "type": "issue_planning_initialized",
    "repoFullName": repo_full_name,
    "maxParallel": int(max_parallel),
    "scopeIssueNumbers": [int(issue_number)],
}, separators=(",", ":")))
PY
)"

python3 - "$REPO_FULL_NAME" "$PLANNER_STATE_DIR" "$events" "$TARGET_WORKDIR" "$PLANNER_THREAD_ID" "$ISSUE_NUMBER" "$MAX_PARALLEL" > "$PLANNER_STATE_DIR/config.json" <<'PY'
import json
import sys

repo_full_name, state_dir, events_path, workdir, planner_thread_id, issue_number, max_parallel = sys.argv[1:]
json.dump({
    "repoFullName": repo_full_name,
    "stateDir": state_dir,
    "eventsPath": events_path,
    "workdir": workdir,
    "plannerThreadId": planner_thread_id,
    "scopeIssueNumbers": [int(issue_number)],
    "maxParallel": int(max_parallel),
}, sys.stdout, indent=2)
print()
PY

write_command_script "$PLANNER_STATE_DIR/dry-run-command.sh" \
  "$WATCHER_BIN" run-issue-planning \
  --events "$events" \
  --state-dir "$PLANNER_STATE_DIR" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH" \
  --planner-thread-id "$PLANNER_THREAD_ID" \
  --scope-issue "$ISSUE_NUMBER" \
  --implementers-root "$IMPLEMENTERS_ROOT" \
  --implementer-workdir-root "$ISSUE_WORKDIR_ROOT" \
  --branch-prefix "$BRANCH_PREFIX" \
  --thread-prefix "$THREAD_PREFIX"

write_command_script "$PLANNER_STATE_DIR/restart-command.sh" \
  "$WATCHER_BIN" run-issue-planning \
  --events "$events" \
  --state-dir "$PLANNER_STATE_DIR" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH" \
  --poll-seconds "$POLL_SECONDS" \
  --pid-file "$PLANNER_STATE_DIR/issue-planning-watcher.pid" \
  --planner-thread-id "$PLANNER_THREAD_ID" \
  --scope-issue "$ISSUE_NUMBER" \
  --implementers-root "$IMPLEMENTERS_ROOT" \
  --implementer-workdir-root "$ISSUE_WORKDIR_ROOT" \
  --branch-prefix "$BRANCH_PREFIX" \
  --thread-prefix "$THREAD_PREFIX" \
  --execute \
  --loop

printf '%s\n' "$PLANNER_STATE_DIR"
