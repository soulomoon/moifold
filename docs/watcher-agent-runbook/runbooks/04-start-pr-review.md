# 04 Start PR Review

Use a PR review watcher when the agent should review, fix, and merge one PR independently from an issue implementer handoff.

## Initialize state

```bash
source /path/to/watcher.env
scripts/watcher-init/init-pr-review-state.sh /path/to/watcher.env
```

The conventional PR review state directory is:

```text
$PR_REVIEW_ROOT/${PROJECT_KEY}__pr${PR_NUMBER}
```

## Dry run one iteration

```bash
PR_STATE_DIR="$PR_REVIEW_ROOT/${PROJECT_KEY}__pr${PR_NUMBER}"

"$WATCHER_BIN" run-pr-review \
  --events "$PR_STATE_DIR/events.jsonl" \
  --state-dir "$PR_STATE_DIR" \
  --repo "$REPO_FULL_NAME" \
  --workdir "$TARGET_WORKDIR" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH"
```

## Start continuous execution

```bash
"$PR_STATE_DIR/restart-command.sh"
```

Expected lifecycle:

1. Read unresolved GitHub review threads and PR review decision.
2. Start a worker turn if actionable findings exist.
3. Start reviewer turn when no unresolved findings remain.
4. Recheck mergeability and required checks.
5. Merge only after a clean reviewer outcome and clean pre-merge gate.
