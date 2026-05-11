### Changes Made
- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`: replaced the public compatibility facade import `CodexWatcher.AppServerClient` with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- `orchestrator/rounds/round-109/implementation-notes.md`: recorded the scoped change, validation evidence, and preserved non-goals for reviewer handoff.

### Tests
- No test files were changed. Existing classifier coverage was preserved.
- Focused classifier test discovery scan:
  - Command: `rg -n "classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion|reviewerStateOutput|reviewer-state|worker turn completed|reviewer turn completed|prior_findings_status|new_findings_status|solved_threads|remaining_review_threads|reviewer_prompt_version|LGTM" test src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  - Result: found classifier assertions in `test/Main.hs`, shared helpers in `test/TestSupport/Workflow.hs`, and indexed PR-review classifier coverage in `test/WorkflowIndexedSpec.hs`.
  - Focused selector result: no focused Tasty/Hspec selector exists; `test/Main.hs` is a hand-rolled QuickCheck driver enumerating `quickCheckResult` calls directly, so the required full `watcher-core-test` is the fallback.
- `cabal test watcher-core-test`: PASS, `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all`: PASS.

### Validation
- Selected scope and contract inspected:
  - `sed -n '1,220p' orchestrator/rounds/round-109/selection.md`
  - `sed -n '1,220p' orchestrator/project-contract.md`
- Target use-site scan:
  - `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  - Result before edit: target imported `CodexWatcher.AppServerClient`; `AppServerTurn` was used by `classifyPrReviewWorkerTurn` and `classifyPrReviewReviewerTurn`; classifier exports and logic entry points were unchanged by the edit.
- Direct-owner availability scan:
  - `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.PrReview\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  - Result: `agent-workflow-codex` is in `cabal.project`; `CodexWatcher.Workflow.Agent.Codex.Client` is exposed by `agent-workflow-codex`; `CodexWatcher.Domain.PrReview.TurnClassifier` and `watcher-core-test` are in `moifold.cabal`.
- Old-import target scan:
  - `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  - Result: PASS, no matches.
- Direct-owner import target scan:
  - `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  - Result: PASS, matched line 16.
- Production diff:
  - `git diff -- src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  - Result: single import replacement only.
- Descriptor/facade diff:
  - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
  - Result: PASS, empty diff.
- Scope diff:
  - `git diff -- src app test docs '*.cabal' cabal.project agent-workflow-codex agent-workflow-core agent-workflow-github`
  - Result: only `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` changed.
- No worker fan-out artifact:
  - `test ! -e orchestrator/rounds/round-109/worker-plan.json`
  - Result: PASS.
- Whitespace checks:
  - `git diff --check`
  - Result: PASS.
  - `git diff --cached --check`
  - Result: PASS.
  - Extra untracked-note hygiene: `git diff --no-index --check /dev/null orchestrator/rounds/round-109/implementation-notes.md`
  - Result: no whitespace diagnostics; command returned the expected non-zero diff status because the file is new under `--no-index`.

### Notes
- Exact diff summary: one production import was moved from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
- Non-goals preserved: no classifier logic, exports, PR-review observation constructors, protocol transitions, reviewer-state schema semantics, prompt-version policy, review-thread parsing, endpoint/session handling, timeout/fallback behavior, command rendering, failure formatting, prompts, fixtures, docs, package descriptors, Cabal exposed modules, public APIs, or public compatibility facade exposure were changed.
- `orchestrator/state.json` was already dirty in the worktree and was not edited by this implementer pass.
