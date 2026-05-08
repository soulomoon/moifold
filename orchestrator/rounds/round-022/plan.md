### Goal
Route the live IssueImplement post-merge review daemon observations for item 022 through the existing moifold-owned indexed IssueImplement projection, while preserving the current compatibility behavior and leaving terminal issue close and lifecycle hardening for later roadmap items.

This round covers post-merge reviewer thread readiness that is already on the route, final-review turn start, final-review classifier outcomes for clean, rework-required, incomplete, and blocked, plus the resulting follow-up effects. It must not route `ObservedIssueClosed`, terminal issue close polling, child lifecycle, repair, healthcheck, or item-023+ observations.

### Approach
Keep the daemon loop and domain loop ownership unchanged. `runIssuePostMergeReviewPendingReviewer`, `runIssuePostMergeReviewReady`, and `runIssuePostMergeReviewing` should continue producing the same `DaemonIssueImplementObservation` values and the same external failure text. Only `CodexWatcher.Daemon.prepareDaemonObservation` should learn to prepare the selected post-merge observations through `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed`, then project back to the existing `PreparedDaemonObservation` shape via `preparedFromIssueImplementProjection`.

Use the existing indexed projectors rather than adding new workflow-core API:

- `projectIssueImplementPostMergeReviewStartedObservation`
- `projectIssueImplementPostMergeReviewerOutcomeCleanObservation`
- `projectIssueImplementPostMergeReviewerOutcomeReworkObservation`
- `projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation`
- `projectIssueImplementPostMergeReviewerOutcomeBlockedObservation`

Preserve moifold ownership of `IssueFinalReviewOutcome`, final-review classification, reviewed-commit validation, prompt-version validation, missing-field diagnostics, reviewer-thread app-server starts, GitHub follow-up and close commands, compatibility writes, and detailed daemon transaction failures.

### Steps
1. Add focused daemon routing cases in `src/CodexWatcher/Daemon.hs` immediately after the existing post-merge reviewer-ready and merge-wait IssueImplement routes:
   - `IssuePostMergeReviewReady` plus `ObservedPostMergeReviewStarted commit turnId` routes to `projectIssueImplementPostMergeReviewStartedObservation`.
   - `IssuePostMergeReviewing` plus `ObservedPostMergeReviewerOutcome (IssueFinalReviewClean evidence)` routes to `projectIssueImplementPostMergeReviewerOutcomeCleanObservation`.
   - `IssuePostMergeReviewing` plus `ObservedPostMergeReviewerOutcome (IssueFinalReviewRework evidence)` routes to `projectIssueImplementPostMergeReviewerOutcomeReworkObservation`.
   - `IssuePostMergeReviewing` plus `ObservedPostMergeReviewerOutcome (IssueFinalReviewIncomplete reason)` routes to `projectIssueImplementPostMergeReviewerOutcomeIncompleteObservation`.
   - `IssuePostMergeReviewing` plus `ObservedPostMergeReviewerOutcome (IssueFinalReviewBlocked reason)` routes to `projectIssueImplementPostMergeReviewerOutcomeBlockedObservation`.
