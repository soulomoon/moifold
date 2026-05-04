#!/usr/bin/env bash
set -euo pipefail

env_file="${1:?usage: init-pr-review-state.sh /path/to/watcher.env}"
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
: "${PR_REVIEW_ROOT:?}"
: "${PR_NUMBER:?}"
: "${ISSUE_BRANCH:?}"
: "${WORKER_THREAD_ID:=pr-worker-$PR_NUMBER}"
: "${REVIEWER_THREAD_ID:=reviewer-$PR_NUMBER}"
: "${POLL_SECONDS:=30}"

pr_state_dir="$PR_REVIEW_ROOT/${PROJECT_KEY}__pr${PR_NUMBER}"
mkdir -p "$pr_state_dir"

events="$pr_state_dir/events.jsonl"
if [[ ! -e "$events" ]]; then
  printf '{"type":"pr_review_initialized","repoFullName":"%s","prNumber":%s,"branch":"%s","workerThreadId":"%s","reviewerThreadId":"%s"}\n' \
    "$REPO_FULL_NAME" "$PR_NUMBER" "$ISSUE_BRANCH" "$WORKER_THREAD_ID" "$REVIEWER_THREAD_ID" > "$events"
fi

cat > "$pr_state_dir/config.json" <<JSON
{
  "repoFullName": "$REPO_FULL_NAME",
  "prNumber": $PR_NUMBER,
  "branch": "$ISSUE_BRANCH",
  "threadId": "$WORKER_THREAD_ID",
  "reviewerThreadId": "$REVIEWER_THREAD_ID",
  "stateDir": "$pr_state_dir",
  "eventsPath": "$events",
  "workdir": "$TARGET_WORKDIR"
}
JSON

cat > "$pr_state_dir/restart-command.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
exec '$WATCHER_BIN' run-pr-review \\
  --events '$events' \\
  --state-dir '$pr_state_dir' \\
  --repo '$REPO_FULL_NAME' \\
  --workdir '$TARGET_WORKDIR' \\
  --app-server-host '$APP_SERVER_HOST' \\
  --app-server-port '$APP_SERVER_PORT' \\
  --app-server-path '$APP_SERVER_PATH' \\
  --poll-seconds '$POLL_SECONDS' \\
  --pid-file '$pr_state_dir/pr-review-watcher.pid' \\
  --execute \\
  --loop
SH
chmod +x "$pr_state_dir/restart-command.sh"

printf '%s\n' "$pr_state_dir"

