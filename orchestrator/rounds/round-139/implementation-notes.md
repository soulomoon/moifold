### Changes Made
- `test/WorkflowExecutionSpec.hs`: removed the concrete `CodexWatcher.Workflow.Permission` facade import, added the direct `CodexWatcher.Workflow.Permission.Core` import, migrated the selected Moifold permission helper checks to direct `validatePhaseActionPlan`, and migrated the selected core validation checks to `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`.

### Tests
- `test/WorkflowExecutionSpec.hs`: preserves the existing mergeability permission assertions and error expectations while exercising direct owner validation paths instead of the compatibility facade.

### Notes
No out-of-scope source, facade, package, policy, runtime, fixture, roadmap, review, merge, or state files were edited. `test/FacadeImportPolicySpec.hs` remains the intentional Permission facade policy coverage owner.
