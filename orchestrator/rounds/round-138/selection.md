### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-138-workflow-indexed-spec-permission-core-import-convergence`
- Extracted item summary: Migrate only `test/WorkflowIndexedSpec.hs` off the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` compatibility-facade import by using the direct `CodexWatcher.Workflow.Permission.Core` owner module for its single existing `validateWorkflowEffectPlanCore @MoifoldSpec` assertion.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowIndexedSpec.hs` only; replace the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`; update only the existing `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec ...` use site to the direct owner qualifier; preserve all indexed workflow assertions, fixtures, event schemas, aggregate wiring, direct owner imports, and permission-error expectations.
- Out of scope: `test/FacadeImportPolicySpec.hs`, `test/WorkflowExecutionSpec.hs`, and all other test, production, app, package, docs, policy, roadmap, and orchestrator files; any `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `validateWorkflowEffectPlanWithPolicy`, or `workflowEffectPermissionChecks*` facade parity migration; the explicit facade/policy parity coverage in `test/FacadeImportPolicySpec.hs`; public `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; runtime compatibility files; event JSON `type` fields; fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after the accepted round-137 import cleanup. The current live scan records the only remaining exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports and `WorkflowPermission.` use sites in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.

This selects a concrete direct-owner migration slice rather than another readiness-only gate. `test/WorkflowIndexedSpec.hs` is the smallest lawful remaining Permission facade target because it has a single real `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` use, and round-136 already established `CodexWatcher.Workflow.Permission.Core` as the direct owner for `validateWorkflowEffectPlanCore`. The selected file does not call `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, policy-check helpers, or explicit facade parity helpers, so this round can reduce the remaining Permission facade surface without changing concrete moifold permission policy behavior or public compatibility availability.

`test/WorkflowExecutionSpec.hs` stays out of scope because it mixes `validateMoifoldEffectPlan` and `validateWorkflowEffectPlanCore @MoifoldSpec` in the same assertions and needs a separate file-local migration decision. `test/FacadeImportPolicySpec.hs` stays out of scope because it owns explicit facade/policy parity coverage and should not be casually removed. Public facade modules, Cabal exposed-module entries, docs/policy wording, runtime compatibility files, and terminal cleanup decisions remain unapproved.
