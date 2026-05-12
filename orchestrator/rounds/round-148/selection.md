### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-010-appserverclient-import-convergence`
- Extracted item id: `round-148-test-support-workflow-appserverturn-direct-owner-migration`
- Extracted item summary: Move only `test/TestSupport/Workflow.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`, preserving the shared workflow helper exports and classifier helper behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/TestSupport/Workflow.hs` import-only migration for `AppServerTurn (..)`, with focused validation that the selected helper no longer imports `CodexWatcher.AppServerClient`, still imports the direct owner module, and preserves the shared helper exports including `appServerRequestId`, `fakeActionExecutorWith`, `fakeActionExecutorWithLogger`, `fakeActionExecutorWithJsonStore`, and `defaultFakeAppServer`.
- Out of scope: production code; test bodies; other test modules; test-suite wiring; package descriptors; docs/policy text; public `CodexWatcher.AppServerClient` facade implementation, exports, or Cabal exposure; direct owner module exports; `test/WorkflowEventLogSpec.hs`; `test/WorkflowExecutionSpec.hs`; `test/Main.hs`; `test/BoundaryPolicySpec.hs`; runtime compatibility files; deprecation; public API removal; package descriptor cleanup; milestone completion; release approval; terminal completion; or public compatibility removal.
- Concurrent batch context: none; state has `max_parallel_rounds: 1`, and this round is a serial import-convergence slice after round 147.

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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 010 remains in progress after round 147 migrated `test/WorkflowIndexedSpec.hs` off the `CodexWatcher.AppServerClient` facade. The current live scan still finds exact `CodexWatcher.AppServerClient` imports in `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`, and `test/Main.hs`, plus policy/facade/docs/Cabal references. `test/WorkflowIndexedSpec.hs` is no longer a remaining importer.

This selects concrete direct migration work rather than another readiness-only artifact. `test/TestSupport/Workflow.hs` is a shared helper surface and uses `AppServerTurn (..)` for classifier helper assertions, while `AppServerRequest` remains covered by the existing `CodexWatcher.AppServerProtocol` import. The direct owner import matches the accepted round 145-147 pattern for workflow-test `AppServerTurn` migrations and should be behavior-preserving when kept import-only.

The round must not use this helper migration as public deprecation or removal approval. Public facade exposure in `moifold.cabal`, docs/policy references, `test/BoundaryPolicySpec.hs` policy evidence, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, and `test/Main.hs` remain later exact selections unless a future reviewed gate approves broader cleanup.

Validation expectations: run focused selected-file scans for the removed facade import and added direct-owner import; scan the remaining exact `CodexWatcher.AppServerClient` importers across `src`, `app`, `test`, docs, and package descriptors; run `cabal test watcher-core-test`, `cabal build all`, and `git diff --check`. If staging occurs later, also run `git diff --cached --check`.
