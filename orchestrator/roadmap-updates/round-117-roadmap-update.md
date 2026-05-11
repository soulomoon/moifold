### Source Round
- Round id: `round-117`
- Merged commit: `bd7951f Move Healthcheck off AppServerClient facade`
- Evidence: `orchestrator/rounds/round-117/selection.md`, `orchestrator/rounds/round-117/implementation-notes.md`, `orchestrator/rounds/round-117/review.md`, `orchestrator/rounds/round-117/review-record.json`, and `orchestrator/rounds/round-117/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and `orchestrator/roadmap-updates/round-117-roadmap-update.md`

### Rationale
`round-117` completes the `round-117-healthcheck-appserverclient-import-convergence` slice under `direction-010-appserverclient-import-convergence`. The reviewed implementation moved only `src/CodexWatcher/Healthcheck.hs` from the public `CodexWatcher.AppServerClient` facade to direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.

This update is status-only and keeps the active roadmap revision at `rev-001`. The round was import-only: no code bodies, behavior, tests, package descriptors, public facade, direct owner modules, protocol modules, docs, or other importers changed.

Validation passed with a Healthcheck target import scan confirming no facade import, direct-owner import scans, the focused Healthcheck REPL aggregate, `cabal test watcher-core-test`, `cabal build all`, diff checks, forbidden-path diff guards, no worker-plan, and review-record `jq`.

Milestone 003 and direction 010 remain in progress. Remaining `CodexWatcher.AppServerClient` source users should no longer include `Healthcheck.hs` and still include `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, and `Healthcheck.hs` are migrated off the facade.

This update does NOT approve public facade removal/deprecation, Cabal/API exposure cleanup, docs cleanup, other importer migration, milestone completion, release approval, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
