### Selected Extraction
- Milestone: Import Convergence And Package-Boundary Cleanup
- Milestone id: `milestone-003-import-convergence-package-boundaries`
- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
- Extracted item id: `round-137-unused-workflow-permission-import-removal`
- Extracted item summary: Remove only unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports from test/support files that currently have no `WorkflowPermission.` use sites.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs` only; delete the exact unused `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import from each file; preserve all assertions, fixtures, event schemas, aggregate wiring, helper exports, direct EventLog owner imports, and workflow behavior.
- Out of scope: `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`; any migration of real `WorkflowPermission.` call sites such as `validateMoifoldEffectPlan`, `validateWorkflowEffectPlanCore`, `validateWorkflowEffectPlanWithPolicy`, `workflowEffectPermissionChecks*`, or `moifoldPermissionPolicy`; the explicit EventLog facade parity owner in `test/FacadeImportPolicySpec.hs`; public `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` facade modules; production `src` or `app` files; `moifold.cabal` or other package descriptors; Cabal exposure cleanup; docs/policy changes; runtime compatibility files; event JSON `type` fields; fixture shape changes; release approval; milestone completion; terminal completion; or public compatibility removal.
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
Milestone 003 remains in progress and direction 012 explicitly asks future selections to prefer lawful concrete migration/removal slices over readiness-only gate work when accepted evidence makes the slice lawful. Round 136 approved the first `Workflow.Permission` direct-owner migration and recorded that the remaining exact facade imports are limited to `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.

The current scan shows `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs` each import `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` but have no `WorkflowPermission.` use sites. Removing those unused imports is a concrete internal facade-import removal, not a behavior change and not a public facade removal. It reduces the remaining Permission facade surface while avoiding files that still exercise actual permission behavior.

The remaining files stay out of scope because they need separate file-local review: `test/FacadeImportPolicySpec.hs` owns explicit facade/policy parity, `test/WorkflowExecutionSpec.hs` mixes `validateMoifoldEffectPlan` with `validateWorkflowEffectPlanCore`, and `test/WorkflowIndexedSpec.hs` has a real core validation call that is a separate direct-owner migration candidate. This round therefore advances cleanup without changing permission soundness, concrete moifold policy behavior, Cabal exposure, docs, runtime compatibility files, or public compatibility availability.
