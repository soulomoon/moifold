### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-135-workflow-eventlog-spec-facade-import-removal`
- Extracted item summary: Remove the remaining exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import from `test/WorkflowEventLogSpec.hs` by making that behavior spec use only direct EventLog core owner calls, while leaving explicit Moifold bridge-wrapper facade parity coverage in `test/FacadeImportPolicySpec.hs`.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowEventLogSpec.hs` only; remove its exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import and replace the remaining `WorkflowEventLog.initializeMoifoldWorkflow` / `WorkflowEventLog.applyMoifoldWorkflowEvent` comparison points with direct `CodexWatcher.Workflow.EventLog.Core` owner behavior; preserve the existing EventLog core transition assertions, labels, event schemas, fixture contracts, replay/transition behavior, and watcher-core aggregation.
- Out of scope: `test/FacadeImportPolicySpec.hs` and its explicit facade parity assertions for `replayMoifoldWorkflowEvents`, `replayWorkflowEventLog @MoifoldSpec`, `initializeMoifoldWorkflow`, and `applyMoifoldWorkflowEvent`; production `src` or `app` files; other tests or support files; creating, moving, deleting, or changing `CodexWatcher.Workflow.EventLog`; public facade deprecation/removal; `moifold.cabal` or package descriptor changes; Cabal exposure cleanup; `CodexWatcher.Workflow.Permission` migration; docs/policy changes; runtime compatibility files; event JSON `type` fields; golden fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after rounds 127 through 134. Those rounds migrated the known production EventLog facade users and the safe test/test-support users to direct owners. After round 134, accepted evidence shows exact `CodexWatcher.Workflow.EventLog` facade imports remain only in `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`; the latter remains solely for two Moifold bridge-wrapper parity calls.

This selects a concrete facade-import removal slice rather than another readiness-only gate. The wrapper parity behavior is already intentionally covered in `test/FacadeImportPolicySpec.hs`, including replay, initialization, and apply facade checks. Therefore `test/WorkflowEventLogSpec.hs` can stop importing the compatibility facade and keep its role as the reusable EventLog core behavior spec using direct owner modules only.

The slice reduces the remaining EventLog facade surface while preserving the public compatibility facade and the explicit policy/parity test that still exercises it. It does not approve public facade removal or deprecation, Cabal exposure removal, package descriptor cleanup, docs cleanup, remaining `test/FacadeImportPolicySpec.hs` facade migration, `Workflow.Permission` migration, release approval, milestone completion, terminal completion, or public compatibility removal.
