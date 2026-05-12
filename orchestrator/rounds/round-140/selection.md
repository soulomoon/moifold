### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-140-test-support-appserver-endpoint-direct-owner-migration`
- Extracted item summary: Migrate only `test/TestSupport/AppServer.hs` from `CodexWatcher.AppServerClient (AppServerEndpoint (..))` to the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, preserving the endpoint-backed fake app-server helper behavior and leaving all users of the helper unchanged.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/TestSupport/AppServer.hs` only; replace its exact `CodexWatcher.AppServerClient (AppServerEndpoint (..))` import with `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`; preserve `withEndpointBackedAppServer`, `jsonRpcResult`, `jsonRpcError`, request recording, server startup, endpoint construction, and helper exports.
- Out of scope: all production files; all other tests and test-support files; `test/FacadeImportPolicySpec.hs`; public `CodexWatcher.AppServerClient` facade implementation or exports; `CodexWatcher.Workflow.Agent.Codex.Client`; `CodexWatcher.Workflow.Agent.Codex.Transport` exports; package descriptors; docs/policy wording; public facade deprecation/removal; Cabal exposure cleanup; package descriptor cleanup; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress. Round 105 accepted the current `CodexWatcher.AppServerClient` readiness evidence and established that the facade is a public compatibility reexport of direct owner modules. Rounds 106 through 126 migrated the production AppServerClient users, and current controller facts leave concrete AppServerClient imports in tests and test support plus the public facade/exposure/docs surfaces.

This selects a concrete migration slice instead of another readiness-only gate. `test/TestSupport/AppServer.hs` imports only `AppServerEndpoint (..)` from the facade, and `AppServerEndpoint` is owned directly by `CodexWatcher.Workflow.Agent.Codex.Transport`. The file is a test helper that constructs endpoint-backed fake app-server values for already accepted coverage; moving this one import does not touch endpoint parsing, session protocol, command rendering, timeout, fallback, failure formatting, app-server client behavior, or public compatibility exposure.

The selected support-file migration should run before public facade or Cabal cleanup because it reduces current concrete test-support facade use while keeping the explicit facade/policy parity owner and all public compatibility gates intact. It also provides a small, reviewable next step after round 139 closed the last non-policy Permission import and after current evidence shows EventLog and Permission concrete use is limited to `test/FacadeImportPolicySpec.hs`.
