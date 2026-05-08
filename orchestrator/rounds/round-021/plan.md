### Goal
Route the live IssueImplement review-handoff and PR merge-wait observations through the moifold-owned indexed IssueImplement projection while preserving the existing daemon transaction surface.

This round covers only:
- `ObservedReviewHandoffInitialized`
- `ObservedReviewHandoffStarted`
- `ObservedImplementationCompleted` idempotence after handoff
- `ObservedIssueReviewerThreadReady`
- `ObservedPullRequestMerged` from `IssueWaitingForPrMerge`

It must not route post-merge reviewer turn starts, post-merge reviewer outcomes, issue close, follow-up, child lifecycle, or item-022+ observations.

### Approach
Keep all runtime behavior in the current IssueImplement daemon loop. `src/CodexWatcher/Domain/IssueImplement/Loop.hs` should continue to perform PR merge polling with `runGhPrView`, emit the current idle text when the PR is not merged, initialize/start handoff in the same order, and create/reuse reviewer threads through the existing app-server path.

The implementation change belongs in `src/CodexWatcher/Daemon.hs`: extend `prepareDaemonObservation` so the selected observations are projected with the existing functions in `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed`, then converted back with `preparedFromIssueImplementProjection`. This keeps `DaemonObservedTickResult`, detailed transaction failures, event commits, compatibility writes, compiled effects, audit labels, and request-id behavior on the same prepared transaction path used by earlier rounds.

Do not move any IssueImplement policy, GitHub command execution, app-server start logic, compatibility writes, or event codecs into indexed core. The indexed adapter remains a typed projection over moifold-owned compatibility behavior.

### Steps
1. In `src/CodexWatcher/Daemon.hs`, add `prepareDaemonObservation` cases for handoff initialization:
   - `IssueHandoffReady` plus `ObservedReviewHandoffInitialized` via `projectIssueImplementReviewHandoffInitializedHandoffReadyObservation`.
   - `IssueHandoffInitialized` plus duplicate `ObservedReviewHandoffInitialized` via `projectIssueImplementReviewHandoffInitializedHandoffInitializedObservation`.
   - `IssueWaitingForPrMerge` plus duplicate `ObservedReviewHandoffInitialized` via `projectIssueImplementReviewHandoffInitializedWaitingForPrMergeObservation`.

2. Add handoff-start cases:
   - `IssueHandoffInitialized` plus `ObservedReviewHandoffStarted` via `projectIssueImplementReviewHandoffStartedHandoffInitializedObservation`.
   - `IssueWaitingForPrMerge` plus duplicate `ObservedReviewHandoffStarted` via `projectIssueImplementReviewHandoffStartedWaitingForPrMergeObservation`.

3. Add implementation-completed idempotence cases after handoff:
   - `IssueHandoffReady` via `projectIssueImplementationCompletedHandoffReadyObservation`.
   - `IssueHandoffInitialized` via `projectIssueImplementationCompletedHandoffInitializedObservation`.
   - `IssueWaitingForPrMerge` via `projectIssueImplementationCompletedWaitingForPrMergeObservation`.
   These must preserve wrong-PR blocking and the no-op/idempotent behavior for the expected PR.

4. Add reviewer-thread-ready cases:
   - `IssueHandoffReady` via `projectIssueImplementReviewerThreadReadyHandoffReadyObservation`.
   - `IssueHandoffInitialized` via `projectIssueImplementReviewerThreadReadyHandoffInitializedObservation`.
   - `IssueWaitingForPrMerge` via `projectIssueImplementReviewerThreadReadyWaitingForPrMergeObservation`.
   - `IssuePostMergeReviewPendingReviewer` via `projectIssueImplementReviewerThreadReadyPostMergeReviewPendingReviewerObservation`.
   - `IssuePostMergeReviewReady` via `projectIssueImplementReviewerThreadReadyPostMergeReviewReadyObservation`.
   These are still reviewer-thread-ready observations, not post-merge reviewer turn starts or outcomes.

5. Add the PR merge observation case only for `IssueWaitingForPrMerge`:
   - `ObservedPullRequestMerged` via `projectIssueImplementPullRequestMergedWaitingForPrMergeObservation`.
   Do not add `prepareDaemonObservation` routes for `projectIssueImplementPullRequestMergedPostMergeReview*`, `projectIssueImplementPostMergeReviewStartedObservation`, `projectIssueImplementPostMergeReviewerOutcome*`, or `projectIssueImplementIssueClosedObservation`.

