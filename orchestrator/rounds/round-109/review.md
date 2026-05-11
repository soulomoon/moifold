### Checks Run
- Command: `sed -n '1,220p' orchestrator/rounds/round-109/selection.md`
  Result: pass. Selection names roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, and extracted item `round-109-pr-review-turn-classifier-appserverclient-import-convergence`. Scope is one importer in `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`.
- Command: `sed -n '1,220p' orchestrator/rounds/round-109/plan.md`
  Result: pass. Plan requires replacing only the `CodexWatcher.AppServerClient` import with `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`, preserving classifier behavior and public facade/package surfaces.
- Command: `sed -n '1,260p' orchestrator/rounds/round-109/implementation-notes.md`
  Result: pass. Notes report the single production import replacement, no test edits, no descriptor/facade edits, and preserved non-goals.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract requires public compatibility facades to remain available and says import convergence is not deprecation, Cabal exposure removal, compatibility-file deletion, facade deletion, release approval, or publication approval.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass. Verification bundle requires `cabal build all`, `cabal test watcher-core-test`, diff whitespace checks, facade import convergence scans, and preservation of public compatibility facades.
- Command: `git diff --name-only`
  Result: pass. Tracked production diff contains only `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`; `orchestrator/state.json` is controller state for active round 109. Round artifacts are untracked under `orchestrator/rounds/round-109/`.
- Command: `git diff -- src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  Result: pass. Diff is exactly one import removal and one direct-owner import addition; classifier code and exports are unchanged.
- Command: `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  Result: pass. Target uses `AppServerTurn` at classifier signatures and imports it from the direct owner at line 16; no target `CodexWatcher.AppServerClient` match remains.
- Command: `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.PrReview\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass. `agent-workflow-codex` is in `cabal.project`, `CodexWatcher.Workflow.Agent.Codex.Client` is exposed, and the target module plus `watcher-core-test` are in `moifold.cabal`.
- Command: `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  Result: pass. No old import remains in the target.
- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  Result: pass. Direct-owner import found at line 16.
- Command: `rg -n "classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion|reviewerStateOutput|reviewer-state|worker turn completed|reviewer turn completed|prior_findings_status|new_findings_status|solved_threads|remaining_review_threads|reviewer_prompt_version|LGTM" test src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
  Result: pass. Discovery found direct classifier assertions in `test/Main.hs`, shared coverage in `test/TestSupport/Workflow.hs`, indexed classifier coverage in `test/WorkflowIndexedSpec.hs`, and workflow agent coverage in `test/WorkflowAgentSpec.hs`.
- Command: `rg -n "quickCheckResult|tasty|hspec|classifyPrReviewTurn|prReviewTurn" test/Main.hs test/WorkflowIndexedSpec.hs test/TestSupport/Workflow.hs test/WorkflowAgentSpec.hs moifold.cabal`
  Result: pass. No focused selector exists; `test/Main.hs` enumerates `quickCheckResult` calls directly, including PR-review protocol/watcher and turn-classifier properties. Full `watcher-core-test` is the correct fallback.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs moifold.cabal cabal.project agent-workflow-codex agent-workflow-core agent-workflow-github`
  Result: pass. Remaining facade users exist in other source/test/docs paths and `moifold.cabal` exposed modules, which matches the selection's non-goals. The target `PrReview/TurnClassifier.hs` is no longer listed.
- Command: `git diff -- src app test docs '*.cabal' cabal.project agent-workflow-codex agent-workflow-core agent-workflow-github`
  Result: pass. Only production change is the selected `TurnClassifier.hs` import replacement.
- Command: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
  Result: pass. Descriptor/facade diff is empty.
- Command: `test ! -e orchestrator/rounds/round-109/worker-plan.json`
  Result: pass. No worker fan-out artifact exists.
- Command: `git diff --check`
  Result: pass. No whitespace diagnostics.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace diagnostics.
- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass. Up to date.
- Command: `jq empty orchestrator/state.json`
  Result: pass. Active controller state JSON is valid before writing the review record.

### Plan Compliance
- Re-read selected scope and shared invariants: met. Selection, project contract, and verification bundle were inspected.
- Inspect target dependency and classifier entry points: met. Target now imports only `AppServerTurn` from `CodexWatcher.Workflow.Agent.Codex.Client`; `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`, and `classifyTurnCompletion` entry points remain present.
- Confirm direct-owner availability and target build membership: met. Cabal scan shows `agent-workflow-codex` package membership, exposed `CodexWatcher.Workflow.Agent.Codex.Client`, and `watcher-core-test` coverage.
- Discover PR-review classifier tests: met. Evidence exists in `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowAgentSpec.hs`. No focused selector exists; full suite was run.
- Edit only the selected production import: met. Production diff is one import replacement in `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`.
- Old-import target scan: met. No target `import CodexWatcher.AppServerClient` remains.
- Direct-owner import target scan: met. Exact `AppServerTurn` import is present.
- Reject behavior changes: met. No classifier logic, exports, JSON parsing, observation constructors, endpoint/session behavior, timeout/fallback, command rendering, failure formatting, prompts, fixtures, docs, package descriptors, or public facade exposure changed.
- Descriptor/facade preservation: met. `moifold.cabal`, `cabal.project`, `agent-workflow-codex/agent-workflow-codex.cabal`, and `src/CodexWatcher/AppServerClient.hs` have empty diff.
- Worker fan-out artifact: met. `worker-plan.json` does not exist.
- Baseline validation: met. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

### Decision
**APPROVED**

This round is merge-ready after normal controller merge handling. Approval is limited to the selected import convergence only and explicitly excludes public facade removal/deprecation, Cabal exposure changes, docs/fixtures/tests/protocol changes, endpoint/session/timeout/fallback/command/failure-formatting changes, other importer migration, milestone completion, or terminal completion.

### Evidence
The selected production diff moves only `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` from the public compatibility import to `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. The target old-import scan is empty, the direct-owner import scan finds line 16, and the descriptor/facade diff is empty.

Classifier behavior is covered by the existing `watcher-core-test` driver: direct and shared tests exercise `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`, `classifyTurnCompletion`, missing-output blocking, structured worker outcomes, reviewer-state JSON parsing, reviewed-commit validation, reviewer prompt-version validation, prior/new findings status handling, LGTM handling, solved/remaining review-thread handling, and incomplete/blocked reviewer outcomes. `cabal test watcher-core-test` passed, and `cabal build all` is up to date.

Remaining `CodexWatcher.AppServerClient` users in other source/test/docs paths and the exposed `moifold.cabal` facade entry are intentionally preserved by the plan and project contract. No public facade removal, deprecation, package exposure change, protocol change, endpoint/session behavior change, or broader importer migration is approved by this review.
