### Goal
Move only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerTurn` from its direct owner, while preserving the existing issue-plan, issue-implementation, turn-completion, and final-review classifier behavior.

### Approach
Keep this round to a single production import convergence. The selected module currently imports `CodexWatcher.AppServerClient` only to name `AppServerTurn` in type signatures and classifier entry points. Replace that facade import with the exact direct-owner import:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
```

Do not change classifier logic, JSON parsing, observation constructors, prompts, endpoint/session handling, timeout/fallback behavior, command rendering, failure formatting, fixtures, public facades, or package descriptors. `CodexWatcher.AppServerClient` must remain exposed and available as a public compatibility facade.

Worker fan-out is not justified. This is one import line in one production module plus verification; there are no non-overlapping implementation ownership boundaries that would reduce risk.

### Steps
1. Re-read the selected scope and shared contract before editing:
   - `orchestrator/rounds/round-108/selection.md`
   - `orchestrator/project-contract.md`
   - `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
2. Inspect the target module and confirm the selected dependency is only `AppServerTurn`:
   - `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyIssueFinalReviewTurn|classifyTurnCompletion" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
3. Confirm direct-owner reachability without descriptor edits:
   - `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.IssueImplement\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
   - The evidence must show `agent-workflow-codex` is already in `cabal.project`, the owner module is exposed by `agent-workflow-codex`, and `watcher-core-test` can build against the current package graph.
4. Discover focused classifier test reachability before editing:
   - `rg -n "classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyIssueFinalReviewTurn|classifyTurnCompletion|turn classifier|issue final review|implementation turn completed|plan turn completed" test src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
   - Also scan the harness for a focused selector: `rg -n "getArgs|withArgs|TASTY|hspec|defaultMain|testGroup|prop_turnClassifier" test/Main.hs test/TestSupport/Workflow.hs test/*.hs`.
   - If the harness does not expose a reliable focused selector, record that discovery and use the full `cabal test watcher-core-test` gate.
5. Edit only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`:
   - remove `import CodexWatcher.AppServerClient`
   - add `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`
   - leave all classifier definitions and exports unchanged.
6. Run target import convergence scans:
   - old import must have no matches in the target: `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
   - direct-owner import must be present in the target: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
7. Run scope checks excluding unrelated files:
   - `git diff -- src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
   - `git diff --name-only`
   - The implementation diff must include no production/test/doc/package/runtime/fixture/roadmap/control-plane changes other than the target source file and the implementer notes artifact, if notes are used.
   - Confirm no worker fan-out artifact exists: `test ! -e orchestrator/rounds/round-108/worker-plan.json`.
8. Verify descriptor and public-facade surfaces stayed untouched:
   - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
   - If this command reports a diff, stop and revert only the implementer's own out-of-scope edits.
9. Run behavior and build gates sequentially:
   - `cabal test watcher-core-test`
   - `cabal build all`
   - These gates must preserve `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, `classifyTurnCompletion`, missing-output blocking, structured blocked/incomplete/complete outcomes, expected-commit validation, PR-number completion, reviewer-thread completion, malformed JSON handling, and final-review clean/rework/blocked/incomplete cases.
10. Run whitespace checks:
    - `git diff --check`
    - `git diff --cached --check`

### Verification
Required evidence for review:

- Target old-import scan has no matches:
  `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- Target direct-owner import scan finds exactly the selected import:
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- Relevant classifier test discovery scan was run, including whether a focused selector exists or why the full suite is the fallback.
- `cabal test watcher-core-test`
- `cabal build all`
- Descriptor/facade diff is empty:
  `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
- No worker plan was created:
  `test ! -e orchestrator/rounds/round-108/worker-plan.json`
- Scope checks show no unrelated files:
  `git diff --name-only`
- `git diff --check`
- `git diff --cached --check`
