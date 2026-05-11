### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer contract requires checking the round diff, plan, active verification bundle, project contract, implementation notes, and writing explicit review artifacts only.

- Command: `sed -n '1,240p' orchestrator/rounds/round-108/selection.md`
  Result: pass; selected item is `round-108-issue-implement-turn-classifier-appserverclient-import-convergence` under roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, scoped to moving only `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` from `CodexWatcher.AppServerClient` to `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.

- Command: `sed -n '1,260p' orchestrator/rounds/round-108/plan.md`
  Result: pass; plan permits one production import replacement plus verification, with no classifier logic, JSON parsing, observation constructor, public facade, package descriptor, fixture, docs, or other importer changes.

- Command: `sed -n '1,260p' orchestrator/rounds/round-108/implementation-notes.md`
  Result: pass; implementation notes report only the target import replacement and validation evidence, with preserved non-goals.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; contract requires public compatibility facades and package/module boundaries to remain available until exact removal gates are approved.

- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline gates are `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`; import convergence is not deprecation or removal approval.

- Command: `jq '{roadmap_id, roadmap_revision, roadmap_dir, controller_stage, active_rounds, current_round_id, last_completed_round}' orchestrator/state.json`
  Result: pass; active state points at roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, round `round-108`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, stage `review`.

- Command: `git diff -- src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; production diff removes `import CodexWatcher.AppServerClient` and adds `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)` with no classifier definition or export changes.

- Command: `git diff --name-only`
  Result: pass with note; tracked diff reports `orchestrator/state.json` and `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`. The only production change is the selected target file. `orchestrator/state.json` was pre-existing controller state for the active round and was not edited by the reviewer. `git status --short` shows the round artifact directory as untracked, including selection, plan, implementation notes, and the reviewer-owned artifacts.

- Command: `rg -n "CodexWatcher\\.AppServerClient|AppServerTurn|classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyIssueFinalReviewTurn|classifyTurnCompletion" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; target now imports `AppServerTurn` from the direct owner at line 16 and still exposes/uses the issue-plan, implementation, final-review, and common completion classifier paths.

- Command: `rg -n "agent-workflow-codex|CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|CodexWatcher\\.Domain\\.IssueImplement\\.TurnClassifier|test-suite watcher-core-test" cabal.project moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
  Result: pass; `agent-workflow-codex` is already in `cabal.project`, the direct-owner module is exposed by `agent-workflow-codex`, the target module remains in `moifold.cabal`, and `watcher-core-test` exists.

- Command: `rg -n "classifyIssuePlanTurn|classifyIssueImplementationTurn|classifyIssueFinalReviewTurn|classifyTurnCompletion|turn classifier|issue final review|implementation turn completed|plan turn completed" test src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; discovered classifier coverage in `test/Main.hs` and `test/TestSupport/Workflow.hs` for plan, implementation, final-review, missing-output blocking, structured outcomes, expected-commit validation, PR-number completion, reviewer-thread completion, malformed/missing state, and clean/rework/blocked/incomplete final-review cases.

- Command: `rg -n "getArgs|withArgs|TASTY|hspec|defaultMain|testGroup|prop_turnClassifier" test/Main.hs test/TestSupport/Workflow.hs test/*.hs`
  Result: pass; found direct `quickCheckResult` call sites for `prop_turnClassifierCompletionStates`, `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, and `prop_turnClassifierBlocksMissingOutputs`, but no reliable named Tasty/Hspec selector. Full `watcher-core-test` is the correct behavior gate.

- Command: `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; no old facade import remains in the target.

- Command: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client \\(AppServerTurn\\)" src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
  Result: pass; selected direct-owner import found at line 16.

- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal cabal.project agent-workflow-codex 2>/dev/null || true`
  Result: pass; scan records remaining allowed facade users outside this selected target, including `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`, runtime/CLI modules, tests, docs, `src/CodexWatcher/AppServerClient.hs`, and `moifold.cabal`. This round did not migrate other importers or remove the public facade.

- Command: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
  Result: pass; descriptor/facade diff is empty.

- Command: `test ! -e orchestrator/rounds/round-108/worker-plan.json`
  Result: pass; no worker fan-out artifact exists.

- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal build all`
  Result: pass; build reported `Up to date`.

- Command: `git diff --check`
  Result: pass; no whitespace errors.

- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

- Command: `jq empty orchestrator/state.json`
  Result: pass; controller state JSON is valid after review artifact writing.

- Command: `jq empty orchestrator/rounds/round-108/review-record.json`
  Result: pass; review record JSON is valid after writing.

### Plan Compliance
- Re-read selected scope, project contract, and verification bundle: met; selection, project contract, and active verification bundle were inspected.
- Confirm target dependency is only `AppServerTurn`: met; target scan shows the direct-owner `AppServerTurn` import and unchanged classifier entry points.
- Confirm direct-owner reachability without descriptor edits: met; `agent-workflow-codex` and owner module exposure already exist, and descriptor/facade diff is empty.
- Discover focused classifier test reachability: met; classifier properties are reached by `quickCheckResult` in `test/Main.hs`, with no focused named selector found, so the full `watcher-core-test` gate was used.
- Edit only the selected production import: met for production code; the only production diff is the one-line import replacement in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`.
- Run target import convergence scans: met; old target import has no matches and direct-owner import is present.
- Run scope checks and worker-plan absence check: met; no worker-plan artifact exists, and no unrelated production/test/doc/package/runtime/fixture change appears in the round diff.
- Verify descriptor and public-facade surfaces stayed untouched: met; `moifold.cabal`, `cabal.project`, `agent-workflow-codex/agent-workflow-codex.cabal`, and `src/CodexWatcher/AppServerClient.hs` have an empty diff.
- Run behavior and build gates: met; `cabal test watcher-core-test` and `cabal build all` passed.
- Run whitespace checks: met; `git diff --check` and `git diff --cached --check` passed.
- Preserve non-goals: met; no public facade removal/deprecation, Cabal exposure change, docs/fixtures/tests/protocol change, other importer migration, milestone completion, or terminal completion was made or claimed.

### Decision
**APPROVED**

This round is merge-ready after normal controller merge handling. Approval is limited to the selected single-import convergence in `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`.

This approval explicitly excludes public facade removal or deprecation, Cabal exposure changes, docs/fixtures/tests/protocol changes, migration of any other importer, milestone completion, terminal completion, release approval, or publication approval.

### Evidence
The implementation exactly replaces the target module's public compatibility-facade import with the selected direct-owner import:

```diff
-import CodexWatcher.AppServerClient
+import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)
```

No classifier exports, type signatures, parsing logic, behavior branches, prompts, endpoint/session handling, timeout/fallback code, command rendering, failure formatting, fixtures, public facades, package descriptors, or other importers changed.

The behavior evidence is the full `watcher-core-test` pass. The test discovery scan shows the relevant classifier properties and examples cover `classifyTurnCompletion`, `classifyIssuePlanTurn`, `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`, missing-output blocking, structured complete/incomplete/blocked outcomes, expected-commit validation, PR-number completion, reviewer-thread completion, malformed/missing state, and final-review clean/rework/blocked/incomplete behavior.

The package-boundary evidence is that `agent-workflow-codex` remains listed in `cabal.project`, `CodexWatcher.Workflow.Agent.Codex.Client` remains exposed by `agent-workflow-codex`, and descriptor/facade files have no diff. The broader facade scan still shows remaining allowed `CodexWatcher.AppServerClient` users and the public facade itself, confirming this round did not imply removal.
