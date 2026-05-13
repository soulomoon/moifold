### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`, so the current tree is buildable.

- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass with no output.

- Command: `git diff --cached --check`
  Result: pass with no output. No staged changes were present.

- Command: `git diff -- src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. The only source change removes the combined `CodexWatcher.Core.Ids` import and adds direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

- Command: `git diff -- src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  Result: pass with no output. The expected later production user was not edited.

- Command: `git diff --name-only -- docs app test moifold.cabal '*.cabal' orchestrator/roadmaps src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Runtime src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  Result: pass with no output. No tests, docs, Cabal files, roadmap files, runtime compatibility files, or public facade modules changed.

- Command: `rg -n "import CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. No matches; `rg` exited 1 as expected for the selected migrated file.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  Result: pass. Found both direct-owner imports:
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:40`: `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), nextRequestId)`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:41`: `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..))`

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal *.cabal 2>/dev/null`
  Result: pass as a classification scan. `moifold.cabal` appears twice because the requested arguments include both `moifold.cabal` and `*.cabal`; counted once below.
  - Remaining production user: `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38`
  - Public facade: `src/CodexWatcher/Core/Ids.hs:1`
  - Tests/fixtures: `test/FacadeImportPolicySpec.hs:11`, `test/WorkflowEventLogSpec.hs:65`, `test/RuntimeSpec.hs:30`, `test/CliSpec.hs:14`, `test/Main.hs:67`, `test/WorkflowIndexedSpec.hs:66`, `test/WorkflowAgentSpec.hs:66`, `test/WorkflowExecutionSpec.hs:65`, `test/RuntimeCompatibilityFixtureSpec.hs:11`, `test/TestSupport/Workflow.hs:98`
  - Docs: `docs/agentic-workflow-framework/release-notes.md:98`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100`, `docs/agentic-workflow-framework/release-candidate-bundle.md:70`
  - Cabal exposure: `moifold.cabal:46`
  - App: no matches.

- Command: `rg -n "module CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.Ids|CodexWatcher\\.AppServerClient|module CodexWatcher\\.Workflow\\.EventLog|module CodexWatcher\\.Workflow\\.Permission" src/CodexWatcher/Core/Ids.hs src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs moifold.cabal`
  Result: pass. The public compatibility facades remain present and exposed; `moifold.cabal` still exposes `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids`.

- Command: `rg -n "automaticDaemonLoopPlanningDryRunStartsSyntheticTurn|automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart|automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread|automaticDaemonLoopPlanningIssueCreationRequestsReplanning|automaticDaemonLoopPlanningGraphWaitsAndRecords|automaticDaemonLoopPlanningGraphDropsClosedDependencies|automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage|automaticPlanningSystemErrorRetriesWatcher|automaticPlanningSystemErrorBlocksAfterRetryLimit|prop_eventLogIssuePlanningIssueCreationReturnsReady|prop_eventLogIssuePlanningGraphWaitsForReadyIssues|prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning|prop_eventLogIssuePlanningRetryReentersPlanning|prop_issuePlanningWatcher|workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility|workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility|workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility|workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility|terminal|retry" test/Main.hs test/WorkflowIndexedSpec.hs test/Workflow*.hs test/TestSupport/Workflow.hs`
  Result: pass. The focused planning-loop checks named by the plan are present and wired into the passing `watcher-core-test` suite.

### Plan Compliance
- Inspect current selected-file facade import: met. The original selected-file diff shows the `CodexWatcher.Core.Ids` import covered `IssueNumber`, `RepoName`, `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId` only.

- Replace with direct owner imports: met. `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:40-41` now imports agent ids and GitHub ids directly.

- Make no other source, test, fixture, roadmap, Cabal, docs, runtime compatibility, or public-facade changes: met. The only changed source/test/docs/Cabal/roadmap/runtime/public-facade path is the selected source file. `orchestrator/state.json` already reflects the active review round; I did not edit it.

- Do not broaden the round or add package exposure changes: met. No Cabal/package changes were made, and `cabal build all` passed with the direct owner imports.

- Record focused planning-loop behavior evidence: met. The passing `watcher-core-test` run covered:
  - request-id progression and synthetic thread/turn ids through `automaticDaemonLoopPlanningDryRunStartsSyntheticTurn` and the indexed daemon request-id checks;
  - planner thread startup, active turn handling, repo/issue/sub-issue command rendering, and issue snapshot write-before-start through `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` and `automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread`;
  - planning observations, repo/issue rendering, graph normalization, event append/write ordering, daemon transitions, and compatibility parity through the issue-creation, graph, event-log property, watcher property, and indexed daemon compatibility checks;
  - app-server `systemError` classification, retry behavior, and failure text through `automaticPlanningSystemErrorRetriesWatcher` and `automaticPlanningSystemErrorBlocksAfterRetryLimit`.

- Record broad remaining `Core.Ids` scan by category: met. The only remaining production user is `src/CodexWatcher/Domain/IssueImplement/Loop.hs`; public facade, test/fixture, docs, Cabal, and app categories are separated above.

- Keep roadmap and project-contract boundaries: met. This review does not approve public facade deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### Decision
**APPROVED**

### Evidence
The integrated source change is import-only and limited to `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`. It removes the compatibility facade import and uses the direct id owner modules that compile under the current package graph. The expected later production user, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, has no diff and remains the only remaining production `CodexWatcher.Core.Ids` user in the broad scan.

Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Focused planning-loop behavior is covered by the passing watcher-core tests wired in `test/Main.hs` and `test/WorkflowIndexedSpec.hs`, including request-id progression, thread/turn ids, repo/issue rendering, event append order, daemon transitions, app-server turn classification, and failure text.

No tests, docs, Cabal files, roadmap files, runtime compatibility files, or public facade modules were changed. Public compatibility modules and Cabal exposure remain available.
