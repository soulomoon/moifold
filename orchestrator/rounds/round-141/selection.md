### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-141-issue-fanout-appserver-spec-endpoint-direct-owner-migration`
- Extracted item summary: Migrate only `test/IssueFanoutAppServerSpec.hs` from `CodexWatcher.AppServerClient (AppServerEndpoint (..))` to the direct transport owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, preserving issue-fanout app-server coverage and leaving the public compatibility facade unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/IssueFanoutAppServerSpec.hs` only; replace its exact `CodexWatcher.AppServerClient (AppServerEndpoint (..))` import with `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`; preserve all issue-fanout execute, child-argument rendering, retry classification, child-start classification, JSON-RPC failure, and decode-failure assertions.
- Out of scope: all production files; all other tests and test-support files; `test/PrReviewLaunchCliSpec.hs`; `test/AutomaticLoopRunnerSpec.hs`; workflow specs with broader `CodexWatcher.AppServerClient` imports; `test/FacadeImportPolicySpec.hs` and source-scan policy expectations; public `CodexWatcher.AppServerClient` facade implementation or exports; `CodexWatcher.Workflow.Agent.Codex.Client`; direct owner exports; package descriptors; docs/policy wording; public facade deprecation/removal; Cabal exposure cleanup; package descriptor cleanup; release approval; milestone completion; terminal completion; or public compatibility removal.
- Concurrent batch context: none; controller state is serial with `max_parallel_rounds: 1`, so this selection opens one round only.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 140 removed the shared AppServer test helper from the `CodexWatcher.AppServerClient` facade. The live scan now shows no production `CodexWatcher.AppServerClient` source imports, but it still shows endpoint-only test imports, broader test imports, public facade/exposure, and docs/policy references. User steering asks the next selection to favor concrete removal or direct-owner migration over another readiness-only artifact, and this slice is a lawful direct-owner migration.

`test/IssueFanoutAppServerSpec.hs` imports only `AppServerEndpoint (..)` from the facade, while the direct owner is already exposed from `CodexWatcher.Workflow.Agent.Codex.Transport`. Round 125 added the issue-fanout app-server behavior coverage, and round 126 migrated the production `Cli/Command/IssueFanout.hs` importer to direct client and transport owners. That evidence makes the test-side endpoint import safe to migrate without touching issue-fanout behavior, app-server protocol, session handling, command rendering, failure formatting, or public compatibility exposure.

This should run now because it removes another concrete remaining facade importer from direction 010 while keeping policy tests, broader facade parity checks, and public facade removal gates intact for later exact selections.
