### Changes Made
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports:
  - `CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId (..))`
  - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..))`
- `orchestrator/rounds/round-186/implementation-notes.md`: recorded round evidence.

Exact source diff summary:
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs | 3 ++-`
- `2 insertions(+), 1 deletion(-)`
- Diff is import-only; no use sites or behavior code changed.

### Tests
- No test files changed.
- Existing `watcher-core-test` coverage was used as behavior evidence for issue-implementation request-id threading, worker/reviewer thread handling, repo/issue/PR rendering, event append order, daemon transition behavior, app-server turn classification, command rendering, and failure text.

### Verification
- `cabal build all`: PASS. The changed module compiled as `CodexWatcher.Domain.IssueImplement.Loop` under GHC 9.12.2.
- `cabal test watcher-core-test`: PASS. Final output: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: PASS.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs`: no matches.
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/IssueImplement/Loop.hs`: PASS:
  - line 42: `CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId (..))`
  - line 45: `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..))`
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal agent-workflow-*/*.cabal`: remaining matches classified below.

### Broad Remaining Core.Ids Classification
- Production users: none remaining under `src/` except the public compatibility facade itself.
- Public facade: `src/CodexWatcher/Core/Ids.hs:1`.
- Cabal/package exposure: `moifold.cabal:46` exposes `CodexWatcher.Core.Ids`; not changed by this production-import slice.
- Tests/fixtures: `test/FacadeImportPolicySpec.hs:11`, `test/WorkflowEventLogSpec.hs:65`, `test/RuntimeSpec.hs:30`, `test/CliSpec.hs:14`, `test/Main.hs:67`, `test/RuntimeCompatibilityFixtureSpec.hs:11`, `test/WorkflowAgentSpec.hs:66`, `test/TestSupport/Workflow.hs:98`, `test/WorkflowIndexedSpec.hs:66`, `test/WorkflowExecutionSpec.hs:65`.
- Docs: `docs/agentic-workflow-framework/release-candidate-bundle.md:70`, `docs/agentic-workflow-framework/release-notes.md:98`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`.
- App matches: none.
- Standalone package candidate matches in `agent-workflow-*/*.cabal`: none.

### Focused Issue-Implementation Loop Behavior Evidence
- The full `watcher-core-test` run passed. QuickCheck properties in this runner print `+++ OK` without function labels, so the named properties below are evidenced by their `test/Main.hs` wiring plus the passing full target:
  - `prop_eventLogFullIssueImplementationPathCompletes` at `test/Main.hs:6851`
  - `prop_eventLogRefreshesIdleIssueWorkerThread` at `test/Main.hs:6854`
  - `prop_eventLogIssueIncompleteCanContinueToComplete` at `test/Main.hs:6863`
  - `prop_issueImplementWatcherIncompleteRestartsImplementation` at `test/Main.hs:6866`
  - `prop_issueImplementWatcherMergedStartsPostMergeReview` at `test/Main.hs:6869`
  - `prop_issueImplementWatcherBlockedStops` at `test/Main.hs:6873`
  - `prop_runtimeGhPrCreateKeepsStdoutJsonOnly` and `prop_runtimeGhPrBodyUpdateUsesPlanFile` at `test/Main.hs:6940-6941`
  - `prop_turnClassifierMapsDomainOutputs`, `prop_turnClassifierPrefersStructuredOutputs`, `prop_turnClassifierBlocksMissingOutputs`, `prop_effectInterpreterPrBodyUpdateUsesIssuePlan`, and `prop_effectInterpreterIssueTurnsUsePhaseSpecificPrompts` at `test/Main.hs:6980-6985`
- Indexed issue-implementation daemon projection groups are wired from `test/WorkflowIndexedSpec.hs:237-239`, including `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanPrSetupAndImplementationWorkerProjections` and `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections`.
- Request-id threading and app-server request progression PASS lines:
  - `PASS body-updated PR advances app-server request id`
  - `PASS indexed workflow issue implement implementation turn start matches compatibility request id`
  - `PASS indexed workflow issue implement daemon dry-run implementation turn start preserves planned effects and compiled request ids`
  - `PASS indexed workflow issue implement daemon execute implementation turn start preserves planned effects and compiled request ids`
- Worker and reviewer thread handling PASS lines:
  - `PASS issue follow-up refreshes worker thread before plan`
  - `PASS issue follow-up starts one replacement worker thread`
  - `PASS merged PR with existing reviewer does not start new reviewer thread`
  - `PASS post-merge review creates reviewer thread when absent`
  - `PASS post-merge reviewer-ready observation matches indexed projection`
- Repo/issue/PR rendering and command rendering PASS lines:
  - `PASS new PR body update writes plan before command`
  - `PASS new PR body update writes plan before event append`
  - `PASS reused PR body update writes plan before command`
  - `PASS reused PR body update writes plan before event append`
  - `PASS body-updated PR schedules implementation worker turn`
  - `PASS missing plan fails PR body update`
- Event append order and daemon transition behavior PASS lines:
  - `PASS automatic implementation completion records implementation completion first`
  - `PASS automatic implementation completion initializes handoff second`
  - `PASS automatic implementation completion starts handoff third`
  - `PASS indexed workflow issue implement daemon execute pull request body update commits event and compatibility writes`
  - `PASS indexed workflow issue implement daemon execute implementation incomplete restart commits event and compatibility writes`
  - `PASS indexed workflow issue implement daemon execute post-merge clean final review closes issue commits event and compatibility writes`
  - `PASS indexed workflow issue implement daemon execute issue close completes commits event and compatibility writes`
- App-server turn classification and failure text PASS lines:
  - `PASS automatic implementation incomplete reads active turn`
  - `PASS automatic implementation incomplete emits incomplete event`
  - `PASS automatic implementation missing output blocks`
  - `PASS automatic implementation missing output records blocked state`
  - `PASS automatic implementation complete without PR stays incomplete`
  - `PASS automatic implementation complete without PR restarts worker`

### Notes
- Migration was safe; no blocker classification was needed for `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.
- This round does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, test/fixture migration, runtime compatibility cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
