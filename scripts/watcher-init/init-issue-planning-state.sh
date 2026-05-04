#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-issue-planning-state.sh /path/to/watcher.env}"
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
: "${PLANNER_STATE_DIR:?}"
: "${PLANNER_THREAD_ID:?}"
: "${ISSUE_NUMBER:?}"
: "${MAX_PARALLEL:=3}"
: "${POLL_SECONDS:=30}"
: "${IMPLEMENTERS_ROOT:?}"
: "${ISSUE_WORKDIR_ROOT:?}"
: "${BRANCH_PREFIX:=codex/issue-}"
: "${THREAD_PREFIX:=issue-worker-}"

mkdir -p "$PLANNER_STATE_DIR"

events="$PLANNER_STATE_DIR/events.jsonl"
if [[ ! -e "$events" ]]; then
  printf '{"type":"issue_planning_initialized","repoFullName":"%s","maxParallel":%s,"scopeIssueNumbers":[%s]}\n' \
    "$REPO_FULL_NAME" "$MAX_PARALLEL" "$ISSUE_NUMBER" > "$events"
fi

cat > "$PLANNER_STATE_DIR/config.json" <<JSON
{
  "repoFullName": "$REPO_FULL_NAME",
  "stateDir": "$PLANNER_STATE_DIR",
  "eventsPath": "$events",
  "workdir": "$TARGET_WORKDIR",
  "plannerThreadId": "$PLANNER_THREAD_ID",
  "scopeIssueNumbers": [$ISSUE_NUMBER],
  "maxParallel": $MAX_PARALLEL
}
JSON

cat > "$PLANNER_STATE_DIR/restart-command.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
exec '$WATCHER_BIN' run-issue-planning \\
  --events '$events' \\
  --state-dir '$PLANNER_STATE_DIR' \\
  --repo '$REPO_FULL_NAME' \\
  --workdir '$TARGET_WORKDIR' \\
  --app-server-host '$APP_SERVER_HOST' \\
  --app-server-port '$APP_SERVER_PORT' \\
  --app-server-path '$APP_SERVER_PATH' \\
  --poll-seconds '$POLL_SECONDS' \\
  --pid-file '$PLANNER_STATE_DIR/issue-planning-watcher.pid' \\
  --planner-thread-id '$PLANNER_THREAD_ID' \\
  --scope-issue '$ISSUE_NUMBER' \\
  --implementers-root '$IMPLEMENTERS_ROOT' \\
  --implementer-workdir-root '$ISSUE_WORKDIR_ROOT' \\
  --branch-prefix '$BRANCH_PREFIX' \\
  --thread-prefix '$THREAD_PREFIX' \\
  --execute \\
  --loop
SH
chmod +x "$PLANNER_STATE_DIR/restart-command.sh"

printf '%s\n' "$PLANNER_STATE_DIR"

