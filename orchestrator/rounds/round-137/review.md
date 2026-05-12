### Checks Run
- Command: `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`
  Result: pass; command exited 1 with no matches, so the three selected files no longer import `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` and contain no `WorkflowPermission.` use sites.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' test`
  Result: pass; remaining exact facade imports are only `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- Command: `rg -n 'WorkflowPermission\.' test`
  Result: pass; remaining use sites are only in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- Command: `git diff --name-only`
  Result: pass; changed paths before review artifacts were `orchestrator/state.json`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, and `test/WorkflowEventLogSpec.hs`.
- Command: `git diff --cached --name-only`
  Result: pass; no staged paths.
- Command: `git diff -- test/WorkflowEventLogSpec.hs test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs`
  Result: pass; diff removes only the exact unused import line from each selected file.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites passed.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.

### Plan Compliance
- Remove only unused `WorkflowPermission` imports from `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs`: met; each selected file has exactly one deleted import line and no other selected-file diff.
- Selected-file post scan must produce no matches: met; the selected-file scan returned no output.
- Broad exact Permission facade import scan must leave only the three excluded files: met; matches remain only in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- Broad `WorkflowPermission.` scan must leave only the three excluded files: met; all remaining use sites are in the excluded real-use/policy files.
- Preserve assertions, fixtures, event schemas, aggregate wiring, helper exports, and direct EventLog owner imports: met; the implementation diff only deletes unused imports and does not change code bodies, exports, fixtures, or event data.
- Do not change package descriptors, production/app files, facade modules, roadmap files, docs/policy, or out-of-scope tests: met; no such paths appear in the implementation diff.
- Do not claim public facade deprecation/removal, Cabal exposure cleanup, package descriptor cleanup, docs/policy cleanup, remaining Permission facade migration, milestone completion, terminal completion, release approval, or public compatibility removal: met; implementation notes claim only unused import removal and validation results.
- Active roadmap and project-contract baseline: met; baseline commands passed, public compatibility facades remain available, and this import-reduction round does not imply deprecation or removal approval.

### Decision
**APPROVED**

### Evidence
The integrated round result is a mechanical import-only cleanup in the selected files:

- `test/WorkflowEventLogSpec.hs`: removed `import CodexWatcher.Workflow.Permission qualified as WorkflowPermission`.
- `test/WorkflowAgentSpec.hs`: removed `import CodexWatcher.Workflow.Permission qualified as WorkflowPermission`.
- `test/TestSupport/Workflow.hs`: removed `import CodexWatcher.Workflow.Permission qualified as WorkflowPermission`.

The selected-file post scan has no matches. The broad exact facade import scan leaves only:

- `test/FacadeImportPolicySpec.hs:22`
- `test/WorkflowIndexedSpec.hs:183`
- `test/WorkflowExecutionSpec.hs:183`

The broad `WorkflowPermission.` scan leaves only real use sites in those same excluded files. `git diff --check`, `git diff --cached --check`, `cabal test watcher-core-test`, and `cabal build all` all passed. No staged changes were present.
