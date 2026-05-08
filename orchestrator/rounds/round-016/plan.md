### Goal
Route the remaining issue-planning retry, blocked, scope-complete, ready-issues-fixed, and completed planning daemon observations through the moifold-owned indexed issue-planning adapter while preserving the existing daemon, fanout, event-log, compatibility, dry-run, execute, and failure surfaces.

### Approach
Keep the indexed adoption boundary in `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`. Add projection helpers for the remaining `IssuePlanningObservation` constructors, using the existing `projectIssuePlanningObservation` machinery and the same compatibility transition plan that `workflowObserve @MoifoldSpec` already produces. Do not move `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, `WatcherEvent`, daemon runtime, fanout policy, compatibility writes, Aeson codecs, or filesystem writes into core.

Update daemon routing in `src/CodexWatcher/Daemon.hs` so `prepareDaemonObservation` uses the indexed projection for every issue-planning observation, not just turn-start, issue-request, and graph-update. Preserve the existing prepared transaction runner, `DaemonObservedTickResult` shape, detailed `DaemonObservedTransactionFailure` mapping, audit formatting, dry-run/execute parity, compatibility write timing, action ordering, and request-id behavior.

For the direct fanout-side planning writes in `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`, keep lifecycle policy local to moifold but derive `ObservedPlanningReadyIssuesFixed` and `ObservedPlanningBlocked` ticks through the new indexed projection before appending events or writing compatibility state. Dry-run output should stay non-mutating and text-compatible; execute mode should keep the existing order: append event, write compatibility state from the projected final state, then print the same user-facing status.

Graph/request daemon observations are owned by item 015. Only touch their code if a shared helper or test fixture must be generalized to support this item; do not change their behavior or expectations.

### Steps
1. In `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, export and implement projection helpers for:
   - `projectIssuePlanningReadyIssuesFixedObservation` from `IssuePlanningIndexedWaitingReadyIssues` to `IssuePlanningIndexedInitialized` with labels `IssuePlanning/Initialized` -> `IssuePlanning/Initialized`.
   - `projectIssuePlanningScopeCompletedObservation` from `IssuePlanningIndexedInitialized` to `IssuePlanningIndexedComplete` with labels `IssuePlanning/Initialized` -> `IssuePlanning/Complete`.
   - `projectIssuePlanningTurnRetryObservation` from `IssuePlanningIndexedActiveTurn` to `IssuePlanningIndexedInitialized` with labels `IssuePlanning/PlanMode` -> `IssuePlanning/Initialized`.
   - `projectIssuePlanningTurnCompletedObservation` from `IssuePlanningIndexedActiveTurn` to `IssuePlanningIndexedComplete` with labels `IssuePlanning/PlanMode` -> `IssuePlanning/Complete`.
   - `projectIssuePlanningBlockedObservation` with explicit source-state entry points for initialized, active-turn, and waiting-ready-issues states, each targeting `IssuePlanningIndexedBlocked`.
2. In `src/CodexWatcher/Daemon.hs`, extend `prepareDaemonObservation` to route these source-state/observation pairs through the new indexed projectors:
   - `PlanningWaitingForReadyIssues` + `ObservedPlanningReadyIssuesFixed`.
   - `PlanningReady` + `ObservedPlanningScopeCompleted`.
   - `PlanningTurnActive` + `ObservedPlanningTurnRetryRequested`.
   - `PlanningTurnActive` + `ObservedPlanningTurnCompleted`.
   - `PlanningReady`, `PlanningTurnActive`, and `PlanningWaitingForReadyIssues` + `ObservedPlanningBlocked`.
3. Keep the fallback compatibility path for unrelated domains and for issue-planning observations outside this item. Invalid observations must still fail with the same `DaemonObservationRejected` text and must commit no event.
4. In `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`, replace the direct `issuePlanningObserve` event/state derivation in `blockPlanningFanout` and `markPlanningReadyIssuesFixed` with the indexed projection helpers. Preserve the current dry-run branches, current-state reload behavior, stale ready-issues marker skips, append/write order, and compatibility write paths.
5. Extend `test/Main.hs` focused indexed issue-planning tests:
   - Add projection assertions for the new helpers, including source/target labels, planned event, final state label, effect plan, replay effects, effect validation, effect permissions, request-id stability, and compatibility writes.
   - Add daemon dry-run and execute parity cases for ready-issues-fixed, scope-completed, retry, turn-completed, and blocked from initialized/active/waiting states.
   - Add invalid-observation cases for the new route helpers where compatibility rejects the observation, and assert no event is committed.
   - Strengthen existing automatic-loop systemError and missing-active-turn tests to prove the retry/block events still come through the daemon observed transaction surface with stable audit labels and compatibility writes.
   - Strengthen fanout tests around ready-issues completion and fanout blocking so the event append and compatibility writes still happen at the same boundary while using the indexed projection.
6. Re-check that `issuePlanningCompletionEvent` remains unchanged: graph update is still the fanout completion boundary; retry, completed turn, issue request, turn start, ready-issues-fixed, scope-completed, and blocked are not new fanout completion events unless an existing test already proves otherwise.
7. Re-check package boundaries with the existing recursive assertions: no moifold lifecycle policy, daemon/runtime code, `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, `WatcherEvent`, concrete state ownership, Aeson event codecs, app-server transport, or GitHub adapter ownership moves into `agent-workflow-core`.

### Verification
Run the focused watcher-core regression suite after implementation:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `cabal test watcher-core-test`
4. `git diff --check`
5. If changes are staged before review or merge: `git diff --cached --check`

The implementation notes should record focused evidence for the selected item: daemon dry-run/execute parity, `DaemonObservedTickResult`, detailed transaction failures, systemError retry/block behavior, missing active turn recovery, ready-issues fanout boundaries, fanout completion boundary, `issuePlanningCompletionEvent`, compatibility writes, action ordering, request-id progression, replay effects, effect validation, effect permissions, invalid-observation failures, and unchanged event JSON schemas/type labels/golden surfaces.
