### Goal
Move only `test/TestSupport/Workflow.hs` off the `CodexWatcher.AppServerClient` compatibility facade for `AppServerTurn (..)`, importing that type from `CodexWatcher.Workflow.Agent.Codex.Client` while preserving the shared workflow helper exports and all classifier/helper behavior.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-148-test-support-workflow-appserverturn-direct-owner-migration`.

### Approach
Make a single import-only edit in `test/TestSupport/Workflow.hs`: replace the facade import `CodexWatcher.AppServerClient` with an explicit direct-owner import of `AppServerTurn (..)` from `CodexWatcher.Workflow.Agent.Codex.Client`.

Do not change production files, test bodies, helper exports, test-suite wiring, package descriptors, docs or policy text, `CodexWatcher.AppServerClient`, direct-owner module exports, public facade exposure, Cabal exposure, runtime compatibility files, deprecation/removal policy, milestone status, release state, or terminal roadmap state. The public facade remains available; remaining facade users are evidence for later selected rounds only.

Worker mode: none. The round has one implementation file and one ordered verification path, so worker fan-out is not justified and `worker-plan.json` should not be created.

### Steps
1. Reconfirm scope before editing with `git status --short` and `sed -n '1,90p' test/TestSupport/Workflow.hs`; preserve unrelated existing control-plane edits and implementation files.
2. In `test/TestSupport/Workflow.hs`, remove only `import CodexWatcher.AppServerClient`.
3. Add `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))` near the existing app-server/workflow-agent imports. Leave `CodexWatcher.AppServerProtocol` in place because `AppServerRequest` remains owned there.
4. Do not reorder unrelated imports, change warning pragmas, add broad imports, or edit definitions below the import block.
5. Re-scan selected exported helper anchors and leave them unchanged: `appServerRequestId`, `fakeActionExecutorWith`, `fakeActionExecutorWithLogger`, `fakeActionExecutorWithJsonStore`, `defaultFakeAppServer`, `classifyTurnCompletion`, `classifyIssuePlanningTurn`, `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`, `classifyIssueFinalReviewTurn`, and all existing `AppServerTurn` fixtures.
6. Record remaining `CodexWatcher.AppServerClient` users from the broad scan as out of scope. In particular, do not edit `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/AppServerClient.hs`, docs, Cabal files, package exposure, or policy scanners.
7. Inspect the implementation diff with `git diff -- test/TestSupport/Workflow.hs` and confirm it is import-only. Then run `git diff --name-only` and confirm no implementation path other than `test/TestSupport/Workflow.hs` changed for this round.

### Verification
Required checks from the round worktree after the import-only edit:

1. Focused selected-file import guard:

   ```sh
   ! rg -n '^import CodexWatcher\.AppServerClient\b' test/TestSupport/Workflow.hs
   rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/TestSupport/Workflow.hs
   ```

2. Direct owner import/export evidence:

   ```sh
   rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs
   rg -n 'import CodexWatcher\.Workflow\.Agent\.Codex\.Client.*AppServerTurn' test/TestSupport/Workflow.hs
   ```

3. Selected-file behavioral/export anchor scan:

   ```sh
   rg -n 'appServerRequestId|fakeActionExecutorWith|fakeActionExecutorWithLogger|fakeActionExecutorWithJsonStore|defaultFakeAppServer|classifyTurnCompletion|classifyIssuePlanningTurn|classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyIssueFinalReviewTurn|AppServerTurn' test/TestSupport/Workflow.hs
   ```

   Confirm the shared helper exports remain present and no test bodies or helper definitions changed.

4. Broad remaining facade scan across source, apps, tests, docs, package descriptors, and standalone package candidates:

   ```sh
   rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*
   ```

   Expected result: no hit in `test/TestSupport/Workflow.hs`; remaining hits are out of scope for this round and must remain untouched unless a later selected round names them.

5. Diff scope checks:

   ```sh
   git diff -- test/TestSupport/Workflow.hs
   git diff --name-only
   ```

   Expected result: the selected file diff is import-only, and implementation changes are limited to `test/TestSupport/Workflow.hs`. Round artifacts may include `orchestrator/rounds/round-148/plan.md`.

6. Required baseline checks:

   ```sh
   cabal test watcher-core-test
   cabal build all
   git diff --check
   ```

7. Staging check, only if staging occurs later:

   ```sh
   git diff --cached --check
   ```

### Risks
- `test/TestSupport/Workflow.hs` exports shared helpers used by many tests, so an accidental helper or test-body edit could create broad behavior drift. Keep the implementation diff import-only.
- `AppServerRequest` is still needed from `CodexWatcher.AppServerProtocol`; moving or broadening that import would exceed the selected `AppServerTurn (..)` migration.
- A clean selected-file scan does not imply the `CodexWatcher.AppServerClient` facade is deprecated or removable. Remaining facade imports, docs, policy evidence, and Cabal exposure stay for later exact selections.

### Out Of Scope
- Production code, test bodies, test-suite wiring, package descriptors, docs, public facade implementation, public facade exports, direct-owner exports, Cabal exposure, runtime compatibility files, deprecation, removal, release approval, milestone completion, and terminal roadmap completion.
- Other current or expected `CodexWatcher.AppServerClient` users, including `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, `test/BoundaryPolicySpec.hs`, `src/CodexWatcher/AppServerClient.hs`, docs, and Cabal references.
