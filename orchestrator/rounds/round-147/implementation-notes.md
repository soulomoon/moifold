### Changes Made
- `test/WorkflowIndexedSpec.hs`: replaced the `CodexWatcher.AppServerClient` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- No test bodies, helper signatures, assertions, strings, `workflowIndexedTests`, package descriptors, docs or policy files, public facade modules, direct owner modules, production files, or other test files were changed.

### Tests
- `test/WorkflowIndexedSpec.hs`: still compiles and runs through `watcher-core-test`; the indexed PR-review worker and reviewer classifier-backed outcome anchors remain present.
- Focused selected-file import guard:
  - `! rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowIndexedSpec.hs` passed with no matches.
  - `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowIndexedSpec.hs` found line 23.
- Direct owner import/export scan:
  - `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` declares `module CodexWatcher.Workflow.Agent.Codex.Client` and exports `AppServerTurn (..)`.
  - `test/WorkflowIndexedSpec.hs` imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
  - `src/CodexWatcher/AppServerClient.hs` remains a facade module reexporting/importing `CodexWatcher.Workflow.Agent.Codex.Client`.
- Selected-file behavioral anchor scan:
  - `workflowIndexedTests` remains present with entries for `workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes` and `workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes`.
  - `prReviewWorkerIndexedClassifierCase` and `prReviewReviewerIndexedClassifierCase` remain present with `-> AppServerTurn` helper signatures.
  - Existing worker and reviewer `AppServerTurn` fixtures remain present.
- Broad `CodexWatcher.AppServerClient` scan:
  - No match remains in `test/WorkflowIndexedSpec.hs`.
  - Remaining matches are out of scope for this round: `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/Main.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`, and docs under `docs/agentic-workflow-framework/`.
- Diff scope checks:
  - `git diff -- test/WorkflowIndexedSpec.hs` shows the selected import-only change.
  - `git diff --name-only` before notes showed `test/WorkflowIndexedSpec.hs` plus pre-existing non-owned `orchestrator/state.json`; I did not edit `orchestrator/state.json`.
- Required baseline checks:
  - `cabal test watcher-core-test` passed.
  - `cabal build all` passed.
  - `git diff --check` passed.
  - `git diff --cached --check` passed.
- Optional focused REPL check was skipped as redundant after the full `watcher-core-test` and `cabal build all` verification.

### Notes
This is an import-only migration for the selected test file. Explicit non-goals for this round: no public facade deprecation or removal, no Cabal/API exposure cleanup, no docs cleanup, no package cleanup, no milestone completion, no release approval, no terminal completion, and no public compatibility removal.