6. Extend `test/Main.hs` policy/projection coverage only as needed if existing `workflowIssueImplementIndexedSpecMatchesCompatibilityForPolicyTransitions` cases are missing any selected projector. Existing policy cases already cover most handoff and merge-wait projectors; keep them intact rather than weakening or deleting them.

7. Add a focused daemon parity test function, registered in the main test list, for this route slice. Reuse `IssueImplementDaemonProjectionCase` and `runIssueImplementDaemonProjectionCase` so dry-run and execute both assert:
   - event equality between compatibility and indexed projection,
   - final state label and shape equality,
   - effect plan and compiled request-id equality,
   - `DaemonObservedTickResult` fields,
   - commit-before-compatibility-write ordering in execute mode,
   - compatibility writes and audit labels.

8. Include daemon projection cases for:
   - handoff initialization from handoff-ready, duplicate initialization from handoff-initialized, and duplicate initialization while waiting for merge,
   - handoff start from handoff-initialized and duplicate start while waiting for merge,
   - implementation completion idempotence from handoff-ready, handoff-initialized, and waiting-for-merge,
   - wrong-PR completion or handoff observation blocking,
   - reviewer-thread-ready from handoff-ready, handoff-initialized, waiting-for-merge, post-merge pending reviewer, and post-merge ready,
   - pull-request-merged from waiting-for-merge with and without an existing reviewer thread,
   - wrong-PR merge blocking from waiting-for-merge.

9. Add or extend automatic-loop tests around `runIssueWaitingForPrMerge` without changing the loop:
   - an open PR keeps using `gh pr view` and returns the idle reason `waiting for PR merge before post-merge review: #<pr>`,
   - a merged PR emits `IssuePullRequestMergedEvent` through the indexed daemon route,
   - when the reviewer thread is already known, the merge observation reaches `IssuePostMergeReviewReady` without starting a new reviewer thread,
   - when no reviewer thread is known, the merge observation reaches `IssuePostMergeReviewPendingReviewer` and the next reviewer-thread-ready observation is routed through indexed projection.

10. Replace the current item-021-negative source scan in `workflowIssueImplementIndexedDaemonDoesNotRouteLaterProjectors` with an item-022+ guard:
    - require the new item-021 projector names in `src/CodexWatcher/Daemon.hs`;
    - continue forbidding `projectIssueImplementPostMergeReviewStartedObservation`, `projectIssueImplementPostMergeReviewerOutcome`, `projectIssueImplementIssueClosedObservation`, `ObservedPostMergeReviewStarted`, `ObservedPostMergeReviewerOutcome`, and `ObservedIssueClosed` in `prepareDaemonObservation`;
    - keep `workflowIssueImplementIndexedDaemonRoutingIsLimitedToPlanPrSetupAndImplementationWorker` or rename it to reflect the wider allowed daemon route, but preserve its guard that loop/runtime/automatic-loop modules do not import `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` or call indexed projectors.

11. Keep source edits scoped to `src/CodexWatcher/Daemon.hs` and `test/Main.hs` unless a compile error exposes a necessary nearby test helper adjustment. Do not edit `orchestrator/state.json`, roadmap files, event schemas, golden fixtures, or compatibility facades.

### Verification
Run the focused test target first:

```sh
cabal test watcher-core-test --test-options='--pattern indexed workflow issue implement'
```

Then run the full round baseline:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

If files are staged later by the implementer or merger, also run:

```sh
git diff --cached --check
```

Manual source-scan guards to confirm after implementation:

```sh
rg -n "projectIssueImplement(PostMergeReviewStarted|PostMergeReviewerOutcome|IssueClosed)|ObservedPostMergeReviewStarted|ObservedPostMergeReviewerOutcome|ObservedIssueClosed" src/CodexWatcher/Daemon.hs
rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/DaemonLoop.hs src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop
```

The first scan should find no item-022+ daemon routes. The second scan should find no indexed IssueImplement imports or projectors outside `src/CodexWatcher/Daemon.hs`, preserving the existing loop/runtime boundary.
