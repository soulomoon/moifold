### Source Round
- Round id: `round-120`
- Merged commit: `660e3a4` (`Move IssuePlanning loop off AppServerClient facade`)
- Evidence: `orchestrator/rounds/round-120/selection.md`, `orchestrator/rounds/round-120/implementation-notes.md`, `orchestrator/rounds/round-120/review.md`, `orchestrator/rounds/round-120/review-record.json`, and `orchestrator/rounds/round-120/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 120 completed the selected `round-120-issue-planning-loop-appserverclient-import-convergence` extraction under milestone `milestone-003-import-convergence-package-boundaries` and direction `direction-010-appserverclient-import-convergence`. The merged change moved only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.

The reviewed evidence records this as an import-only migration: no code bodies, behavior, planner-thread initialization, request-id progression, dry-run synthetic planner thread behavior, planned app-server request/result behavior, active-turn reads, systemError retry/blocking behavior, command failure formatting for snapshot commands, tests, docs, package descriptors, public facade, protocol modules, direct-owner modules, runtime files, app code, or other importers changed. Validation passed for the focused planning classifier and systemError REPL gate, full `cabal test watcher-core-test`, `cabal build all`, diff checks, target import scans, forbidden diff guards, no-worker-plan checks, and state/review-record JSON checks.

The active roadmap should therefore record `Domain/IssuePlanning/Loop.hs` as migrated off `CodexWatcher.AppServerClient` while keeping direction 010 and milestone 003 in progress. Remaining production source users are `Domain/PrReview/LaunchCli.hs`, `AutomaticLoop/Runner.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`, and `Domain/IssuePlanning/Loop.hs` are now migrated off the facade.

This status update does not approve public facade removal or deprecation, Cabal/API exposure cleanup, docs cleanup, package descriptor cleanup, protocol or runtime changes, other importer migration, milestone completion, release approval, terminal completion, or any public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
