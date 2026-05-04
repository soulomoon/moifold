# Runbook Validation

Use this page when validating changes to watcher setup scripts, CLI parser wiring, setup docs, or this runbook. This is a maintainer gate, not the normal project watcher start path.

Start by recording the current worktree state without reverting user changes:

```bash
git status --short --untracked-files=all
```

## 1. Docker primary gate

First prove Docker is available:

```bash
docker --version
docker info
```

Then run the setup smoke:

```bash
scripts/watcher-init/docker-setup-smoke.sh
```

If Docker is unavailable, stop the primary validation and report the exact `docker --version` and `docker info` failures. Do not use host tests as a substitute for Docker smoke unless the operator explicitly accepts that weaker validation.

The Docker smoke must complete these stages:

- Install OS dependencies.
- Install `gh`.
- Install `ghcup`.
- Install and select `ghc` and `cabal` through `ghcup`.
- Initialize the Cabal package index.
- Build the watcher with `cabal build all`.
- Resolve `WATCHER_BIN`.
- Start a mock app-server TCP listener.
- Run `check-app-server.sh` directly in `APP_SERVER_CHECK_MODE=tcp`.
- Run `check-project-setup.sh` in check-only mode.
- Initialize issue planning, issue implementer, and PR review state.
- Check generated `dry-run-command.sh` and `restart-command.sh` syntax.
- Replay the initial `events.jsonl` files.
- Check watcher loop command help.

Expected Docker app-server output is TCP-only:

```text
ok app-server tcp
app-server protocol probe skipped: tcp-only mode
```

That proves the container can reach a service port. It does not prove the real Codex app-server protocol.

## 2. Host quick confirmation

Only after Docker smoke passes, run:

```bash
bash -n scripts/watcher-init/*.sh
git diff --check
cabal build all
cabal test all
bin="$(cabal list-bin moifold)" && "$bin" probe-app-server --help
```

## 3. Stale reference scan

Run:

```bash
rg -n \
  -g '!docs/watcher-agent-runbook/runbook-validation.md' \
  "command_text|bash -lc \"\\$|app-server TCP check passed|jq|APP_SERVER_CHECK_MODE|probe-app-server" \
  scripts docs test src app moifold.cabal
```

Expected interpretation:

- `command_text` should not appear as a stale generated field; helper names such as `setup_command_text` are acceptable.
- `bash -lc "$...` style generated command references should not appear.
- `app-server TCP check passed` should not appear as stale text.
- `APP_SERVER_CHECK_MODE` should be limited to env, setup smoke, app-server check, and docs references.
- `probe-app-server` should be wired through parser, tests, app-server check scripts, and relevant docs.
- `jq` hits from `gh --jq` command rendering or tests are acceptable.

## Report format

Report:

- Whether Docker setup smoke truly completed.
- Whether each Docker stage passed.
- Whether host quick confirmation passed.
- Any key failure output and likely root cause.
- Whether stale or duplicate setup logic remains.
