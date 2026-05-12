### Goal
Remove only the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports from:

- `test/WorkflowEventLogSpec.hs`
- `test/WorkflowAgentSpec.hs`
- `test/TestSupport/Workflow.hs`

This round should reduce the remaining internal `Workflow.Permission` facade imports without changing assertions, fixtures, event schemas, aggregate wiring, helper exports, direct EventLog owner imports, package descriptors, production code, public facade modules, roadmap files, or workflow behavior.

### Approach
Keep the implementation sequential and mechanical. The selected files currently import `CodexWatcher.Workflow.Permission qualified as WorkflowPermission`, and the current selected-file scan shows no `WorkflowPermission.` use sites in those three files. Delete that exact import line from each selected file and make no other code or test changes.

Do not touch `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, or `test/WorkflowExecutionSpec.hs`; those files still own real `WorkflowPermission.` use sites or facade policy coverage and need separate review. Do not create `worker-plan.json`; fan-out is not justified for three import-line removals.

### Steps
1. Record the pre-change selected-file scan:
   - `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`
   - Confirm the exact facade import appears once in each selected file.
   - Confirm there are no `WorkflowPermission.` use sites in the selected files.
2. Remove only this exact import from each selected file:
   - `import CodexWatcher.Workflow.Permission qualified as WorkflowPermission`
3. Run the post-change selected-file scan:
   - `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`
   - Confirm the command produces no matches. If it reports a `WorkflowPermission.` use site, stop and inspect before making any broader change.
4. Run the broad exact Permission facade import scan:
   - `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' test`
   - Confirm the only remaining matches are:
     - `test/FacadeImportPolicySpec.hs`
     - `test/WorkflowIndexedSpec.hs`
     - `test/WorkflowExecutionSpec.hs`
   - Treat any other remaining match as a failed implementation for this round, except do not expand scope without a new plan/review.
5. Confirm the remaining `WorkflowPermission.` use sites are only in the excluded real-use files:
   - `rg -n 'WorkflowPermission\.' test`
   - Confirm matches remain only in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
6. Check changed paths:
   - `git diff --name-only`
   - The implementation diff should show only `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs` plus round artifacts/controller state already managed by the orchestrator.
   - If staging is used, also run `git diff --cached --name-only` with the same expectation.

### Verification
Run the focused scans and active roadmap baseline:

1. `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`
2. `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' test`
3. `rg -n 'WorkflowPermission\.' test`
4. `git diff --name-only`
5. `cabal test watcher-core-test`
6. `cabal build all`
7. `git diff --check`
8. `git diff --cached --check` if staging is involved

The reviewer should reject the round if any selected file still imports `CodexWatcher.Workflow.Permission qualified as WorkflowPermission`, if any selected file gains or retains a `WorkflowPermission.` use site, if the broad exact facade import scan leaves files other than `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`, if real Permission call sites are changed, or if any assertion, fixture, event schema, aggregate wiring, helper export, direct EventLog owner import, workflow behavior, package descriptor, production/app file, public facade module, roadmap file, or out-of-scope test file is edited.
