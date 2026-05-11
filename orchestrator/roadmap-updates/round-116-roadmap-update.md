### Source Round
- Round id: `round-116`
- Merged commit: `c6b5c6b Add Healthcheck app-server thread coverage`
- Evidence: `orchestrator/rounds/round-116/selection.md`, `orchestrator/rounds/round-116/implementation-notes.md`, `orchestrator/rounds/round-116/review.md`, `orchestrator/rounds/round-116/review-record.json`, and `orchestrator/rounds/round-116/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and `orchestrator/roadmap-updates/round-116-roadmap-update.md`

### Rationale
`round-116` satisfies the Healthcheck app-server thread inspection coverage gate recorded under `direction-010-appserverclient-import-convergence`. The reviewed change added endpoint-backed `runHealthcheck` worker `thread/read` coverage for request id `9001`, `includeTurns = True`, the configured thread id, latest turn id/status/count reporting, missing endpoint and missing thread id skip behavior, no `thread/read` when the thread id is absent, JSON-RPC error formatting, decode-failure prefix handling, and the direct-owner `AppServerEndpoint` test import.

The active roadmap should record this as evidence for a later import-only `Healthcheck.hs` migration decision, not as migration itself. Timeout coverage was omitted and accepted because the production timeout is hard-coded to five seconds.

Validation passed with the focused REPL aggregate, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, production/package/protocol diff guards, no `worker-plan.json`, and review-record `jq`.

Milestone 003 and direction 010 remain in progress. Current `CodexWatcher.AppServerClient` source users still include `Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`, `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus test-policy and test-support imports. `Cli/Command/AppServerProbe.hs` remains absent from the remaining source-user list because round 115 migrated it. `Healthcheck.hs` now has its coverage gate satisfied but still remains a source user until a later import-only migration.

This update does NOT approve production Healthcheck import migration, behavior changes, public facade removal/deprecation, Cabal/API exposure cleanup, docs cleanup, other importer migration, milestone completion, release approval, or terminal completion.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
