# 02 Start Issue Planning

Use an issue planning watcher when the agent should split or manage work for a repository or a scoped set of issues.

## Initialize state

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
scripts/watcher-init/init-issue-planning-state.sh /workspace/artifacts/<project>-watcher.env
'
```

This writes:

- `$PLANNER_STATE_DIR/events.jsonl`
- `$PLANNER_STATE_DIR/config.json`
- `$PLANNER_STATE_DIR/dry-run-command.sh`
- `$PLANNER_STATE_DIR/restart-command.sh`

## Dry run one iteration

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$PLANNER_STATE_DIR/dry-run-command.sh"
'
```

## Start continuous execution

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$PLANNER_STATE_DIR/restart-command.sh"
'
```

The generated restart command uses `--execute --loop` and writes the pid file under the state directory.
Ready issues fan out into running issue implementer watchers by default.

## Fan out implementers manually

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
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
'
```