2. Do not change `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, or the event/replay/effect definitions except as tests require. These modules should continue to own PR `headRefOid` reads, missing `headRefOid` failure text, app-server final-review turn starts, structured-output classification, and effect interpretation.
3. Extend `test/Main.hs` daemon parity coverage:
   - Add `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPostMergeReviewProjections`.
   - Add `issueImplementDaemonPostMergeReviewProjectionCases` using existing prefixes/states or local equivalents for:
     - final-review turn start from `IssuePostMergeReviewReady`;
     - clean final review to `IssueWaitingForIssueClose` with `CloseIssueTag` then `SleepUntilNextPollTag`;
     - rework-required final review to `IssueImplementationReady` with `UpdateIssueFollowUpTag` then `SleepUntilNextPollTag`;
     - incomplete final review back to `IssuePostMergeReviewReady` with `SleepUntilNextPollTag`;
     - blocked final review to `BlockedState` with `RecordBlockedTag` then `StopDaemonTag`.
   - Run these cases through both `DryRunActions` and `ExecuteActions` using the existing `runIssueImplementDaemonProjectionCase` helper so the assertions cover event parity, pre/post effect plan parity, compiled action/request-id parity, compatibility writes, event append ordering, final state label, replay source state, and detailed transaction result shape.
4. Keep or strengthen automatic-loop behavior tests around the real post-merge loop:
   - `automaticIssueMergeWaitsForIssueClose` must still prove reviewer-thread creation when absent, no reviewer-thread start when already present, final-review target commit from PR `headRefOid`, clean-to-close behavior, and closed issue completion through the old item-023 route.
   - `automaticIssueFinalReviewFindingsRequestRework` must still prove rework-to-follow-up, next attempt branch selection, `UpdateIssueFollowUp`, and no `GhIssueClose` on rework.
   - Add a small assertion only if the new indexed route is otherwise unproven by daemon parity: final-review clean/rework observed ticks match the corresponding indexed projection.
5. Update source-scan guard `workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors`:
   - Move item-022 projector names from forbidden to required: `projectIssueImplementPostMergeReviewStartedObservation` and the four `projectIssueImplementPostMergeReviewerOutcome*Observation` names.
   - Continue requiring item-020 and item-021 projectors.
   - Keep item-023+ forbidden needles for `projectIssueImplementIssueClosed`, `ObservedIssueClosed`, and the issue-close daemon route.
   - Keep `projectIssueImplementPullRequestMergedWaitingForIssueCloseObservation` forbidden unless a test-only policy parity case still references it outside `src/CodexWatcher/Daemon.hs`; the guard should scan daemon routing, not the indexed policy adapter itself.
6. Preserve the package boundary guard `workflowIssueImplementIndexedDaemonRoutingIsLimitedToDaemonProjectionOnly`: indexed routing imports remain confined to `src/CodexWatcher/Daemon.hs`, and loop/runtime/automatic modules must not import `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed`, `projectIssueImplement*`, or `IssueImplementIndexedSpec`.
7. Leave item-023 and item-024 behavior untouched:
   - `IssueWaitingForIssueClose` plus `ObservedIssueClosed` must still fall through compatibility routing.
   - Do not alter `runIssueWaitingForIssueClose`, issue close polling, `IssueClosedEvent`, `StopDaemon`, issue-implementer child lifecycle, repair, healthcheck, or fanout.

### Verification
Run focused tests before the full suite:

1. `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`
2. `cabal test watcher-core-test --test-option=--match --test-option='automatic issue merge waits for issue close'`
3. `cabal test watcher-core-test --test-option=--match --test-option='automatic issue final review findings request rework'`
4. `cabal test watcher-core-test --test-option=--match --test-option='turn classifier maps domain outputs'`

Then run the roadmap baseline:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`
4. `git diff --cached --check` only if changes are staged later by an implementer or integrator.

Manual/source-scan guards to record in implementation notes:

- `rg -n "ObservedIssueClosed|projectIssueImplementIssueClosed|runIssueWaitingForIssueClose" src/CodexWatcher/Daemon.hs src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/Domain/IssueImplement/Loop.hs` must show issue-close routing remains unported for item 023.
- `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|IssueImplementIndexedSpec|projectIssueImplement" src/CodexWatcher/Domain src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop` must show no indexed import or projector use outside daemon projection.
- `rg -n "projectIssueImplementPostMergeReviewStartedObservation|projectIssueImplementPostMergeReviewerOutcome" src/CodexWatcher/Daemon.hs test/Main.hs` must show the item-022 routes and tests are present.
- `rg -n "IssueFinalReviewOutcome|reviewerPromptVersion|reviewed_commit_sha|final review state missing required fields|merged PR #.*headRefOid" src/CodexWatcher/Domain/IssueImplement test/Main.hs` must confirm classifier and missing-field/head-ref diagnostics stayed in the domain layer and tests.
