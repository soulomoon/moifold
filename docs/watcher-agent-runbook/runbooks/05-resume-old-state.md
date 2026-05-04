# 05 Resume Old State

Use this when an old watcher state directory already exists.

## Identify state

```bash
source /path/to/watcher.env
STATE_DIR=/workspace/artifacts/path/to/existing-state
DOMAIN=issue-implement   # issue-planning | issue-implement | pr-review
```

Required files:

- `$STATE_DIR/events.jsonl`
- `$STATE_DIR/config.json` for generated states
- `$STATE_DIR/restart-command.sh` if the state was prepared for daemon restart

## Inspect replay

```bash
"$WATCHER_BIN" replay-events "$STATE_DIR/events.jsonl"
```

If replay fails, do not append new events manually. Plan a repair first:

```bash
"$WATCHER_BIN" repair-invalid-state \
  --events "$STATE_DIR/events.jsonl" \
  --state-dir "$STATE_DIR"
```

Apply only after reviewing the planned rewrite:

```bash
"$WATCHER_BIN" repair-invalid-state \
  --events "$STATE_DIR/events.jsonl" \
  --state-dir "$STATE_DIR" \
  --execute
```

## Stop any old daemon

```bash
"$WATCHER_BIN" stop-daemon \
  --state-dir "$STATE_DIR" \
  --domain "$DOMAIN"
```

If there is no running pid but an inactive lease remains:

```bash
"$WATCHER_BIN" clear-runtime-lease --state-dir "$STATE_DIR"
```

## Resume

Preferred:

```bash
cd "$WATCHER_REPO"
scripts/restart-watcher --state-dir "$STATE_DIR" --domain "$DOMAIN"
```

If the last event is a terminal `watcher_blocked` caused by a failed app-server turn and the operator wants to retry that turn:

```bash
cd "$WATCHER_REPO"
scripts/restart-watcher \
  --state-dir "$STATE_DIR" \
  --domain "$DOMAIN" \
  --drop-blocked-tail
```

Fallback when no repo script is available:

```bash
"$STATE_DIR/restart-command.sh"
```

