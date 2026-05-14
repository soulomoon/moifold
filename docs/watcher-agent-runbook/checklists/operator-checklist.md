# Operator Checklist

Before moifold runtime setup is accepted:

- `docker --version` has succeeded.
- `docker info` has succeeded.
- The persistent watcher container exists and is running.
- The watcher repo is mounted in the persistent container at the path recorded in `WATCHER_REPO`.
- `ghcup`, `ghc`, and `cabal` are installed inside the persistent container and selected through `ghcup`.
- `WATCHER_BIN` exists inside the persistent container and was built from the expected watcher repo.
- `gh auth status` succeeds inside the persistent container for the target GitHub account.
- The app server host and port are reachable from inside the persistent container.
- The app server supports the Codex thread/turn protocol needed by `moifold`.
- `docker exec "$WATCHER_DOCKER_CONTAINER" ... scripts/watcher-init/check-app-server.sh /workspace/artifacts/<project>-watcher.env` has passed against the real app-server.
- If setup scripts, watcher setup code, CLI parser, or this runbook changed, `../runbook-validation.md` has passed.

Before starting a project watcher:

- `scripts/watcher-init/check-project-setup.sh /workspace/artifacts/<project>-watcher.env` has been run in check-only mode inside the persistent watcher container.
- Missing system tools and detected project dependency setup commands have been reviewed.
- Project dependencies were installed only after an explicit operator decision.
- `gh auth status` succeeds inside the persistent watcher container for the target GitHub account.
- `TARGET_WORKDIR` is the target project checkout path inside the persistent watcher container.
- The target project branch state is understood before execute mode.
- `events.jsonl` replays successfully.
- `dry-run-command.sh` syntax is valid and its command line matches the intended watcher domain.
- No watcher pid is currently running for the same state directory.
- `runtime-owner.json` is absent or belongs to an inactive pid.

Before resume:

- Do not overwrite old `events.jsonl`.
- Back up state before repair or blocked-tail drop.
- Prefer `scripts/restart-watcher` over invoking a raw loop command by hand.
- Check `daemon.log`, `daemon.err.log`, `watcher.log.jsonl`, and
  `moifold healthcheck` after restart.

Before handing off:

- Record the persistent watcher container name.
- Record the state directory.
- Record the watcher domain.
- Record whether it is dry-run or execute loop.
- Record the current replay phase from `replay-events`.
