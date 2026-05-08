### Goal
Route the live issue-planning daemon start path for `PlanningReady` plus `ObservedPlanningTurnStarted` through the moifold-owned indexed issue-planning adapter, then project the indexed transition back to the existing daemon transaction result surfaces.

This round must preserve planner thread creation, planner turn start, app-server request-id progression, `DaemonTickResult`, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, dry-run and execute reports, action ordering, compatibility writes, `planning-state.json`, `issue-snapshot.json`, and invalid-observation failures. It must not route graph, request, terminal, retry, or blocked daemon observations, and must not move moifold lifecycle policy into `agent-workflow-core`.

### Approach
Keep the implementation sequential and narrow. Mirror the already-merged PR-review mergeability pattern: add an issue-planning indexed projection helper in `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed`, then teach `CodexWatcher.Daemon.prepareDaemonObservation` to use it only for `(PlanningReady, DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId))`.

The projection helper should call the generic indexed API with an `IssuePlanningIndexedState IssuePlanningIndexedInitialized` and an `IssuePlanningIndexedObservation IssuePlanningIndexedInitialized IssuePlanningIndexedActiveTurn`, then convert the planned indexed transition back to `PlannedTransition MoifoldSpec` with `issuePlanningIndexedTransitionToCompatibility`. The daemon should keep committing and executing through the existing moifold transaction runner so dry-run rendering, execute commits, compatibility writes, detailed failures, and audit construction remain unchanged.

Planner-thread creation and turn start stay in `CodexWatcher.Domain.IssuePlanning.Loop`: `runPlanningReady`, `ensureIssuePlanningSnapshot`, `ensurePlannerThread`, and `startPlannerTurn` continue to own snapshot writes, thread creation, stale planner-thread replacement, turn prestart, and request-id advancement. The indexed routing starts only after `loopPrestartAndObserve` has classified `ObservedPlanningTurnStarted`.

### Steps
1. Add a projection record and helper to `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, analogous to `PrReviewMergeabilityIndexedProjection` and `projectPrReviewMergeabilityCleanObservation`, for `PlanningReady -> PlanningTurnActive`.
2. Export the new projection type and helper from `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed`. Keep the helper in the moifold adapter module so core indexed workflow APIs remain generic and do not import `PlannerConfig`, app-server transport, daemon runtime, Aeson codecs, `WatcherEvent`, or concrete lifecycle policy.
3. Update `src/CodexWatcher/Daemon.hs` so `prepareDaemonObservation` matches only `SomeWatcherState PlanningReady {}` with `DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)` and uses the new indexed helper. Leave every other issue-planning observation on the existing compatibility `observeDaemonState` path for later roadmap items.
4. Preserve `PreparedDaemonObservation` shape and the existing dry-run/execute calls to `runWorkflowPreparedDryRunTransaction` and `runWorkflowPreparedExecuteTransactionDetailed`. Do not change `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, compatibility write calculation, audit construction, or event append logic.
5. Add focused tests in `test/Main.hs` that prove the start observation is now routed through the indexed projection while remaining behavior-compatible:
   - direct indexed projection from `PlanningReady` emits `IssuePlanningTurnStarted`, reaches plan mode, preserves source and target labels, and compiles the same `StartPlannerTurn` request-id progression as compatibility;
   - observed daemon dry-run for `ObservedPlanningTurnStarted` keeps the same event, reports, no-mutation behavior, compatibility writes, audit labels, and request-id progression;
   - observed daemon execute for `ObservedPlanningTurnStarted` keeps planner-turn app-server action before event append, writes compatibility state afterward, reaches plan mode, and preserves the committed event label;
   - invalid `ObservedPlanningTurnStarted` from a non-ready issue-planning state still fails as `DaemonObservationRejected` with no committed event.
6. Extend automatic-loop start coverage only as needed to pin the preserved live behavior: existing planning dry-run, scoped execute snapshot-before-start, and stale planner-thread replacement tests should still pass without changing expectations.
7. Confirm no graph, request, terminal, retry, blocked, PR-review, or issue-implementation observation routing was added in this round.

### Verification
- Add focused assertions with unique names near the existing indexed issue-planning, observed daemon, and automatic planning tests in `test/Main.hs`. The current `watcher-core-test` harness is a single exitcode test executable without a name filter, so validate those focused assertions through:
  `cabal test watcher-core-test`
- Then the required build baseline:
  `cabal build all`
- Re-run the full test baseline after the build:
  `cabal test watcher-core-test`
- Finish with:
  `git diff --check`
- If the implementer stages changes before review, also run:
  `git diff --cached --check`

Reviewer evidence should explicitly cover unchanged event labels and schemas, unchanged dry-run and execute report shape, unchanged action ordering around planner thread start, planner turn start, event append, and compatibility writes, unchanged `planning-state.json` and `issue-snapshot.json` writes, preserved request-id progression, detailed transaction-failure preservation, and unchanged recursive package-boundary assertions.
