# 00 Setup Checks

This is the first runbook. The operating agent runs it before any watcher starts or resumes.

## Docker Setup Smoke

Use Docker as the preferred reproducible setup test before relying on host state. This validates the instruction flow from a clean image:

- Install OS-level build dependencies.
- Install `gh`.
- Install `ghcup`.
- Install and select `ghc` and `cabal` through `ghcup`.
- Build the watcher with `cabal`.
- Start a local mock app-server TCP listener.
- Run `check-project-setup.sh` in check-only mode.
- Generate planner, issue implementer, and PR review watcher state directories.
- Validate generated `restart-command.sh` syntax.
- Replay the initial event logs.
- Verify the watcher loop commands are available.

Run:

```bash
scripts/watcher-init/docker-setup-smoke.sh
```

This smoke test proves the setup scripts and instructions are mechanically runnable in a clean container. It does not replace a live end-to-end run against real GitHub and a real Codex app-server protocol implementation. The mock app-server only proves that setup can detect a reachable service port.

## Environment Contract

Required tools on the watcher host:

- `git`: inspect and operate on the target checkout.
- `gh`: read and mutate GitHub issues, PRs, review threads, and merge state.
- `ghcup`: install and manage the Haskell toolchain.
- `ghc`: compile the Haskell watcher. It should be installed and selected with `ghcup`.
- `cabal`: build and run the Haskell watcher executable. It should be installed and selected with `ghcup`.
- POSIX shell tools: `bash`, `timeout`, `mkdir`, `chmod`, `printf`, `cat`.
- `docker`: run the clean setup smoke. Host watcher execution can still proceed without Docker if the operator explicitly accepts skipping the smoke.

Required credentials and access:

- `gh auth status` must succeed for an account with access to `REPO_FULL_NAME`.
- The account must be allowed to read issues/PRs, create or update PRs, comment on review threads, merge PRs when the PR watcher reaches merge, and close issues for issue implementer completion.
- The target checkout in `TARGET_WORKDIR` must be readable and writable by the watcher process.
- `STATE_ROOT` and all watcher state directories must be writable.

Required service before watcher execution:

- Codex app-server must already be running and reachable at `APP_SERVER_HOST:APP_SERVER_PORT` and `APP_SERVER_PATH`.
- The app-server must support the thread/turn protocol used by `moifold`: create/read threads, start turns, and return structured turn output.
- Watchers will not start useful work without app-server reachability, because implementation, planning, review, and final review work all run as app-server turns.

Target project dependency policy:

- The agent should detect likely dependency managers from the target checkout, but should not install by default.
- Common detected project tools include `npm`, `pnpm`, `yarn`, `cabal`, `stack`, `cargo`, `go`, `python3`, `uv`, `poetry`, `nix`, and `make`.
- Missing project tools or dependency setup commands must be reported to the operator.
- Dependency installation requires an explicit operator decision.

## Agent Check Procedure

The agent should run the setup checker in report-only mode first:

```bash
set -euo pipefail
source /path/to/watcher.env

cd "$WATCHER_REPO"
cabal build all
WATCHER_BIN="${WATCHER_BIN:-$(cabal list-bin moifold)}"

scripts/watcher-init/check-project-setup.sh /path/to/watcher.env
```

The checker reports:

- Required base tools: `git`, `gh`, `ghcup`, `ghc`, `cabal`, `bash`, `timeout`
- Watcher repo status and watcher binary availability
- GitHub CLI auth status
- Target project git status
- App-server TCP reachability
- Target project dependency entrypoints, such as `package.json`, `cabal.project`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`, `flake.nix`, or `Makefile`
- Suggested setup commands such as `npm ci`, `pnpm install --frozen-lockfile`, `cabal build all`, `cargo fetch`, `go mod download`, `uv sync`, or `poetry install`

Haskell toolchain rule:

- Prefer `ghcup` for both `ghc` and `cabal`.
- If `ghc` or `cabal` is missing, install through `ghcup`, for example:

```bash
ghcup install ghc recommended
ghcup set ghc recommended
ghcup install cabal recommended
ghcup set cabal recommended
```

- If `ghc` or `cabal` exists outside the ghcup path, the agent should report that as a warning before proceeding.

Default mode must not install dependencies. The agent should summarize this to the operator:

- `ready`: whether base tools, GitHub auth, target checkout, writable state root, watcher binary/build, and app-server reachability are all acceptable.
- `missing_tools`: any tools the checker reports as missing.
- `services_to_start`: especially app-server if TCP reachability fails.
- `suggested_setup_commands`: dependency/build commands the checker found.
- `install_required`: whether the watcher can proceed in dry-run mode without installing dependencies, or whether the target project likely needs setup before useful implementation work can run.

Only after the operator decides installation is allowed:

1. Set `ALLOW_DEPENDENCY_INSTALL=true` in the project env file.
2. Run:

```bash
scripts/watcher-init/check-project-setup.sh /path/to/watcher.env --install
```

If `ALLOW_DEPENDENCY_INSTALL` is not set to `true`, `--install` exits without running setup commands.

After setup checks pass, continue with `runbooks/01-preflight.md`.
