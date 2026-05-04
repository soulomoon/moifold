# 05 Resume Old State

Use this when an old watcher state directory already exists.

## Identify state

```bash
export STATE_DIR=/workspace/artifacts/path/to/existing-state
export DOMAIN=issue-implement   # issue-planning | issue-implement | pr-review
docker exec -e STATE_DIR -e DOMAIN "$WATCHER_DOCKER_CONTAINER" bash -lc 'printf "STATE_DIR=%s DOMAIN=%s\n" "$STATE_DIR" "$DOMAIN"'
```

Required files:

- `$STATE_DIR/events.jsonl`
- `$STATE_DIR/config.json` for generated states
- `$STATE_DIR/restart-command.sh` if the state was prepared for daemon restart

## Inspect replay

```bash
docker exec -e STATE_DIR "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$WATCHER_BIN" replay-events "$STATE_DIR/events.jsonl"
'
```

If replay fails, do not append new events manually. Plan a repair first:

```bash
docker exec -e STATE_DIR "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$WATCHER_BIN" repair-invalid-state \
  --events "$STATE_DIR/events.jsonl" \
  --state-dir "$STATE_DIR"
'
```

Apply only after reviewing the planned rewrite:

```bash
docker exec -e STATE_DIR "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$WATCHER_BIN" repair-invalid-state \
  --events "$STATE_DIR/events.jsonl" \
  --state-dir "$STATE_DIR" \
  --execute
'
```

## Stop any old daemon

```bash
docker exec -e STATE_DIR -e DOMAIN "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$WATCHER_BIN" stop-daemon \
  --state-dir "$STATE_DIR" \
  --domain "$DOMAIN"
'
```

If there is no running pid but an inactive lease remains:

```bash
docker exec -e STATE_DIR "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$WATCHER_BIN" clear-runtime-lease --state-dir "$STATE_DIR"
'
```

## Resume

Preferred:

```bash
docker exec -e STATE_DIR -e DOMAIN "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
scripts/restart-watcher --state-dir "$STATE_DIR" --domain "$DOMAIN"
'
```

If the last event is a terminal `watcher_blocked` caused by a failed app-server turn and the operator wants to retry that turn:

```bash
docker exec -e STATE_DIR -e DOMAIN "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
scripts/restart-watcher \
  --state-dir "$STATE_DIR" \
  --domain "$DOMAIN" \
  --drop-blocked-tail
'
```

Fallback when no repo script is available:

```bash
docker exec -e STATE_DIR "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
"$STATE_DIR/restart-command.sh"
'
```
