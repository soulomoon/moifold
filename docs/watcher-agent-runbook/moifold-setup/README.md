# Moifold Setup

This layer creates the only supported watcher runtime: a long-lived Docker container that builds `moifold`, holds the toolchain, and runs all later target-project setup and watcher commands.

## Persistent Docker Runtime

Use Docker as the runtime boundary, not only as a smoke test. After this step, keep the container running and use `docker exec` for every `project-watch/` command.

Build the setup image:

```bash
docker --version
docker info
docker build \
  -f docker/watcher-setup/Dockerfile \
  -t moifold-watcher-setup:local \
  .
```

Start or reuse one persistent container:

```bash
export WATCHER_DOCKER_CONTAINER="${WATCHER_DOCKER_CONTAINER:-moifold-watcher}"
export WATCHER_HOST_ARTIFACTS="${WATCHER_HOST_ARTIFACTS:-$PWD/../}"
export WATCHER_HOST_CODEX_HOME="${WATCHER_HOST_CODEX_HOME:-$HOME/.codex}"

test -f "$WATCHER_HOST_CODEX_HOME/auth.json"

if docker ps \
  --filter "name=^/${WATCHER_DOCKER_CONTAINER}$" \
  --filter "status=running" \
  --format '{{.Names}}' | grep -qx "$WATCHER_DOCKER_CONTAINER"; then
  printf 'Reusing running watcher container: %s\n' "$WATCHER_DOCKER_CONTAINER"
elif docker ps -a \
  --filter "name=^/${WATCHER_DOCKER_CONTAINER}$" \
  --format '{{.Names}}' | grep -qx "$WATCHER_DOCKER_CONTAINER"; then
  docker start "$WATCHER_DOCKER_CONTAINER"
else
  docker run -d \
    --name "$WATCHER_DOCKER_CONTAINER" \
    --restart unless-stopped \
    -v "$PWD:/work/moifold" \
    -v "$WATCHER_HOST_ARTIFACTS:/workspace/artifacts" \
    -v "$WATCHER_HOST_CODEX_HOME:/host-codex:ro" \
    -w /work/moifold \
    moifold-watcher-setup:local \
    sleep infinity
fi

docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc 'pwd && ghc --numeric-version && cabal --numeric-version && codex --version'
```

`WATCHER_HOST_ARTIFACTS` is a host path. `/workspace/artifacts` is the matching container path used by env files and watcher state.
`WATCHER_HOST_CODEX_HOME` is the host Codex config directory mounted read-only at `/host-codex` so auth changes on the host are visible inside the container.

If reusing an older `moifold-watcher` container created before the `/host-codex` mount existed, stop and report that the container must be recreated with the auth mount before app-server turns can run. Do not fall back to a one-time copy unless the operator explicitly accepts non-live auth sync.

If Docker is unavailable, stop setup and report the exact `docker --version` and `docker info` failures. Do not continue with host setup as a substitute.

Build the watcher inside the persistent container:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
cd /work/moifold
cabal update
cabal --builddir=/tmp/moifold-dist build all
WATCHER_BIN="$(cabal --builddir=/tmp/moifold-dist list-bin moifold)"
test -x "$WATCHER_BIN"
printf "WATCHER_BIN=%s\n" "$WATCHER_BIN"
'
```

Write the printed `WATCHER_BIN` into the project env file. The path must be valid inside the container.

Optional maintainer smoke:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
cd /work/moifold
APP_SERVER_CHECK_MODE=tcp scripts/watcher-init/check-app-server.sh /workspace/artifacts/watcher-smoke.env
'
```

The existing `scripts/watcher-init/docker-setup-smoke.sh` is useful as a transient maintainer regression check, but it is not the operating runtime. Operators should not run target setup or watchers on the host after the persistent container exists.

For maintainer validation after changing setup scripts, CLI wiring, or this runbook, run `../runbook-validation.md`.

## Container Toolchain

Required tools on the watcher host:

- `docker`: build the image, keep the watcher container running, and execute commands inside it.

Required tools inside the persistent container:

- `git`: inspect the watcher repo and target checkout.
- `gh`: read and mutate GitHub issues, PRs, review threads, and merge state.
- `codex`: run the Codex app-server in the same filesystem namespace as watcher and target checkouts.
- `ghcup`: install and manage the Haskell toolchain.
- `ghc`: compile Haskell projects. It must be selected through `ghcup`.
- `cabal`: build and run the Haskell watcher executable. It must be selected through `ghcup`.
- `python3`: generate JSON event/config files from shell init scripts without unsafe string interpolation.
- POSIX shell tools: `bash`, `timeout`, `mkdir`, `chmod`, `printf`, `cat`.

GitHub auth rule:

- `gh auth status` must succeed inside the persistent container. Host `gh auth status` is not enough.
- Prefer non-interactive token handoff from the already-authenticated host CLI. Do not print the token:

```bash
gh auth status
gh auth token | docker exec -i "$WATCHER_DOCKER_CONTAINER" \
  gh auth login --hostname github.com --with-token
docker exec "$WATCHER_DOCKER_CONTAINER" gh auth status
docker exec "$WATCHER_DOCKER_CONTAINER" gh auth setup-git --hostname github.com
```

- If `gh auth token` fails on the host, stop setup and ask the operator to authenticate GitHub on the host or provide an approved token handoff method.
- The token must have enough repository access for the later target workflows: read issues/PRs, create and update PRs, comment on review threads, merge PRs when allowed, and close completed issues.
- `gh auth setup-git` is required because implementer watchers use normal `git push` over HTTPS before `gh pr create`; `gh auth status` alone does not configure Git credential lookup.

Codex CLI rule:

