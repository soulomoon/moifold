### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-134-workflow-eventlog-spec-core-audit-direct-owner-split`
- Extracted item summary: Split only `test/WorkflowEventLogSpec.hs` so reusable EventLog core and workflow audit assertions import direct owner modules, while any remaining Moifold bridge-wrapper checks continue to call the compatibility facade explicitly.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowEventLogSpec.hs` only; migrate generic `WorkflowEventLog.` use sites for `EventLogFixtureContract`, replay summaries, transition helpers/failures, `initializeWorkflowEvent`, `applyWorkflowEvent`, `replayWorkflowEventLogDetailed`, fixture validation, workflow failure audit, audit accessors, and daemon recommendations to direct owners such as `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.Audit`; keep facade-qualified calls only where the test is intentionally exercising current Moifold bridge wrappers such as `initializeMoifoldWorkflow` and `applyMoifoldWorkflowEvent`; preserve all existing assertions, labels, event schemas, fixture contracts, replay/transition parity, and test aggregation.
- Out of scope: `test/FacadeImportPolicySpec.hs`; production `src` or `app` files; other test/support files; creating or moving a bridge-owner production module; changing `CodexWatcher.Workflow.EventLog` exports; public facade deprecation/removal; `moifold.cabal` or any package descriptor change; Cabal exposure removal; `CodexWatcher.Workflow.Permission` migration; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 133. Those rounds migrated the known production EventLog facade users and all simple test/test-support audit-only imports. The current remaining exact `CodexWatcher.Workflow.EventLog` facade imports are limited to `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`.

This selects a concrete owner split rather than another readiness-only artifact. `test/WorkflowEventLogSpec.hs` is the next smallest lawful behavior-test target because it mixes reusable EventLog core assertions, audit assertions, and explicit Moifold bridge-wrapper parity checks in one facade-qualified namespace. Direct owner modules for the reusable parts already exist in `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.Audit`, while the current product-owned bridge wrappers still live on the compatibility facade and can remain visibly facade-qualified for this round.

The selection deliberately avoids public facade or Cabal exposure cleanup. It reduces the mixed facade surface inside the behavior spec, leaves `test/FacadeImportPolicySpec.hs` as the explicit policy/facade parity test, and preserves future options for a later narrow bridge-owner extraction without implying approval for facade removal, deprecation, `Workflow.Permission` migration, milestone completion, terminal completion, or public compatibility removal.
