# 02 Start Issue Planning

Use an issue planning watcher when the agent should split or manage work for a repository or a scoped set of issues.

## Initialize state

```bash
source /path/to/watcher.env
scripts/watcher-init/init-issue-planning-state.sh /path/to/watcher.env
```

This writes:

- `$PLANNER_STATE_DIR/events.jsonl`
- `$PLANNER_STATE_DIR/config.json`
- `$PLANNER_STATE_DIR/restart-command.sh`

## Dry run one iteration

```bash
"$WATCHER_BIN" run-issue-planning \
  --events "$PLANNER_STATE_DIR/events.jsonl" \
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
```

## Start continuous execution

```bash
"$PLANNER_STATE_DIR/restart-command.sh"
```

The generated restart command uses `--execute --loop`, writes the pid file under the state directory, and can fan out issue implementer children when `--start-children` is enabled.

## Fan out implementers manually

```bash
"$WATCHER_BIN" issue-fanout \
  --repo "$REPO_FULL_NAME" \
  --implementers-root "$IMPLEMENTERS_ROOT" \
  --workdir-root "$ISSUE_WORKDIR_ROOT" \
  --max-parallel "$MAX_PARALLEL" \
  --open-issues "$ISSUE_NUMBER" \
  --execute \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH" \
  --branch-prefix "$BRANCH_PREFIX" \
  --thread-prefix "$THREAD_PREFIX"
```
