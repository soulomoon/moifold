### Changes Made
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: replaced the public compatibility facade import `CodexWatcher.AppServerClient` with the selected direct-owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- `orchestrator/rounds/round-108/implementation-notes.md`: recorded implementation scope, validation evidence, and preserved non-goals for review.

Exact diff summary:
- Removed one import line: `import CodexWatcher.AppServerClient`.
- Added one import line: `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- Classifier exports, type signatures, parsing, classification logic, prompts, endpoint/session handling, timeout/fallback behavior, command rendering, failure formatting, fixtures, public facades, and package descriptors were not changed.

### Tests
- `test/Main.hs` and `test/TestSupport/Workflow.hs`: existing classifier coverage discovered for `classifyTurnCompletion`, `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, and `classifyIssueFinalReviewTurn`, including missing-output blocking, structured complete/incomplete/blocked outcomes, malformed JSON, expected-commit validation, PR-number completion, reviewer-thread completion, and final-review clean/rework/blocked/incomplete behavior.
- Focused selector discovery: `rg -n "getArgs|withArgs|TASTY|hspec|defaultMain|testGroup|prop_turnClassifier" test/Main.hs test/TestSupport/Workflow.hs test/*.hs` found the classifier properties and direct `quickCheckResult` call sites, but no reliable named Tasty/Hspec selector. The full `watcher-core-test` suite was used as the fallback gate.

Validation commands and results:
- `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyIssueFinalReviewTurn|classifyTurnCompletion" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: confirmed the selected dependency was only `AppServerTurn`.
- `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.IssueImplement\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`: confirmed `agent-workflow-codex` is already in `cabal.project`, the owner module is exposed by `agent-workflow-codex`, the target module is in `moifold.cabal`, and `watcher-core-test` exists.
- `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: passed, no old import remains in the target.
- `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: passed, selected direct-owner import found at line 16.
- `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`: passed, descriptor/facade diff empty.
- `test ! -e orchestrator/rounds/round-108/worker-plan.json`: passed, no worker fan-out artifact exists.
- `cabal test watcher-core-test`: passed, 1 of 1 test suites passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
Non-goals preserved:
- No classifier logic, JSON parsing, observation constructor, prompt, endpoint/session, timeout/fallback, command rendering, failure formatting, fixture, public API, package descriptor, Cabal exposure, facade exposure, deprecation, removal, release, milestone-completion, or terminal-completion change was made.
- `CodexWatcher.AppServerClient` remains available as a public compatibility facade.
- No other `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission` importer was migrated.

Scope notes:
- Changed paths owned by this implementation are `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` and `orchestrator/rounds/round-108/implementation-notes.md`.
- `git diff --name-only` also reports `orchestrator/state.json`, which was already modified before this implementation and was not edited for this round.
