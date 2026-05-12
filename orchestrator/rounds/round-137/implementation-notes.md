### Changes Made
- `test/WorkflowEventLogSpec.hs`: removed the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import; no assertions, fixtures, event schemas, direct EventLog owner imports, or workflow behavior changed.
- `test/WorkflowAgentSpec.hs`: removed the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import; no assertions, fixtures, event schemas, aggregate wiring, helper exports, or workflow behavior changed.
- `test/TestSupport/Workflow.hs`: removed the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import; no helper exports, aggregate wiring, assertions, fixtures, or workflow behavior changed.

### Tests
- `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`: passed; no matches remained in the selected files after the removal.
- `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' test`: passed; remaining matches were only `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- `rg -n 'WorkflowPermission\.' test`: passed; remaining use sites were only in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- `git diff --name-only`: showed `orchestrator/state.json`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, and `test/WorkflowEventLogSpec.hs` before this notes file was written; `orchestrator/state.json` was pre-existing orchestrator state and was not edited by this implementer.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged whitespace errors.
- `cabal test watcher-core-test`: passed; 1 of 1 test suites passed.
- `cabal build all`: passed.

### Notes
No staging, commit, merge, production code, package descriptor, roadmap, facade module, fixture, or out-of-scope test edits were made. The selected-file pre-change scan showed the exact unused import once in each selected file and no `WorkflowPermission.` use sites in those files.
