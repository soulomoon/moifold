### Goal
Remove the concrete `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` facade dependency from `test/WorkflowExecutionSpec.hs` by switching the existing assertions to direct owner validation paths, while preserving workflow execution behavior and leaving `test/FacadeImportPolicySpec.hs` as the only intentional Permission facade import/use site.

### Approach
Keep this as a sequential, single-file migration. `test/WorkflowExecutionSpec.hs` already imports and uses `validatePhaseActionPlan`, so the two `WorkflowPermission.validateMoifoldEffectPlan` checks should become direct `validatePhaseActionPlan` checks. Add `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` for the two existing `validateWorkflowEffectPlanCore @MoifoldSpec` checks, and update only those call heads to the direct core qualifier.

Do not edit `test/FacadeImportPolicySpec.hs`, the public `CodexWatcher.Workflow.Permission` facade, `Permission.Core` exports, `StateMachine`, package descriptors, docs/policy, runtime compatibility files, EventLog facade parity, roadmap/state artifacts, or release/removal artifacts. This round is import convergence only; it is not facade deprecation, facade removal, Cabal exposure cleanup, milestone completion, terminal completion, or public compatibility removal.

No worker fan-out is justified because the scope is one test file with four mechanical use-site updates and one import replacement.

### Steps
1. Confirm the starting point in `test/WorkflowExecutionSpec.hs`:
   - The exact import `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` is present.
   - `validatePhaseActionPlan` is already imported and used.
   - The only `WorkflowPermission.` use sites in the file are the two `validateMoifoldEffectPlan` assertions and the two `validateWorkflowEffectPlanCore @MoifoldSpec` assertions selected for this round.
2. Replace the exact Permission facade import with:
   - `import CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`
3. Update only the selected use sites in `test/WorkflowExecutionSpec.hs`:
   - Replace `WorkflowPermission.validateMoifoldEffectPlan state planned.plannedPreCommitEffects` with `validatePhaseActionPlan state planned.plannedPreCommitEffects`.
   - Replace `WorkflowPermission.validateMoifoldEffectPlan state expectedEffects` with `validatePhaseActionPlan state expectedEffects`.
   - Replace both `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec ...` call heads with `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec ...`.
4. Preserve the existing assertion structure and expectations:
   - Keep the merge pre-commit effect assertion.
   - Keep the allowed merge permission assertion.
   - Keep the denied-state rejection assertion and its checks for `workflowPermissionEffectLabel == "MergePullRequest"` and `"effect is not allowed"`.
   - Do not change fixtures, event schemas, aggregate wiring, dry-run expectations, replay assertions, observation assertions, or any surrounding helper behavior.
5. Run focused selected-file scans and record the results:
   - `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowExecutionSpec.hs`
   - Expected: no matches.
   - `rg -n 'WorkflowPermissionCore\.validateWorkflowEffectPlanCore @MoifoldSpec|validatePhaseActionPlan' test/WorkflowExecutionSpec.hs`
   - Expected: the migrated core validation uses are present, and direct phase validation remains the Moifold permission path used by this file.
6. Run broad remaining-use scans over source, app, tests, docs, package descriptors, and standalone package candidates. Record that only `test/FacadeImportPolicySpec.hs` retains the Permission facade import/use after this round:
   - `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null`
   - Expected implementation-relevant matches: only `test/FacadeImportPolicySpec.hs`.
   - Treat historical orchestrator artifacts and roadmap text as evidence records, not implementation migration targets.
7. Inspect the diff and confirm it is limited to `test/WorkflowExecutionSpec.hs` plus this `plan.md`, with no implementation/test files outside selection, no state/roadmap/review/merge artifacts, no package descriptors, and no docs/policy edits.

### Verification
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if anything is staged
- Focused `test/WorkflowExecutionSpec.hs` scans proving the old Permission facade import and `WorkflowPermission.` qualifier are gone from the selected file.
- Broad Permission facade import/use scans proving `test/FacadeImportPolicySpec.hs` is the only remaining current code file with `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` or `WorkflowPermission.` use.
- Diff review confirming this remains a behavior-preserving import convergence round and does not edit out-of-scope files or imply public facade removal/deprecation.

### Worker Fan-Out
No worker fan-out. The selected change is a single-file, four-use-site migration with a serial verification path, so `worker-plan.json` should not be created.
