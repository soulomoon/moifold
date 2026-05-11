### Source Round
- Round id: `round-118`
- Merged commit: `e45b729 Add Observe command app-server coverage`
- Evidence: `orchestrator/rounds/round-118/selection.md`, `orchestrator/rounds/round-118/implementation-notes.md`, `orchestrator/rounds/round-118/review.md`, `orchestrator/rounds/round-118/review-record.json`, and `orchestrator/rounds/round-118/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and `orchestrator/roadmap-updates/round-118-roadmap-update.md`

### Rationale
`round-118` completes the `round-118-observe-appserver-interpreter-coverage` slice under `direction-010-appserverclient-import-convergence`. The reviewed implementation added focused black-box `observeOnce` coverage for `src/CodexWatcher/Cli/Command/Observe.hs`: execute mode without an endpoint fails with the required endpoint flag message, dry-run without an endpoint succeeds through the null interpreter fallback, and execute mode with a configured endpoint reaches fake app-server session and planner `turn/start` traffic.

This update is status-only and keeps the active roadmap revision at `rev-001`. The round was test-only: it added `test/ObserveCommandSpec.hs`, wired `observeCommandTests` into `test/Main.hs`, and added only `ObserveCommandSpec` to the `watcher-core-test` metadata in `moifold.cabal`. Production `src/CodexWatcher/Cli/Command/Observe.hs`, app-server client/transport/protocol modules, runtime compatibility files, fixtures, docs, app code, and other importer files were not changed.

Validation passed with the focused `ObserveCommandSpec.observeCommandTests` REPL aggregate, `cabal test watcher-core-test`, `cabal build all`, diff hygiene, forbidden-path diff guards, package-descriptor scope checks, observe import-migration guards, remaining facade-user scans, no worker-plan artifact, and review-stage state checks.

Milestone 003 and direction 010 remain in progress. `round-118` records the Observe coverage gate as satisfied for a later import-only migration decision, but `Cli/Command/Observe.hs` remains a `CodexWatcher.AppServerClient` source user until that later migration. Remaining source users still include `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. `RunnerGuard.hs`, `Cli/Command/AppServerProbe.hs`, and `Healthcheck.hs` remain migrated off the facade.

This update does NOT approve production Observe import migration, public facade removal/deprecation, Cabal/API exposure cleanup, docs cleanup, other importer migration, milestone completion, release approval, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
