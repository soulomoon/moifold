### Goal
Migrate or classify the single production `CodexWatcher.Core.Ids` import in
`src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, preserving issue-planning loop
behavior and leaving `src/CodexWatcher/Domain/IssueImplement/Loop.hs` for a
later round.

### Approach
Use a one-file import-only migration by replacing the combined compatibility
facade import with the direct owner modules that already expose the required
identifiers:

- `CodexWatcher.Workflow.Agent.Ids` for `RequestId (..)`, `ThreadId (..)`,
  `TurnId (..)`, and `nextRequestId`.
- `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber (..)` and
  `RepoName (..)`.

Do not change request-id progression, planner thread/turn handling, repo/issue
rendering, event append order, daemon transition behavior, app-server turn
classification, failure text, public facade exposure, Cabal exposure, docs,
runtime compatibility files, or tests. Do not use worker fan-out; this is a
single source-file slice with one verification path.

If the import split fails to compile or focused evidence shows behavior drift,
do not broaden the round. Restore the source behavior for
`IssuePlanning/Loop.hs` if needed and classify the exact blocker in the round
implementation notes for reviewer and roadmap-update use.

### Steps
1. Inspect the current `CodexWatcher.Core.Ids` import in
   `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and confirm the imported
   names are only `IssueNumber`, `RepoName`, `RequestId`, `ThreadId`, `TurnId`,
   and `nextRequestId`.
2. Replace that import with direct imports from
   `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`,
   keeping the export lists explicit and preserving formatting near the
   surrounding imports.
3. Make no other source, test, fixture, roadmap, Cabal, docs, runtime
   compatibility, or public-facade changes.
4. If the compiler reports missing package exposure or missing exports for the
   direct-owner modules, inspect only enough to identify whether this is a real
   package-boundary blocker. Do not add dependencies or alter Cabal in this
   round unless the reviewer can approve it as strictly necessary for this
   selected file; otherwise classify the blocker.
5. Record implementation evidence for the focused planning-loop behavior
   surfaces covered by existing tests: request-id progression, planner
   thread/turn ids, repo/issue command rendering, issue snapshot rendering,
   event append order, daemon state transitions, app-server turn
   classification, retry/block failure text, and graph/event behavior.
6. Record the broad remaining `Core.Ids` scan by category: remaining production
   users, `src/CodexWatcher/Core/Ids.hs` public facade, tests/fixtures, docs,
   and Cabal exposure. The expected production remainder after a successful
   migration is `src/CodexWatcher/Domain/IssueImplement/Loop.hs` only.

### Verification
Run the baseline commands:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

Run selected import scans:

1. `rg -n "import CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
   - For a successful migration this must return no matches.
2. `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
   - Confirm the file imports both direct owner modules.
3. `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal *.cabal 2>/dev/null`
   - Classify matches separately as production users, public facade,
     tests/fixtures, docs, and Cabal exposure. Do not count
     `src/CodexWatcher/Core/Ids.hs`, docs, Cabal, or tests as remaining
     production users.

For focused behavior evidence, cite the relevant checks exercised by
`cabal test watcher-core-test`, including:

- `automaticDaemonLoopPlanningDryRunStartsSyntheticTurn` for dry-run synthetic
  planner thread/turn ids and request-id progression.
- `automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart` and
  `automaticDaemonLoopPlanningExecuteStartsFreshPlannerThread` for planner
  thread startup, issue snapshot writes, repo/issue/sub-issue rendering, and
  turn-start behavior.
- `automaticDaemonLoopPlanningIssueCreationRequestsReplanning`,
  `automaticDaemonLoopPlanningGraphWaitsAndRecords`,
  `automaticDaemonLoopPlanningGraphDropsClosedDependencies`, and
  `automaticDaemonLoopPlanningGraphCanonicalizesOpenScopeCoverage` for
  planning observations, repo/issue command rendering, graph normalization, and
  daemon transitions.
- `automaticPlanningSystemErrorRetriesWatcher` and
  `automaticPlanningSystemErrorBlocksAfterRetryLimit` for app-server
  system-error classification, retry behavior, and failure text.
- `prop_eventLogIssuePlanningIssueCreationReturnsReady`,
  `prop_eventLogIssuePlanningGraphWaitsForReadyIssues`,
  `prop_eventLogIssuePlanningReadyIssuesFixedReentersPlanning`,
  `prop_eventLogIssuePlanningRetryReentersPlanning`, and the
  `prop_issuePlanningWatcher...` checks for event append/order and watcher
  transitions.
- `workflowIssuePlanningIndexedDaemonDryRunMatchesCompatibility`,
  `workflowIssuePlanningIndexedDaemonExecuteMatchesCompatibility`,
  `workflowIssuePlanningIndexedDaemonDryRunMatchesActiveTurnCompatibility`,
  `workflowIssuePlanningIndexedDaemonExecuteMatchesActiveTurnCompatibility`,
  and the terminal/retry indexed daemon checks for compatibility projection,
  audit labels, compiled request ids, append/write ordering, and daemon
  transition parity.

If the migration is classified instead of landed, verification must still run
`git diff --check` and the broad scan, then record why the selected file remains
a production `Core.Ids` user and why that reason is a blocker rather than a
public facade, test, docs, Cabal, or runtime compatibility surface.
