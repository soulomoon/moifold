### Changes Made
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: replaced the single `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports:
  - `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), nextRequestId)`
  - `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..))`
- `orchestrator/rounds/round-185/implementation-notes.md`: recorded implementation evidence for this round.

Exact source diff summary:
- Removed one import line from `CodexWatcher.Core.Ids`.
- Added two explicit direct-owner import lines.
- No term, type signature, event, command rendering, app-server classification, request-id progression, runtime compatibility, test, docs, Cabal, roadmap, or state behavior was changed.
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs` was not edited.

### Tests
- No tests were edited. Existing focused watcher-core behavior coverage was used as evidence for this import-only migration.

Verification commands and results:
- `cabal build all`: passed. The build recompiled `CodexWatcher.Domain.IssuePlanning.Loop` with the direct owner imports and completed the `moifold` executable build.
- `cabal test watcher-core-test`: passed. Result: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed with no output.
- `rg -n "import CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: no matches; `rg` exited 1 as expected for the migrated selected-file scan.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: passed with both direct-owner imports:
  - line 40: `CodexWatcher.Workflow.Agent.Ids`
  - line 41: `CodexWatcher.Workflow.GitHub.Ids`
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal *.cabal`: passed as a classification scan. `moifold.cabal` appeared twice because the requested argument list includes both `moifold.cabal` and `*.cabal`; counted once below.

Broad remaining `Core.Ids` classification:
- Production users:
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38` imports `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RequestId`, and `ThreadId` from `CodexWatcher.Core.Ids`. This is the expected out-of-scope production remainder for a later round.
- Public facade:
  - `src/CodexWatcher/Core/Ids.hs:1` remains the public compatibility facade module.
- Tests/fixtures:
  - `test/FacadeImportPolicySpec.hs:11`
  - `test/WorkflowEventLogSpec.hs:65`
  - `test/RuntimeSpec.hs:30`
  - `test/CliSpec.hs:14`
  - `test/Main.hs:67`
  - `test/WorkflowIndexedSpec.hs:66`
  - `test/WorkflowAgentSpec.hs:66`
  - `test/WorkflowExecutionSpec.hs:65`
  - `test/RuntimeCompatibilityFixtureSpec.hs:11`
  - `test/TestSupport/Workflow.hs:98`
- Docs:
  - `docs/agentic-workflow-framework/release-candidate-bundle.md:70`
  - `docs/agentic-workflow-framework/release-notes.md:98`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`
- Cabal:
  - `moifold.cabal:46` exposes `CodexWatcher.Core.Ids`.
- App:
  - no matches under `app`.

Focused planning-loop behavior evidence from `watcher-core-test`:
- `test/Main.hs` wires and passed the planning-loop checks named by the plan:
  - `automaticDaemonLoopPlanningDryRunStartsSyntheticTurn`: synthetic planner thread id and request-id progression.
  - `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` and `automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread`: planner thread startup, issue snapshot write order, repo/issue rendering, and turn-start behavior.
  - `automaticDaemonLoopPlanningIssueCreationRequestsReplanning`, `automaticDaemonLoopPlanningGraphWaitsAndRecords`, `automaticDaemonLoopPlanningGraphDropsClosedDependencies`, and `automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage`: planning observations, graph normalization, repo/issue command rendering, and daemon transitions.
  - `automaticPlanningSystemErrorRetriesWatcher` and `automaticPlanningSystemErrorBlocksAfterRetryLimit`: app-server `systemError` classification, retry behavior, and failure text.
  - `prop_eventLogIssuePlanningIssueCreationReturnsReady`, `prop_eventLogIssuePlanningGraphWaitsForReadyIssues`, `prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning`, `prop_eventLogIssuePlanningRetryReentersPlanning`, and the `prop_issuePlanningWatcher...` checks: event append/order and watcher transitions.
- `test/WorkflowIndexedSpec.hs` wires and passed the indexed issue-planning daemon compatibility checks named by the plan:
  - `workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility`
  - `workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility`
  - `workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility`
  - `workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility`
  - terminal/retry indexed daemon compatibility checks for compiled request ids, append/write ordering, audit labels, and daemon transition parity.

### Notes
The migration was safe as an import-only direct-owner split. There was no compile-time package-boundary blocker and no focused behavior failure. This round does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.
