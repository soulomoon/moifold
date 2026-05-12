### Checks Run
- Command: `! rg -n '^import CodexWatcher\.AppServerClient\b' test/WorkflowIndexedSpec.hs`
  Result: pass; no selected-file facade import remains.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client \(AppServerTurn \(\.\.\)\)' test/WorkflowIndexedSpec.hs`
  Result: pass; line 23 imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Command: `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Client|AppServerTurn \(\.\.\)' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs test/WorkflowIndexedSpec.hs`
  Result: pass; direct owner module is declared and exports `AppServerTurn (..)`, and the selected test imports it.
- Command: `rg -n 'module CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.Client' src/CodexWatcher/AppServerClient.hs`
  Result: pass; `CodexWatcher.AppServerClient` remains a facade over the direct owner.
- Command: `rg -n 'workflowIndexedTests|workflowPrReviewWorkerIndexedSpecMatchesClassifierBackedOutcomes|workflowPrReviewReviewerIndexedSpecMatchesClassifierBackedOutcomes|prReviewWorkerIndexedClassifierCase|prReviewReviewerIndexedClassifierCase|AppServerTurn' test/WorkflowIndexedSpec.hs`
  Result: pass; `workflowIndexedTests`, both classifier-backed outcome tests, both classifier helpers, `-> AppServerTurn` helper signatures, and existing `AppServerTurn` fixtures remain present.
- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal agent-workflow-*`
  Result: pass; no hit remains in `test/WorkflowIndexedSpec.hs`. Remaining out-of-scope users are `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, `test/BoundaryPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/Main.hs`, `test/WorkflowExecutionSpec.hs`, `test/TestSupport/Workflow.hs`, and docs under `docs/agentic-workflow-framework/`.
- Command: `git diff -- test/WorkflowIndexedSpec.hs`
  Result: pass; diff is import-only, replacing `import CodexWatcher.AppServerClient` with `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
- Command: `git diff --name-only`
  Result: pass; tracked diff contains only `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`.
- Command: `git diff -- orchestrator/state.json`
  Result: pass; state records round 147 in `review` for roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites passed.
- Command: `cabal build all`
  Result: pass; output was `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Step 1, locate the selected import block: met; `test/WorkflowIndexedSpec.hs` import block was the only selected-file diff location.
- Step 2, replace only the facade import with the direct owner import: met; selected-file diff is a single import replacement.
- Step 3, do not reorder unrelated imports or touch definitions: met; `git diff -- test/WorkflowIndexedSpec.hs` shows no definition, assertion, helper, or body changes.
- Step 4, preserve selected behavioral anchors: met; the anchor scan still finds `workflowIndexedTests`, both classifier-backed outcome tests, both classifier helpers, `-> AppServerTurn` helper signatures, and the existing worker/reviewer fixtures.
- Step 5, record remaining facade users as out of scope: met; the broad scan lists remaining facade users outside `test/WorkflowIndexedSpec.hs`, and none were edited by this round.
- Project-contract non-goals: met; this round does not claim public facade deprecation/removal, Cabal/API exposure cleanup, docs cleanup, package cleanup, milestone completion, release approval, terminal completion, or public compatibility removal.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected scope. `test/WorkflowIndexedSpec.hs` no longer imports `CodexWatcher.AppServerClient`; it imports `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))` directly. The direct owner export is present, and the compatibility facade remains available and exposed.

The only tracked non-orchestrator implementation/test diff is the selected test file, and that diff is import-only. `git diff --name-only` shows only `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`; untracked round artifacts are under `orchestrator/rounds/round-147/`. No out-of-scope implementation file, package descriptor, docs file, public facade module, or unselected test file was changed.

Baseline validation passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
