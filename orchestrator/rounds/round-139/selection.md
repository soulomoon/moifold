### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-139-workflow-execution-spec-permission-direct-owner-migration`
- Extracted item summary: Migrate only `test/WorkflowExecutionSpec.hs` off the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` compatibility-facade import by replacing the two `validateMoifoldEffectPlan` assertions with existing direct `validatePhaseActionPlan` calls and replacing the two `validateWorkflowEffectPlanCore @MoifoldSpec` assertions with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowExecutionSpec.hs` only; remove the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import; add direct `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` only if needed; replace `WorkflowPermission.validateMoifoldEffectPlan` with `validatePhaseActionPlan`, which is already imported and used in this file; replace `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` with `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`; preserve all workflow execution assertions, fixtures, event schemas, aggregate wiring, dry-run checks, permission-error expectations, and existing `validatePhaseActionPlan` comparisons.
- Out of scope: `test/FacadeImportPolicySpec.hs`; public `CodexWatcher.Workflow.Permission` facade implementation or exports; `CodexWatcher.Workflow.Permission.Core` exports; `CodexWatcher.StateMachine` behavior; package descriptors; docs/policy wording; runtime compatibility files; EventLog facade parity coverage; public facade deprecation/removal; Cabal exposure cleanup; package descriptor cleanup; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress. Round 138 accepted the prior concrete Permission migration and left exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports/use sites only in `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`. The roadmap update records `WorkflowExecutionSpec` as the remaining non-policy concrete Permission migration candidate, while `FacadeImportPolicySpec` remains explicit facade/policy parity coverage.

This selects a concrete migration/removal slice rather than another readiness-only gate, matching the current operator steering for direction 012. The full `WorkflowExecutionSpec` facade import removal is lawful in one bounded file-local round: `WorkflowPermission.validateMoifoldEffectPlan` is only a concrete Moifold helper wrapper over `validatePhaseActionPlan`, and this file already imports and uses `validatePhaseActionPlan`; `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` is owned directly by `CodexWatcher.Workflow.Permission.Core`, which prior accepted rounds already established as the direct owner for core permission validation.

The selected scope should remove the facade import completely from `test/WorkflowExecutionSpec.hs`, not split only the core calls, because leaving the two `validateMoifoldEffectPlan` calls on the facade would preserve the last non-policy concrete Permission facade dependency even though an equivalent direct path is already present in the file. `test/FacadeImportPolicySpec.hs` remains untouched because it is the explicit facade/policy parity owner, so this round does not imply public facade deprecation, public facade removal, Cabal exposure cleanup, or milestone completion.
