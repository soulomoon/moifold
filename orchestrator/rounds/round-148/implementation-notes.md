### Changes Made
- `test/TestSupport/Workflow.hs`: replaced the `CodexWatcher.AppServerClient` import used for `AppServerTurn (..)` with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`. This was import-only; helper exports, helper bodies, fixtures, test bodies, protocol imports, production code, Cabal files, docs, policy, public facade exposure, and direct-owner exports were not changed.

### Tests
- `test/TestSupport/Workflow.hs`: no test bodies changed. Existing shared helper/export anchors were scanned and preserved: `appServerRequestId`, `fakeActionExecutorWith`, `fakeActionExecutorWithLogger`, `fakeActionExecutorWithJsonStore`, `defaultFakeAppServer`, classifier helpers, and existing `AppServerTurn` fixtures.

Validation run from `orchestrator/worktrees/round-148`:
- `! rg -n '^import CodexWatcher\.AppServerClient\b' test/TestSupport/Workflow.hs` - passed; no selected-file facade import remains.
- `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/TestSupport/Workflow.hs` - passed; direct owner import found at line 111.
- `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` - passed; owner module exports `AppServerTurn (..)` and defines `data AppServerTurn`.
- `rg -n 'appServerRequestId|fakeActionExecutorWith|fakeActionExecutorWithLogger|fakeActionExecutorWithJsonStore|defaultFakeAppServer|classifyTurnCompletion|classifyIssuePlanningTurn|classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyIssueFinalReviewTurn|AppServerTurn' test/TestSupport/Workflow.hs` - passed; selected helper/export anchors remain present.
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*` - passed for this round's expectation; no hit remains in `test/TestSupport/Workflow.hs`. Remaining hits are out of scope: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, and docs under `docs/agentic-workflow-framework/`.
- `git diff -- test/TestSupport/Workflow.hs` - passed; selected implementation diff is import-only.
- `git diff --name-only` - observed `orchestrator/state.json`, `test/TestSupport/Workflow.hs`, and this implementation note. `orchestrator/state.json` was pre-existing/unrelated control-plane work and was not edited in this implementation pass.
- `cabal test watcher-core-test` - passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all` - passed.

### Notes
This round does not approve, imply, or perform deprecation, public facade removal, Cabal exposure cleanup, docs cleanup, API cleanup, policy cleanup, milestone completion, release approval, or terminal roadmap completion.

Remaining `CodexWatcher.AppServerClient` users and references are deliberately out of scope for later reviewed selections: public facade implementation/exposure, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/Main.hs`, `test/BoundaryPolicySpec.hs`, `moifold.cabal`, and docs/policy references. `CodexWatcher.AppServerProtocol` remains imported in `test/TestSupport/Workflow.hs` because `AppServerRequest` is still owned there.
