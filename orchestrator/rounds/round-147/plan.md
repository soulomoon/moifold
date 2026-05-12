### Goal
Move only `test/WorkflowIndexedSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`, by importing `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`, while preserving the indexed PR-review worker/reviewer classifier-backed outcome assertions, helper signatures, `workflowIndexedTests`, and every test body.

### Approach
Use a single-file, import-only edit. Leave all `AppServerTurn` values, helper type signatures, classifier cases, assertions, test bodies, helper modules, package descriptors, docs, public facades, direct-owner modules, and production files unchanged.

The direct owner is already valid for this migration: `CodexWatcher.Workflow.Agent.Codex.Client` exports `AppServerTurn (..)`, and `CodexWatcher.AppServerClient` remains an exposed compatibility facade. This round only moves the selected test importer toward the direct owner; it does not deprecate, remove, hide, or change the facade.

Worker fan-out is not used. The change has one implementation file owner and one verification path; splitting it would add coordination overhead without independent non-overlapping work.

### Steps
1. Open `test/WorkflowIndexedSpec.hs` and locate the current import block near the top of the file.
2. Replace only `import CodexWatcher.AppServerClient` with `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
3. Do not reorder unrelated imports, do not add helper imports, and do not touch any definitions below the import block.
4. Confirm the following selected behavioral anchors are still present and unchanged in `test/WorkflowIndexedSpec.hs`: `workflowIndexedTests`, `workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes`, `workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes`, `prReviewWorkerIndexedClassifierCase`, `prReviewReviewerIndexedClassifierCase`, and all `AppServerTurn` helper signature references.
5. Record the remaining `CodexWatcher.AppServerClient` users from the broad scan as out of scope for this round. In particular, do not edit `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `src/CodexWatcher/AppServerClient.hs`, docs, policy specs, Cabal exposure, or package descriptors.

### Verification
Run these checks from the round worktree after the import-only edit:

1. Focused selected-file import guard:

   ```sh
   ! rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowIndexedSpec.hs
   rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowIndexedSpec.hs
   ```

2. Direct owner import/export scan:

   ```sh
   rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs test/WorkflowIndexedSpec.hs
   rg -n 'module CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.Client' src/CodexWatcher/AppServerClient.hs
   ```

3. Selected-file behavioral anchor scan:

   ```sh
   rg -n 'workflowIndexedTests|workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes|workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes|prReviewWorkerIndexedClassifierCase|prReviewReviewerIndexedClassifierCase|AppServerTurn' test/WorkflowIndexedSpec.hs
   ```

   Confirm the scan still shows the `workflowIndexedTests` entries for both classifier-backed tests, both classifier helper definitions with `-> AppServerTurn` signatures, and the existing worker/reviewer `AppServerTurn` fixtures.

4. Broad AppServerClient scan documenting remaining out-of-scope users:

   ```sh
   rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*
   ```

   Expected result: no hit in `test/WorkflowIndexedSpec.hs`; remaining hits are out of scope for this round and must remain untouched unless a later selection names them.

5. Diff scope checks:

   ```sh
   git diff -- test/WorkflowIndexedSpec.hs
   git diff --name-only
   ```

   Expected result: the selected file diff is import-only, and implementation changes are limited to `test/WorkflowIndexedSpec.hs`. Round artifacts may include `orchestrator/rounds/round-147/plan.md`.

6. Required baseline checks:

   ```sh
   cabal test watcher-core-test
   cabal build all
   git diff --check
   git diff --cached --check
   ```

7. Optional focused REPL check, only if practical and never as a replacement for `cabal test watcher-core-test`:

   ```sh
   cabal repl watcher-core-test
   ```

   In the REPL, load `WorkflowIndexedSpec` and evaluate `workflowIndexedTests` if the local Cabal setup makes that focused check faster than rerunning the full test target during investigation.
