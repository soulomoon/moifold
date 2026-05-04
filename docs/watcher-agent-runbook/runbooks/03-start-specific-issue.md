# 03 Start Specific Issue

Use an issue implementer watcher when the agent should implement one GitHub issue.

## Initialize state

```bash
source /path/to/watcher.env
scripts/watcher-init/init-issue-implement-state.sh /path/to/watcher.env
```

The conventional issue state directory is:

```text
$IMPLEMENTERS_ROOT/${PROJECT_KEY}__issue${ISSUE_NUMBER}
```

## Dry run one iteration

```bash
ISSUE_STATE_DIR="$IMPLEMENTERS_ROOT/${PROJECT_KEY}__issue${ISSUE_NUMBER}"

"$WATCHER_BIN" run-issue-implement \
  --events "$ISSUE_STATE_DIR/events.jsonl" \
  --state-dir "$ISSUE_STATE_DIR" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH"
```

## Start continuous execution

```bash
"$ISSUE_STATE_DIR/restart-command.sh"
```

Expected lifecycle:

1. Create or reuse PR for `$ISSUE_BRANCH`.
2. Start an issue plan turn.
3. Write/update the PR body from the issue plan.
4. Start implementation turns until complete.
5. Hand off to PR review.
6. Wait for PR merge.
7. Run post-merge final review.
8. Close the issue or restart implementation for follow-up.
