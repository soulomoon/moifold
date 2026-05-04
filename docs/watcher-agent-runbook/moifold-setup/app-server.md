# App Server

The watcher talks to Codex app-server over WebSocket JSON-RPC. This service belongs to the moifold runtime setup layer, not to any target project.

## Start

Default loopback command:

```bash
codex app-server --listen ws://127.0.0.1:4500
```

Record the command in the project env file:

```bash
APP_SERVER_START_COMMAND="codex app-server --listen ws://127.0.0.1:4500"
APP_SERVER_HOST=127.0.0.1
APP_SERVER_PORT=4500
APP_SERVER_PATH=/
```

If the operator uses a different port, host, path, token, or process manager, record that exact command instead.

## Verify

Default protocol check:

```bash
scripts/watcher-init/check-app-server.sh /path/to/watcher.env
```

This performs:

- TCP reachability check.
- WebSocket JSON-RPC `initialize` handshake through the Haskell watcher client.

Optional live checks:

```bash
APP_SERVER_PROBE_THREAD_ID=<existing-thread-id> scripts/watcher-init/check-app-server.sh /path/to/watcher.env
APP_SERVER_CREATE_SMOKE_THREAD=true scripts/watcher-init/check-app-server.sh /path/to/watcher.env
APP_SERVER_START_SMOKE_TURN=true scripts/watcher-init/check-app-server.sh /path/to/watcher.env
```

The optional checks verify:

- `thread/read` when `APP_SERVER_PROBE_THREAD_ID` is set.
- `thread/start` when `APP_SERVER_CREATE_SMOKE_THREAD=true`.
- `turn/start` when `APP_SERVER_START_SMOKE_TURN=true`.

Creating a smoke turn can consume model resources. Do not run it without explicit operator approval.

## Docker Smoke

`scripts/watcher-init/docker-setup-smoke.sh` uses `APP_SERVER_CHECK_MODE=tcp` with a mock listener. That proves the setup scripts and command generation are mechanically runnable in a clean container. It does not prove the real app-server protocol. Run the default protocol check above against a real app-server before starting execute loops.
