### Goal
Move only `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerTurn` from its direct owner, while preserving the existing PR-review worker, reviewer, and turn-completion classification behavior.

### Approach
Keep this round to a single production import convergence. The selected module currently imports `CodexWatcher.AppServerClient` only to name `AppServerTurn` in type signatures and classifier entry points. Replace that facade import with the exact direct-owner import:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
```

Do not change classifier logic, JSON parsing, PR-review observation constructors, endpoint/session handling, app-server protocol, timeout/fallback behavior, command rendering, failure formatting, prompts, fixtures, docs, public facades, package descriptors, or any other importer. `CodexWatcher.AppServerClient` must remain exposed and available as a public compatibility facade.

No worker fan-out is justified: the edit target is one import line in one source file, the verification is shared and sequential, and splitting it would add coordination risk without isolating ownership.

### Steps
1. Re-read the selected round scope and shared invariants before editing:
   - `sed -n '1,220p' orchestrator/rounds/round-109/selection.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
2. Inspect the target module and confirm the selected dependency is only `AppServerTurn` while the classifier entry points stay in place:
   - `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
3. Confirm the direct-owner package/module is already available and the target module is already part of the main library/test build:
   - `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.PrReview\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
4. Discover focused PR-review classifier test reachability before running the broader suite:
   - `rg -n "classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion|reviewerStateOutput|reviewer-state|worker turn completed|reviewer turn completed|prior_findings_status|new_findings_status|solved_threads|remaining_review_threads|reviewer_prompt_version|LGTM" test src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
   - If this reveals a focused Tasty/Hspec selector for the classifier coverage, run that selector first.
   - If no focused selector exists, record that discovery and fall back to the required full `watcher-core-test`.
5. Edit only `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`:
   - remove `import CodexWatcher.AppServerClient`
   - add `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`
   - do not touch any other import unless the compiler requires only local formatting/order adjustment in the same file.
6. Check the target import result immediately:
   - old import must have no matches in the target: `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
   - direct-owner import must be present in the target: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
7. Inspect the production diff and reject any behavior change:
   - `git diff -- src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
   - The diff should be the single import replacement only.
8. Prove package descriptors and public compatibility facade stayed untouched:
   - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
9. Run scope checks excluding unrelated files:
   - `git diff --name-only`
   - The only production path changed by the implementer should be `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`; controller artifacts under `orchestrator/rounds/round-109/` may be present, and pre-existing `orchestrator/state.json` dirtiness must not be edited by the implementer.
   - Confirm no other selected facade importer was migrated: `git diff -- src app test docs '*.cabal' cabal.project agent-workflow-codex agent-workflow-core agent-workflow-github`
10. Do not create `orchestrator/rounds/round-109/worker-plan.json`.

### Verification
Required checks for the implementer:

- Target old-import scan has no matches:
  `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- Target direct-owner import scan finds the exact import:
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- Relevant classifier test discovery scan:
  `rg -n "classifyPrReviewWorkerTurn|classifyPrReviewReviewerTurn|classifyTurnCompletion|reviewerStateOutput|reviewer-state|worker turn completed|reviewer turn completed|prior_findings_status|new_findings_status|solved_threads|remaining_review_threads|reviewer_prompt_version|LGTM" test src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- If a focused selector is discovered, run it first and record the exact command/result. If no focused selector exists, record that and rely on the full suite below.
- Full classifier/regression suite:
  `cabal test watcher-core-test`
- Full build:
  `cabal build all`
- Descriptor/facade diff empty:
  `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
- No worker fan-out artifact:
  `test ! -e orchestrator/rounds/round-109/worker-plan.json`
- Whitespace checks:
  `git diff --check`
  `git diff --cached --check`

Behavior that must remain covered by the existing tests or focused selector evidence: `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`, `classifyTurnCompletion`, missing-output blocking, structured worker outcomes, reviewer-state JSON parsing, reviewed-commit validation, reviewer prompt-version validation, prior/new findings status handling, LGTM handling, solved/remaining review-thread handling, and incomplete/blocked reviewer outcomes.
