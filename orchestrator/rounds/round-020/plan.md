### Goal
Route the live IssueImplement implementation-turn daemon observations for `IssueImplementationReady` and `IssueImplementing` through the moifold-owned indexed IssueImplement projection, then project back to the existing daemon transaction surface without changing daemon result shapes, dry-run text, request-id progression, action ordering, compatibility writes, event schemas, or later IssueImplement lifecycle routing.

This round covers only implementation worker turn start, implementation incomplete, implementation blocked, implementation completed, and implementation-ready worker refresh behavior. It must not route review handoff, PR merge waiting, post-merge review, follow-up, issue close, child lifecycle, plan-mode and PR setup paths already covered by item 019, or any later observations.

### Approach
Keep policy ownership in `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` and keep daemon-loop mechanics in the existing loop modules. The indexed adapter already exposes the item-020 projection helpers, so the implementation should add only the missing live routing in `CodexWatcher.Daemon.prepareDaemonObservation`, using `preparedFromIssueImplementProjection` exactly like item 019.

The loop should continue to discover observations the same way:

- `runIssueImplementationReady` still uses `StartIssueImplementationWorkerTurnKind` and emits `ObservedImplementationTurnStarted`.
- `runIssueImplementing` still uses active-turn classification and `classifyIssueImplementationTurn`.
- The classifier still handles structured output, missing output, completed-before-known-PR, incomplete, blocked, and completed outcomes.
- Worker refresh still comes from the existing `ObservedIssueWorkerThreadRefreshed` path, but only for `IssueImplementationReady` is newly live-routed in this item.

Tests should extend the existing item-019 daemon projection harness rather than creating a second harness. Rename the plan/PR setup daemon parity test and case list to cover item-020 implementation-worker projections as well, add the missing cases, and update the source-scan guard so item-021+ projectors remain forbidden while item-020 projectors are required/allowed.

### Steps
1. Update `src/CodexWatcher/Daemon.hs` in `prepareDaemonObservation` to route these exact `(state, observation)` pairs through indexed projections:
   - `IssueImplementationReady` + `ObservedIssueWorkerThreadRefreshed threadId` via `projectIssueImplementWorkerThreadRefreshedImplementationReadyObservation`.
   - `IssueImplementationReady` + `ObservedImplementationTurnStarted turnId` via `projectIssueImplementationTurnStartedObservation`.
   - `IssueImplementationReady` + `ObservedImplementationBlocked reason` via `projectIssueImplementationBlockedImplementationReadyObservation`.
   - `IssueImplementing` + `ObservedImplementationIncomplete reason` via `projectIssueImplementationIncompleteObservation`.
   - `IssueImplementing` + `ObservedImplementationBlocked reason` via `projectIssueImplementationBlockedImplementingObservation`.
   - `IssueImplementing` + `ObservedImplementationCompleted prNumber maybeReviewerThreadId` via `projectIssueImplementationCompletedImplementingObservation`.
2. Preserve the existing fallback to `observeDaemonState` for all other IssueImplement observations, especially `ObservedReviewHandoffInitialized`, `ObservedReviewHandoffStarted`, `ObservedIssueReviewerThreadReady`, `ObservedPullRequestMerged`, `ObservedPostMergeReviewStarted`, `ObservedPostMergeReviewerOutcome`, `ObservedIssueClosed`, and later-state `ObservedImplementationCompleted` idempotence.
3. Extend `test/Main.hs` daemon parity coverage:
   - Rename `workflowIssueImplementIndexedDaemonDryRunAndExecuteMatchPlanAndPrSetupProjections` to include implementation worker routing, and update the test list entry.
   - Rename `issueImplementDaemonPlanAndPrSetupProjectionCases` accordingly.
   - Add dry-run and execute projection cases for worker refresh from implementation-ready, implementation turn start, incomplete restart, blocked from implementation-ready, blocked from implementing, successful completion with reviewer thread, successful completion without reviewer thread, completed-before-known-PR classified as incomplete, and stale PR completion blocking.
   - For each case assert the existing harness invariants: compatibility event parity, indexed event parity, planned pre/post effects, compiled effects and request ids, final state shape/label, replay source state, compatibility writes, execute commit/appends, and dry-run non-mutation.
4. Add or extend automatic daemon-loop behavior tests where the projection harness alone does not prove the live observation was discovered:
   - Implementation-ready with known PR starts the app-server turn, emits `IssueImplementationTurnStartedEvent`, schedules `StartIssueImplementationWorkerTurn`, and advances the app-server request id.
   - Active implementation turn incomplete emits `IssueImplementationIncompleteEvent`, restarts by planning `StartIssueImplementationWorkerTurn`, and preserves restart-on-incomplete behavior.
   - Active implementation turn missing output emits `IssueImplementationBlockedEvent`, records blocked state, stops the daemon, and does not silently restart.
   - Active implementation turn complete with no known PR remains incomplete instead of handoff-ready.
   - Active implementation turn complete with stale PR blocks rather than handing off.
5. Update source-scan guards in `test/Main.hs`:
   - Keep indexed imports/projectors forbidden from `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/DaemonLoop.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, `src/CodexWatcher/DaemonLoop/Runtime.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, and `src/CodexWatcher/AutomaticLoop/Output.hs`.
   - Replace the item-020-plus guard with an item-021-plus guard: allow and require the item-020 projector names in `Daemon.hs`, but keep later route names forbidden (`projectIssueImplementReviewHandoff*`, `projectIssueImplementPullRequestMerged*`, `projectIssueImplementReviewerThreadReady*`, `projectIssueImplementPostMerge*`, `projectIssueImplementIssueClosed*`, and idempotent later-state `projectIssueImplementationCompletedHandoff*`/`WaitingForPrMerge*`).
   - Keep observation needles for review handoff, reviewer-thread-ready, pull-request-merged, post-merge, and issue-closed forbidden in the newly indexed `Daemon.hs` routing block.
6. Do not change `CodexWatcher.Workflow.Indexed.*`, `agent-workflow-core`, event codecs, golden fixtures, public compatibility facades, child lifecycle code, runtime command rendering, prompt schemas, or structured-output field requirements.
7. Record implementation notes after coding with the changed files and exact evidence, but do not stage or commit as part of the implementation worker unless the orchestrator role for that later phase explicitly asks.

### Verification
Run focused checks first:

- `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon'`
- `cabal test watcher-core-test --test-option=--match --test-option='automatic implementation'`
- `cabal test watcher-core-test --test-option=--match --test-option='implementation turn'`

Then run the baseline contract:

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` only if the later implementation phase stages changes.

Run source-scan guards explicitly if the focused matcher does not isolate them:

- `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon routing'`
- `cabal test watcher-core-test --test-option=--match --test-option='indexed workflow issue implement daemon does not route'`

Reviewer evidence must show:

- `DaemonTickResult`, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, detailed transaction failure text, dry-run reports, audit labels, action ordering, event append ordering, request-id progression, and compatibility write timing remain compatible.
- `StartIssueImplementationWorkerTurn`, active-turn classification, structured output parsing, missing-output blocking, completed-before-known-PR incomplete behavior, stale PR mismatch blocking, restart-on-incomplete behavior, and `ImplementationBlocked` stop behavior are preserved.
- Item-021+ routes remain on compatibility fallback.
- The recursive/package-boundary assertions still prove indexed core does not import moifold lifecycle policy, `IssueConfig`, `IssueFinalReviewOutcome`, app-server transport, GitHub adapters, daemon/runtime interpreters, Aeson event codecs, concrete `WatcherEvent`, concrete `SomeWatcherState`, child lifecycle, or compatibility write ownership.
