### Checks Run
- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`
  Result: pass. The production diff is exactly one import replacement: `CodexWatcher.AppServerClient` was replaced with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- Command: `git diff --name-only`
  Result: pass. Changed tracked files are `orchestrator/state.json` and `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`; the state file was pre-existing coordination state outside reviewer write scope and was not edited by this review.
- Command: `rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`
  Result: pass. No matches; the target file no longer imports the public compatibility facade.
- Command: `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.Agent\.Codex\.Client[[:space:]]+\(AppServerTurn\)' src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`
  Result: pass. Found `9:import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- Command: `rg -n 'classifyIssuePlanningTurn|prop_turnClassifier|issue planning|IssuePlanning|quickCheckResult|testGroup|tasty|hspec' test src`
  Result: pass. Focused selector discovery shows the relevant assertions in `test/Main.hs` as plain `watcher-core-test` coverage, including `prop_turnClassifierCompletionStates`, `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, and `prop_turnClassifierBlocksMissingOutputs`.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher core test executable passed; the log reports `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal src/CodexWatcher/AppServerClient.hs`
  Result: pass. Empty diff; no package descriptor or public facade exposure changed.
- Command: `test ! -e orchestrator/rounds/round-107/worker-plan.json`
  Result: pass. No worker fan-out artifact exists.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `jq empty orchestrator/state.json`
  Result: pass. The coordination state file remains valid JSON.
- Command: `jq empty orchestrator/rounds/round-107/review-record.json`
  Result: pass. The review record written by this review is valid JSON.

### Plan Compliance
- Re-check coordination context: met. Reviewed `selection.md`, `plan.md`, `implementation-notes.md`, `orchestrator/project-contract.md`, and the active verification bundle.
- Inspect the target import and use sites: met. The old facade import supplied only `AppServerTurn`; classifier helpers remain imported from `CodexWatcher.Turn.Classifier.Common`.
- Replace only the selected target import: met. The only production code diff is the import replacement in `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`.
- Preserve issue-planning classifier behavior and structured-output semantics: met. No classifier logic, constructors, parsing, missing-output behavior, invalid-payload behavior, planning-graph parsing, or structured blocked/incomplete/complete handling changed; `watcher-core-test` passed.
- Confirm no package descriptor, public facade exposure, docs, fixtures, tests, or other AppServerClient importers changed: met. Descriptor/facade diff was empty, and `git diff --name-only` shows no source/test/docs/fixture/package changes besides the selected target file.
- Confirm no worker fan-out artifact: met. `worker-plan.json` does not exist.

### Decision
**APPROVED**

### Evidence
The integrated round matches the selected extraction exactly: `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` now imports `AppServerTurn` from `CodexWatcher.Workflow.Agent.Codex.Client`, and no `CodexWatcher.AppServerClient` import remains in that target file. The diff does not change issue-planning observation constructors, classifier logic, JSON parsing, structured-output semantics, missing-output behavior, package descriptors, public facade exposure, docs, fixtures, tests, or other AppServerClient importers.

The public `CodexWatcher.AppServerClient` facade remains available and unchanged. This approval is merge-ready for round 107 after normal controller merge handling, but it is not approval for facade deprecation/removal, Cabal exposure changes, package publication, docs/fixture updates, endpoint/session/protocol changes, timeout/fallback changes, failure-formatting changes, or migration of any other importer.
