# Operator Checklist

Before start:

- `scripts/watcher-init/docker-setup-smoke.sh` has passed, or the operator has explicitly accepted skipping Docker smoke.
- `WATCHER_BIN` exists and was built from the expected watcher repo.
- `ghcup` is installed.
- `ghc` is installed and preferably selected through `ghcup`.
- `cabal` is installed and preferably selected through `ghcup`.
- `scripts/watcher-init/check-project-setup.sh /path/to/watcher.env` has been run in check-only mode.
- Missing system tools and detected project dependency setup commands have been reviewed.
- Project dependencies were installed only after an explicit operator decision.
- `gh auth status` succeeds for the target GitHub account.
- `TARGET_WORKDIR` is the target project checkout.
- The target project branch state is understood before execute mode.
- The app server host and port are reachable.
- `events.jsonl` replays successfully.
- No watcher pid is currently running for the same state directory.
- `runtime-owner.json` is absent or belongs to an inactive pid.

Before resume:

- Do not overwrite old `events.jsonl`.
- Back up state before repair or blocked-tail drop.
- Prefer `scripts/restart-watcher` over invoking a raw loop command by hand.
- Check `daemon.log`, `daemon.err.log`, `watcher.log.jsonl`, and `block-state.json` after restart.

Before handing off:

- Record the state directory.
- Record the watcher domain.
- Record whether it is dry-run or execute loop.
- Record the current replay phase from `replay-events`.
