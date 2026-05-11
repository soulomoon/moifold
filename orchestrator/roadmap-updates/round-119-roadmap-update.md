### Source Round
- Round id: `round-119`
- Merged commit: `f59c2c3` (`Move Observe command off AppServerClient facade`)
- Evidence: `orchestrator/rounds/round-119/selection.md`, `orchestrator/rounds/round-119/implementation-notes.md`, `orchestrator/rounds/round-119/review.md`, `orchestrator/rounds/round-119/review-record.json`, and `orchestrator/rounds/round-119/merge.md`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`

### Rationale
Round 119 completed the selected `round-119-observe-appserverclient-import-convergence` extraction under milestone `milestone-003-import-convergence-package-boundaries` and direction `direction-010-appserverclient-import-convergence`. The merged change moved only `src/CodexWatcher/Cli/Command/Observe.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to direct owner transport imports for `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions`.

The reviewed evidence records this as an import-only migration: no command body, behavior, parser, output, endpoint requirement, dry-run fallback, tests, docs, package descriptors, protocol modules, facade modules, direct-owner modules, runtime files, app code, or other importers changed. Validation passed for focused `ObserveCommandSpec.observeCommandTests`, full `cabal test watcher-core-test`, `cabal build all`, diff checks, target import scans, forbidden diff guards, no-worker-plan checks, and state/review-record JSON checks.

The active roadmap should therefore record `Cli/Command/Observe.hs` as migrated off `CodexWatcher.AppServerClient` while keeping direction 010 and milestone 003 in progress. Remaining production source users are `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, `Healthcheck.hs`, and `Cli/Command/Observe.hs` are now migrated off the facade.

This status update does not approve public facade removal or deprecation, Cabal/API exposure cleanup, docs cleanup, package descriptor cleanup, protocol or runtime changes, other importer migration, milestone completion, release approval, terminal completion, or any public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
