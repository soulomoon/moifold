### Changes Made
- `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`: added a moifold-owned indexed projection record and `projectIssuePlanningTurnStartedObservation` for only `PlanningReady -> PlanningTurnActive`, projecting the indexed transition back to existing `PlannedTransition MoifoldSpec` and final-state surfaces.
- `src/CodexWatcher/Daemon.hs`: routed only live `PlanningReady` plus `DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId)` through the indexed issue-planning projection; all other observations continue through the existing compatibility observation path and transaction runners.
- `test/Main.hs`: added focused indexed projection and daemon dry-run/execute/rejection coverage for the issue-planning turn-start route, including labels, event shape, request-id progression, action ordering, compatibility writes, audit/report surfaces, and invalid-observation failure behavior.

### Tests
- `test/Main.hs`: verifies direct indexed turn-start projection emits `IssuePlanningTurnStarted`, reaches `IssuePlanning/PlanMode`, preserves source/target labels, and compiles the expected planner-turn app-server request id.
- `test/Main.hs`: verifies observed daemon dry-run preserves event/report/audit surfaces, compatibility writes, no-mutation behavior, final state, and request-id progression for the indexed turn-start route.
- `test/Main.hs`: verifies observed daemon execute starts the planner turn before appending the event, writes compatibility state after append, preserves committed event labels, and reaches plan mode.
- `test/Main.hs`: verifies invalid `ObservedPlanningTurnStarted` from an already active planning state is rejected as `DaemonObservationRejected` with no runtime calls.
- `cabal test watcher-core-test`: passed before `cabal build all`.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed after `cabal build all`.

### Notes
No graph, issue-request, terminal, retry, blocked, PR-review, or issue-implementation observations were added to the new issue-planning daemon route. Planner thread creation, planner turn prestart, snapshot writes, stale-thread replacement, and lifecycle policy remain owned by the existing issue-planning loop and compatibility transaction machinery.
