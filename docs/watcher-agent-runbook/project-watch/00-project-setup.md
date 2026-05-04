# 00 Project Setup Checks

This is the first project-specific runbook. The operating agent runs it inside the persistent watcher Docker container after the `moifold` runtime is ready and before any watcher starts or resumes for a target repo.

## Environment Contract

Required credentials and access:

- `gh auth status` must succeed inside the persistent watcher container for an account with access to `REPO_FULL_NAME`.
- The account must be allowed to read issues/PRs, create or update PRs, comment on review threads, merge PRs when the PR watcher reaches merge, and close issues for issue implementer completion.
- The target checkout in `TARGET_WORKDIR` must be readable and writable inside the persistent watcher container.
- `STATE_ROOT` and all watcher state directories must be writable.
- `APP_SERVER_HOST`, `APP_SERVER_PORT`, and `APP_SERVER_PATH` must point at the app-server as reached from inside the persistent watcher container.
- `WATCHER_BIN` must be the executable path resolved during moifold setup and valid inside the persistent watcher container.

Target project dependency policy:

- The agent should detect likely dependency managers from the target checkout, but should not install by default.
- Common detected project tools include `npm`, `pnpm`, `yarn`, `cabal`, `stack`, `cargo`, `go`, `python3`, `uv`, `poetry`, `nix`, and `make`.
- Missing project tools or dependency setup commands must be reported to the operator.
- For Cabal projects, if `cabal.project` declares `with-compiler: ghc-X.Y.Z`, that exact compiler must exist inside the persistent watcher container before `cabal build all` runs. Install it with `ghcup install ghc X.Y.Z`; do not change the watcher compiler just to satisfy the target checkout.
- Dependency installation is allowed inside the persistent watcher container. The report-only pass exists to make the planned setup visible before running it, not to enforce an authorization gate.

## Agent Check Procedure

The agent should run the setup checker in report-only mode first. `/workspace/artifacts/<project>-watcher.env` is a container path:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
scripts/watcher-init/check-project-setup.sh /workspace/artifacts/<project>-watcher.env
'
```

The checker reports:

- Required base tools: `git`, `gh`, `ghcup`, `ghc`, `cabal`, `bash`, `timeout`, `python3`
- Watcher repo status and watcher binary availability
- GitHub CLI auth status
- Target project git status
- App-server TCP reachability and WebSocket initialize protocol probe
- Target project dependency entrypoints, such as `package.json`, `cabal.project`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`, `flake.nix`, or `Makefile`
- Suggested setup commands such as `npm ci`, `pnpm install --frozen-lockfile`, `ghcup install ghc X.Y.Z`, `cabal build all`, `cargo fetch`, `go mod download`, `uv sync`, or `poetry install`

Default mode must not install dependencies. The agent should summarize this to the operator:

- `ready`: whether base tools, GitHub auth, target checkout, writable state root, watcher binary, and app-server reachability are all acceptable.
- `missing_tools`: any tools the checker reports as missing.
- `services_to_start`: especially app-server if TCP reachability fails.
- `suggested_setup_commands`: dependency/build commands the checker found.
- `install_required`: whether the watcher can proceed in dry-run mode without installing dependencies, or whether the target project likely needs setup before useful implementation work can run.

After reviewing the report-only output, run the install pass:

```bash
docker exec "$WATCHER_DOCKER_CONTAINER" bash -lc '
set -euo pipefail
source /workspace/artifacts/<project>-watcher.env
cd "$WATCHER_REPO"
scripts/watcher-init/check-project-setup.sh /workspace/artifacts/<project>-watcher.env --install
'
```

After setup checks pass, continue with `01-preflight.md`.
