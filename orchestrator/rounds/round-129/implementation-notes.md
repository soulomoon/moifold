### Changes Made
- `test/WorkflowAgentSpec.hs`: removed the unused exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import only.
- `test/TestSupport/Workflow.hs`: removed the unused exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import only.
- Kept direct owner imports `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` in both files.

### Tests
- `! rg -n "WorkflowEventLog\\.|CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs` - passed with no output.
- `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test` - passed; remaining hits were only in out-of-scope tests: `WorkflowDocsMigrationSpec.hs`, `WorkflowExecutionSpec.hs`, `WorkflowEventLogSpec.hs`, `FacadeImportPolicySpec.hs`, `Main.hs`, and `WorkflowIndexedSpec.hs`.
- `printf ':module + WorkflowAgentSpec\nworkflowAgentTests\n:quit\n' | cabal repl watcher-core-test` - passed; `workflowAgentTests` evaluated to `True`.
- `cabal test watcher-core-test` - passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all` - passed.
- `git diff --check` - passed with no output.
- `git diff --cached --check` - passed with no output.
- `git diff --stat` - showed the two import removals plus pre-existing controller-owned `orchestrator/state.json` changes.
- `git diff -- test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs` - showed only the two selected import-line removals.
- `git status --short` - showed `M orchestrator/state.json`, `M test/TestSupport/Workflow.hs`, `M test/WorkflowAgentSpec.hs`, and `?? orchestrator/rounds/round-129/`.

### Notes
No behavior, exports, test aggregation, helper definitions, event JSON, fixtures, production code, package descriptors, docs, facade modules, roadmap files, or runtime compatibility files were changed. `orchestrator/state.json` was already modified before this implementation pass and was left untouched.
