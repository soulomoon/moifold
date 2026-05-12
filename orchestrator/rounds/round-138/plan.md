### Goal
Move only `test/WorkflowIndexedSpec.hs` off the `CodexWatcher.Workflow.Permission` compatibility-facade import for its single `validateWorkflowEffectPlanCore @MoifoldSpec` assertion, using the direct `CodexWatcher.Workflow.Permission.Core` owner module while preserving all existing indexed workflow behavior and permission-error expectations.

### Approach
Keep this as a sequential, single-file import convergence round under the project contract. The only implementation file in scope is `test/WorkflowIndexedSpec.hs`; public facade modules, package descriptors, docs/policy, runtime compatibility surfaces, fixtures, and the two explicitly out-of-scope test files remain unchanged.

No worker fan-out is justified because the change is one import and one existing use site in one file, with one implementer able to run the focused scans and baseline verification without cross-file ownership splits.

### Steps
1. Confirm the starting point in `test/WorkflowIndexedSpec.hs`: the exact import `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` and the single `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec wrongPhaseState checkingEffects` use.
2. Replace that import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`.
3. Update only the existing `validateWorkflowEffectPlanCore @MoifoldSpec` call in `test/WorkflowIndexedSpec.hs` to `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`.
4. Do not modify `test/FacadeImportPolicySpec.hs`, `test/WorkflowExecutionSpec.hs`, any public facade modules, Cabal/package descriptors, docs/policy files, runtime files, fixtures, roadmap files, `orchestrator/state.json`, or review/merge artifacts.
5. Run focused scans for `test/WorkflowIndexedSpec.hs` to prove it no longer imports `CodexWatcher.Workflow.Permission` as `WorkflowPermission` and has no remaining `WorkflowPermission.` use.
6. Run broad remaining import/use scans over Haskell sources, docs, package descriptors, and standalone package candidates. Record that only the two out-of-scope test files, `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`, retain `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports and `WorkflowPermission.` facade use after this round. Treat the facade module definition itself and direct `Permission.Core` references as expected non-findings, not migration targets.
7. Inspect `git diff -- test/WorkflowIndexedSpec.hs orchestrator/rounds/round-138/plan.md` to confirm the implementation diff is limited to the selected test-file import/use change plus this plan artifact.

### Verification
- `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/WorkflowIndexedSpec.hs`
- `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/FacadeImportPolicySpec.hs test/WorkflowExecutionSpec.hs`
- `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." $(rg --files -g'*.hs' src app test) docs moifold.cabal cabal.project* package.yaml || true`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if staging is used

### Worker Fan-Out
No worker fan-out. Do not create `worker-plan.json` for this round.
