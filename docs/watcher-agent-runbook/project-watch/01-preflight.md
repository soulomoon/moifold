# 01 Preflight

Run these checks inside the persistent watcher container before creating or resuming a watcher.

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env

cd "$WATCHER_REPO"

gh auth status
git -C "$TARGET_WORKDIR" status --short --untracked-files=no

timeout 30 "$WATCHER_BIN" healthcheck \
  --state-root "$STATE_ROOT" \
  --repo "$REPO_FULL_NAME" \
  --app-server-host "$APP_SERVER_HOST" \
  --app-server-port "$APP_SERVER_PORT" \
  --app-server-path "$APP_SERVER_PATH"
'
```

Rules for the operating agent:

- Never start `--execute --loop` over a running pid or active `runtime-owner.json` lease.
- Prefer a dry run first by omitting `--execute` and `--loop`.
- Keep one state directory per watcher. Do not mix planner, implementer, and PR review events.
- The first line of `events.jsonl` must be the correct `*_initialized` event for that watcher domain.
- Resume from the existing `events.jsonl` whenever it is valid. Do not create a new state directory just because the daemon stopped.
