### Source Round
- Round id: `round-110`
- Merged commit: `74f715b`
- Evidence: `orchestrator/rounds/round-110/selection.md`, `orchestrator/rounds/round-110/runner-guard-appserverclient-gate-evidence.md`, `orchestrator/rounds/round-110/review.md`, `orchestrator/rounds/round-110/review-record.json`, and `orchestrator/rounds/round-110/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and `orchestrator/roadmap-updates/round-110-roadmap-update.md`

### Rationale
Round 110 completed artifact-only RunnerGuard AppServerClient gate evidence at merged commit `74f715b`. The accepted evidence maps every `src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` imported symbol to direct owner modules and use sites, covering `AppServerEndpoint`, `AppServerTurn (..)`, `defaultAppServerClientOptions`, `formatAppServerClientFailure`, `latestTurnById`, `parseThreadReadTurns`, `parseTurnStartTurnId`, `sendOneAppServerRequest`, `startThreadWithEndpoint`, `threadReadMaterializationPending`, and `threadSystemError`.

The gate matrix evaluated repair-thread launch, `thread-name/set`, `turn/start`, request id progression, active-thread read, thread-read materialization pending, `threadSystemError`, latest-turn lookup, turn-completion classification, stale-turn decisions, and `formatAppServerClientFailure` text. The recommendation is status-only: no later RunnerGuard import-only split is safe yet until focused RunnerGuard active app-server turn inspection coverage lands first.

This update preserves the existing boundaries. It does not approve migration, deprecation, public facade removal, Cabal exposure or package cleanup, behavior change, source/test/docs/package changes, milestone completion, release, or terminal completion. `CodexWatcher.AppServerClient` remains public and unchanged. Direction 010 remains in progress, with remaining source users still including `RunnerGuard.hs` as blocked by focused behavior coverage, plus `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, `Cli/Command/IssueFanout.hs`, plus test-policy imports.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
