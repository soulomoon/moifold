### Changes Made
- `test/WorkflowAgentSpec.hs`: replaced the import-only dependency on the public compatibility facade `CodexWatcher.AppServerClient` with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- `orchestrator/rounds/round-146/implementation-notes.md`: recorded the implemented scope, verification evidence, and explicit non-goals for round 146.

### Tests
- `test/WorkflowAgentSpec.hs`: existing workflow agent role, PR review worker/reviewer turn-classifier, observation-kernel, and app-server turn-read assertions were preserved unchanged; no test bodies, helper functions, assertions, strings, or `workflowAgentTests` were edited.
- `git status --short`: before the edit, the worktree already showed `M orchestrator/state.json` and `?? orchestrator/rounds/round-146/`; after the import edit, `test/WorkflowAgentSpec.hs` was the only implementation file changed by this round.
- `sed -n '1,80p' test/WorkflowAgentSpec.hs`: before showed `import CodexWatcher.AppServerClient`; after showed `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Focused selected-file import guard:
  - `rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowAgentSpec.hs`: no matches, exit 1 as expected.
  - `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowAgentSpec.hs`: line 23 direct owner import present.
- Direct owner import/export scan:
  - `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)|data AppServerTurn' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`: module declaration on line 11, `AppServerTurn (..)` export on line 14, `data AppServerTurn` on line 77.
  - `rg -n 'import CodexWatcher\.Workflow\.Agent\.Codex\.Client.*AppServerTurn' test/WorkflowAgentSpec.hs`: line 23 import present.
- Selected-file behavioral anchor scan:
  - `rg -n 'workflowAgentTests|workflowAgentRoleWrapsPrReviewWorkerClassifier|workflowPrReviewAgentRolesClassifyOutputs|workflowAgentObservationKernelMatchesPrReviewClassifiers|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|workflow Codex adapter parses thread read turn|AppServerTurn' test/WorkflowAgentSpec.hs`: found `workflowAgentTests`, the selected workflow role/classifier/observation tests, both classifier calls, the app-server turn-read assertion text, and all `AppServerTurn` uses.
- Broad AppServerClient scan:
  - `rg -n 'CodexWatcher\.AppServerClient' src app test agent-workflow-codex moifold.cabal`: remaining matches are `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/Main.hs`; all are out of scope for this selected round.
- Diff inspection:
  - `git diff -- test/WorkflowAgentSpec.hs`: import-only diff replacing the facade import with the direct owner import.
  - `git diff --name-only`: showed `orchestrator/state.json` and `test/WorkflowAgentSpec.hs`; `orchestrator/state.json` was pre-existing orchestration state and was not edited in this round.
- `cabal test watcher-core-test`: pass, 1 of 1 test suites passed.
- `cabal build all`: pass.
- `git diff --check`: pass, no output.
- `git diff --cached --check`: pass, no output.

### Notes
Optional focused REPL load was skipped as redundant after `cabal test watcher-core-test` compiled `WorkflowAgentSpec` and the full test/build checks passed.

Explicit non-goals preserved: no public facade deprecation or removal, no Cabal/API exposure cleanup, no docs cleanup, no package cleanup, no milestone completion, no release approval, no terminal completion, and no public compatibility removal.
