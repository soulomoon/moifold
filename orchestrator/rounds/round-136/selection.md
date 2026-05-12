### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-136-workflow-docs-migration-spec-permission-core-import-convergence`
- Extracted item summary: Migrate only `test/WorkflowDocsMigrationSpec.hs` off the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` compatibility-facade import by using the direct `CodexWatcher.Workflow.Permission.Core` owner module for existing `validateWorkflowEffectPlanCore` assertions.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowDocsMigrationSpec.hs` only; replace the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`; update only the existing `WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec ...` use sites to the direct owner qualifier; preserve all DocsMigration assertions, indexed permission parity checks, fixtures, event schemas, aggregate wiring, and existing EventLog direct-owner imports.
- Out of scope: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/TestSupport/Workflow.hs`, and all production `src` or `app` files; any `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `validateWorkflowEffectPlanWithPolicy`, or `workflowEffectPermissionChecks*` facade parity migration; the explicit `CodexWatcher.Workflow.EventLog` facade parity owner in `test/FacadeImportPolicySpec.hs`; `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; public facade deprecation/removal; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 is dependency-ready because milestone 001 is complete, and direction 012 remains in progress after round 135. The accepted round-135 evidence leaves the only exact EventLog facade import in `test/FacadeImportPolicySpec.hs`, where it intentionally owns facade parity for `replayMoifoldWorkflowEvents`, `replayWorkflowEventLog @MoifoldSpec`, `initializeMoifoldWorkflow`, and `applyMoifoldWorkflowEvent`; removing that parity-owner import is not lawful without a later public facade decision.

This selects a concrete behavior-preserving migration slice instead of another readiness-only gate. `test/WorkflowDocsMigrationSpec.hs` is the smallest next lawful `Workflow.Permission` target because its current `WorkflowPermission.` use sites are only `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec`, and the active roadmap records `CodexWatcher.Workflow.Permission.Core` as the direct owner module exposed by `agent-workflow-core`. The selected file does not call `validateMoifoldEffectPlan` or `moifoldPermissionPolicy`, so this round can reduce facade dependence without changing concrete moifold permission policy behavior or public compatibility availability.

The remaining `Workflow.Permission` bridge imports in other tests stay for later exact selections because they either preserve explicit facade parity, use concrete moifold validation helpers, or need separate file-local review. Public `Workflow.EventLog` and `Workflow.Permission` modules, Cabal exposed-module entries, docs/policy wording, and runtime compatibility surfaces remain unapproved for deprecation or removal.