- `codex` is part of the persistent watcher runtime, not a target-project dependency.
- The setup image installs `@openai/codex`; if `codex --version` fails inside the container, rebuild the setup image or install Codex CLI inside the container before continuing.
- Do not run app-server on the host for normal watcher operation. Host app-server paths and container watcher paths diverge unless an operator adds explicit path mapping.

Codex auth rule:

- The container must have Codex/OpenAI auth before app-server can run turns. A plain `initialize` probe can pass without auth, but `turn/start` will fail later with API authorization errors.
- Bind-mount host Codex config read-only at `/host-codex`, then link only the required auth entries into the container Codex home. Do not print token contents:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
test -f /host-codex/auth.json
mkdir -p /root/.codex
rm -f /root/.codex/auth.json
ln -s /host-codex/auth.json /root/.codex/auth.json
if test -d /host-codex/accounts; then
  rm -rf /root/.codex/accounts
  ln -s /host-codex/accounts /root/.codex/accounts
fi
test -f /root/.codex/auth.json
codex --version
'
```

- If host Codex auth is unavailable, stop setup and ask the operator to authenticate Codex on the host or provide an approved non-interactive auth mechanism for the container.
- Treat `/host-codex/auth.json`, `/host-codex/accounts/`, `/root/.codex/auth.json`, and `/root/.codex/accounts/` as secrets. Do not include their contents in logs, issue comments, or handoff text.
- Do not bind-mount the host `~/.codex` directly over `/root/.codex`: app-server writes state databases and logs under `/root/.codex`, and sharing those writable files with the host can corrupt state or create cross-process contention.

Haskell toolchain rule:

- Prefer `ghcup` for both `ghc` and `cabal`.
- If `ghc` or `cabal` is missing inside the container, rebuild the setup image or install through `ghcup` inside the container, for example:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
ghcup install ghc recommended
ghcup set ghc recommended
ghcup install cabal recommended
ghcup set cabal recommended
'
```

- If `ghc` or `cabal` exists outside the ghcup path inside the container, the agent should report that as a warning before proceeding.
- The watcher compiler and target-project compiler are separate concerns. Keep the watcher build on the setup image compiler unless there is a watcher-specific reason to change it. If the target checkout declares a different Cabal compiler, for example `with-compiler: ghc-9.14.1`, install that exact compiler in the persistent container with `ghcup install ghc 9.14.1` during project setup.

Build the watcher only inside the persistent container:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
cd /work/moifold
cabal update
cabal --builddir=/tmp/moifold-dist build all
WATCHER_BIN="$(cabal --builddir=/tmp/moifold-dist list-bin moifold)"
test -x "$WATCHER_BIN"
printf "%s\n" "$WATCHER_BIN"
'
```

Write the resolved `WATCHER_BIN` value into the project env file used by `project-watch/`.

## App Server

Codex app-server is part of the `moifold` runtime, not the target project setup. Start it during moifold setup inside the persistent watcher container so watcher commands and app-server threads see the same container paths.

Start one loopback app-server inside the persistent container:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
APP_SERVER_HOST="${APP_SERVER_HOST:-127.0.0.1}"
APP_SERVER_PORT="${APP_SERVER_PORT:-4500}"
mkdir -p /workspace/artifacts/app-server
if nc -z "$APP_SERVER_HOST" "$APP_SERVER_PORT" >/dev/null 2>&1; then
  printf "app-server already listening at %s:%s\n" "$APP_SERVER_HOST" "$APP_SERVER_PORT"
else
  cd /workspace/artifacts
  nohup codex app-server --listen "ws://${APP_SERVER_HOST}:${APP_SERVER_PORT}" \
    >/workspace/artifacts/app-server/codex-app-server.log 2>&1 &
  printf "%s\n" "$!" >/workspace/artifacts/app-server/codex-app-server.pid
  printf "started app-server pid %s cwd %s\n" \
    "$(cat /workspace/artifacts/app-server/codex-app-server.pid)" "$PWD"
fi
'
```

The watcher sends explicit `cwd` values in `thread/start` and `turn/start`, so the app-server process cwd is only the runtime default. Starting it from `/workspace/artifacts` keeps all mounted artifact paths visible.

Before any watcher runs in execute mode:

- Codex app-server must already be running inside the persistent container and reachable at `APP_SERVER_HOST:APP_SERVER_PORT` and `APP_SERVER_PATH`.
- Prefer `APP_SERVER_HOST=127.0.0.1` when app-server runs inside the same container.
- If an operator deliberately runs app-server on the host, use `APP_SERVER_HOST=host.docker.internal` on Docker Desktop and ensure every app-server cwd/thread workdir uses host-visible paths, not container-only paths.
- The app-server must support the thread/turn protocol used by `moifold`: create/read threads, start turns, and return structured turn output.
- Watchers will not start useful work without app-server reachability, because implementation, planning, review, and final review work all run as app-server turns.

After writing a project env file, verify the already-running app-server from inside the same container:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
cd /work/moifold
scripts/watcher-init/check-app-server.sh /workspace/artifacts/<project>-watcher.env
'
```

For a stronger live smoke that mutates app-server state:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
cd /work/moifold
APP_SERVER_CREATE_SMOKE_THREAD=true scripts/watcher-init/check-app-server.sh /workspace/artifacts/<project>-watcher.env
APP_SERVER_START_SMOKE_TURN=true scripts/watcher-init/check-app-server.sh /workspace/artifacts/<project>-watcher.env
'
```

Creating a smoke turn can consume model resources. Use it only after the operator approves a live protocol smoke.

The agent should report the app-server endpoint, how it was started, whether the WebSocket initialize probe passed, and whether optional `thread/read`, `thread/start`, or `turn/start` probes were run. If the app-server is unavailable, stop before starting project watchers.

Details: `app-server.md`.

After this layer is ready, continue with `../project-watch/README.md`.
