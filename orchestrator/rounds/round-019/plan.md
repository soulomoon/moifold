### Goal

Route the item-019 live `IssueImplement` plan-mode and PR setup daemon observations through the moifold-owned indexed `IssueImplement` projection while preserving the existing daemon-loop probes, command parsing, action order, compatibility writes, dry-run text, and request-id behavior.

### Approach

Keep PR discovery, branch advancement, PR creation/reuse parsing, `issue-plan.md` recording, and PR body rendering in the existing moifold daemon loop. Do not move that ownership into `agent-workflow-core` or into the indexed adapter.

Use the indexed adapter only at the daemon observation preparation boundary in `src/CodexWatcher/Daemon.hs`, after the existing loop code has already produced the same compatibility `DaemonIssueImplementObservation` values as today. Add an `IssueImplement` equivalent of `preparedFromIssuePlanningProjection` and extend `prepareDaemonObservation` for only this round's states/observations:

1. `IssueReadyToPlan` + `ObservedPlanTurnStarted` via `projectIssueImplementPlanTurnStartedObservation`.
2. `IssueInPlanMode` + `ObservedPlanCompleted` via `projectIssueImplementPlanCompletedObservation`.
3. `IssueReadyToPlan` + `ObservedIssueWorkerThreadRefreshed` via `projectIssueImplementWorkerThreadRefreshedReadyToPlanObservation`; this is the live follow-up refresh path reached by `runIssueReadyToPlan`.
4. `IssueImplementationReady` + `ObservedIssueAttemptBranchAdvanced` via `projectIssueImplementAttemptBranchAdvancedObservation`.
5. `IssueImplementationReady` + `ObservedPullRequestCreated` via `projectIssueImplementPullRequestCreatedImplementationReadyObservation`.
6. `IssueImplementationReady` + `ObservedPullRequestReused` via `projectIssueImplementPullRequestReusedImplementationReadyObservation`.
7. `IssuePlanReady` + `ObservedPullRequestBodyUpdated` via `projectIssueImplementPullRequestBodyUpdatedPlanReadyObservation`.

Leave all other `IssueImplement` observations on the existing compatibility fallback in this item, including implementation-turn observations, review handoff, PR merge-wait, post-merge review, issue close, child lifecycle paths, and PR setup blocking observations not listed above. This keeps the round bounded to item 019 and avoids pulling item 020+ behavior forward.

### Steps

1. Import `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` qualified in `src/CodexWatcher/Daemon.hs`.
2. Add `preparedFromIssueImplementProjection` beside `preparedFromIssuePlanningProjection`, returning `PreparedDaemonObservation` from `issueImplementIndexedProjectionPlanned` and `issueImplementIndexedProjectionFinalState`.
3. Add the seven `prepareDaemonObservation` cases listed in the approach, before the legacy fallback. Each case should call the indexed projector and then `preparedFromIssueImplementProjection`.
4. Do not change `src/CodexWatcher/Domain/IssueImplement/Loop.hs` behavior other than imports only if the implementation discovers a compile need. In particular, keep these flows intact:
   - `runIssueReadyToPlan` still decides between follow-up worker refresh and `loopPrestartAndObserve`.
   - `runIssuePlanActive` still uses `classifyIssuePlanTurn`.
   - `runIssuePlanReady` still delegates to `updatePullRequestBody`.
   - `observeExistingPullRequest`, `advanceMergedAttemptBranchOrCreatePullRequest`, `retryCreatePullRequest`, and `updatePullRequestBody` still own GitHub probes, command parsing, report prepending, and action ordering.
5. Update the existing source-scan guard `workflowIssueImplementIndexedAdapterDoesNotRouteLiveDaemonPaths` in `test/Main.hs` into a narrower guard such as `workflowIssueImplementIndexedDaemonRoutingIsLimitedToPlanAndPrSetup`. It should allow the new `Daemon.hs` import/projectors but still fail if `IssueImplement.Indexed`, `IssueImplementIndexedSpec`, or `projectIssueImplement` appears in `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/*.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, or `src/CodexWatcher/AutomaticLoop/Output.hs`.
6. Add a second source-scan guard for `src/CodexWatcher/Daemon.hs` that forbids item-020+ projectors and observations in the indexed routing table, including `projectIssueImplementationTurnStartedObservation`, `projectIssueImplementationIncompleteObservation`, `projectIssueImplementationBlocked`, `projectIssueImplementReviewHandoff`, `projectIssueImplementPullRequestMerged`, `projectIssueImplementReviewerThreadReady`, `projectIssueImplementPostMerge`, and `projectIssueImplementIssueClosed`.
7. Add focused daemon projection parity tests in `test/Main.hs` for dry-run and execute mode. The tests should compare `runObservedDaemonTickWithEvents` against both `workflowPlanObservation @MoifoldSpec` and the indexed projector for:
   - plan turn start,
   - plan completion,
   - follow-up worker refresh,
   - attempt-branch advancement,
   - PR created,
   - PR reused,
   - PR body update.
8. Extend the existing automatic-loop PR setup tests to assert the routed daemon tick still matches the indexed projection where relevant:
   - `automaticIssueFollowUpRefreshesWorkerBeforePlanTurn`,
   - `automaticDaemonLoopRetriesPrCreateWhileWaitingForPr`,
   - `automaticDaemonLoopAdvancesMergedAttemptBranchBeforePrCreate`,
   - `automaticDaemonLoopUpdatesNewPrBodyBeforeImplementation`,
   - `automaticDaemonLoopUpdatesReusedPrBodyBeforeImplementation`.
   Keep `automaticDaemonLoopBlocksUnlinkedBranchPr` as a behavior-preservation test for the compatibility fallback unless the reviewer explicitly asks to route PR setup blocking in this item.
9. Ensure the PR body update test proves `RecordIssuePlan` still runs before `UpdatePullRequestBody` and before the `IssuePullRequestBodyUpdatedEvent` append. The existing `automaticDaemonLoopWritesPlanBeforePlanCompletedEvent` and PR-body tests are useful anchors, but this item needs a direct PR-body indexed-routing assertion too.
10. Ensure the PR create/reuse tests still prove `parseGhPrCreateResult`, report prepending, dry-run text (`would create pull request...` / `would update pull request body...`), PR URL compatibility writes, and no-app-server request-id stability remain unchanged.

### Verification

Run the focused regression target after adding the tests:

```sh
cabal test watcher-core-test
```

Run the full roadmap baseline before review:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If the implementation stages changes before review or merge, also run:

```sh
git diff --cached --check
```

Run these source-scan guards manually if a test failure needs a quick diagnosis:

```sh
rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" \
  src/CodexWatcher/Domain/IssueImplement/Loop.hs \
  src/CodexWatcher/DaemonLoop.hs \
  src/CodexWatcher/DaemonLoop \
  src/CodexWatcher/AutomaticLoop/Runner.hs \
  src/CodexWatcher/AutomaticLoop/Output.hs
```

```sh
rg -n "projectIssueImplementationTurnStartedObservation|projectIssueImplementationIncompleteObservation|projectIssueImplementationBlocked|projectIssueImplementReviewHandoff|projectIssueImplementPullRequestMerged|projectIssueImplementReviewerThreadReady|projectIssueImplementPostMerge|projectIssueImplementIssueClosed" \
  src/CodexWatcher/Daemon.hs
```

The first scan should return no matches. The second scan should return no matches for this round. The only allowed indexed `IssueImplement` routing in `Daemon.hs` should be the seven item-019 projectors named in the approach.
