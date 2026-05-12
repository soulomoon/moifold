### Goal
Remove the unused exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade imports from `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs` only. Preserve workflow test aggregation, support helper exports, direct owner imports (`WorkflowEventLogCommit` and `WorkflowEventLogFileCore`), and behavior.

### Approach
Treat this as a narrow import-convergence removal slice, not a public facade or package-boundary removal. First prove that the two selected files have no local `WorkflowEventLog.` references, then delete only the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import lines from those files. Leave every other EventLog facade import in tests, `test/Main.hs`, docs, Cabal exposure, production code, and facade modules untouched because those surfaces are outside this round.

No worker fan-out is justified: both edits are adjacent test/support import cleanup with one verification path and no independent ownership boundary.

### Steps
1. Confirm the selected files still match the precondition:
   ```sh
   rg -n "WorkflowEventLog\\.|CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs
   ```
   Expected before editing: each file has the exact import, and neither file has any `WorkflowEventLog.` use site.
2. In `test/WorkflowAgentSpec.hs`, remove only:
   ```haskell
   import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
   ```
   Keep `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` imports in place.
3. In `test/TestSupport/Workflow.hs`, remove only:
   ```haskell
   import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
   ```
   Keep `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` imports in place.
4. Do not touch exports, test aggregation, helper definitions, production files, package descriptors, docs, roadmap files, facade modules, runtime compatibility files, event JSON, or golden fixtures.
5. Confirm the worktree diff contains only the two selected import-line removals plus this plan artifact during the planning phase:
   ```sh
   git diff -- test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs
   git diff -- orchestrator/rounds/round-129/plan.md
   ```

### Verification
Run these checks after the two import removals:

1. Targeted selected-file no-use/no-import scan:
   ```sh
   ! rg -n "WorkflowEventLog\\.|CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs
   ```
2. Broad exact EventLog facade import scan over tests to prove these two files were removed from the remaining set while out-of-scope test imports remain visible:
   ```sh
   rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" test
   ```
   Expected after editing: no hits in `test/WorkflowAgentSpec.hs` or `test/TestSupport/Workflow.hs`; remaining hits may still include out-of-scope tests such as `test/WorkflowDocsMigrationSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/FacadeImportPolicySpec.hs`, and `test/Main.hs`.
3. If a focused preflight is useful before the full suite, run the existing workflow agent IO aggregate through the test-suite GHCi context:
   ```sh
   printf ':module + WorkflowAgentSpec\nworkflowAgentTests\n:quit\n' | cabal repl watcher-core-test
   ```
   This is only a focused preflight; it does not replace the full test suite.
4. Run the required baseline tests/build:
   ```sh
   cabal test watcher-core-test
   cabal build all
   ```
5. Run diff hygiene checks:
   ```sh
   git diff --check
   git diff --cached --check
   ```
6. Final scope review:
   ```sh
   git diff --stat
   git diff -- test/WorkflowAgentSpec.hs test/TestSupport/Workflow.hs
   git status --short
   ```
   Confirm only the two selected test/support imports were removed by the implementation, no `worker-plan.json` was created, and unrelated existing worktree changes such as controller-owned `orchestrator/state.json` are not modified by this round.
