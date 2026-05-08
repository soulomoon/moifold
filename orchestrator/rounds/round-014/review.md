### Checks Run
- Command: `cabal test watcher-core-test`
  Result: pass. Ran before the full build as requested by the round plan; the suite reported `Test suite watcher-core-test: PASS` and included the new indexed issue-planning daemon assertions.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. Ran again after the build; the suite reported `Test suite watcher-core-test: PASS`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: not run. `git diff --cached --quiet` showed no staged changes.

### Plan Compliance
- Add moifold-owned indexed issue-planning projection helper: met. `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed` adds `IssuePlanningIndexedProjection` and `projectIssuePlanningTurnStartedObservation`, using `IssuePlanningIndexedState IssuePlanningIndexedInitialized` plus an `ObservedPlanningTurnStarted` observation and converting the indexed transition back through `issuePlanningIndexedTransitionToCompatibility`.
- Export the projection helper from the moifold adapter, without moving policy into core: met. The new exports are in the moifold adapter module. No `agent-workflow-core` source changed; recursive package-boundary assertions remained in `watcher-core-test` and passed.
- Route only `PlanningReady` plus `ObservedPlanningTurnStarted`: met. `prepareDaemonObservation` adds exactly one issue-planning indexed case: `(SomeWatcherState PlanningReady {}, DaemonIssuePlanningObservation (ObservedPlanningTurnStarted threadId turnId))`. The default branch still calls `observeDaemonState`.
- Keep graph/request/terminal/retry/blocked observations out of this round: met. No daemon route was added for `ObservedPlanningIssuesRequested`, `ObservedPlanningGraphUpdated`, `ObservedPlanningReadyIssuesFixed`, `ObservedPlanningScopeCompleted`, `ObservedPlanningTurnRetryRequested`, `ObservedPlanningTurnCompleted`, or `ObservedPlanningBlocked`.
- Preserve prepared daemon transaction shape and existing dry-run/execute runners: met. `PreparedDaemonObservation` is unchanged, and dry-run/execute still run through `runWorkflowPreparedDryRunTransaction` and `runWorkflowPreparedExecuteTransactionDetailed`.
- Preserve planner thread creation, planner turn start, request-id progression, and compatibility writes: met. The diff does not modify `CodexWatcher.Domain.IssuePlanning.Loop`; planner-thread creation, snapshot setup, stale-thread replacement, and prestart still happen before observation classification. New tests cover `StartPlannerTurn`, request ids `920 -> 921`, `930 -> 931`, and `940 -> 941`, plus compatibility writes after event append.
- Preserve daemon result/failure, dry-run/execute reports, audit labels, and action ordering: met. New dry-run and execute tests assert event/report/audit surfaces, no dry-run mutation, planner-turn action before event append, compatibility writes after append, and invalid turn-start rejection as `DaemonObservationRejected` with no runtime calls. Existing detailed transaction-failure tests also passed.
- Preserve `planning-state.json`, `issue-snapshot.json`, event schema labels, and package-boundary assertions: met. The round does not change compatibility write calculation or the issue-planning loop snapshot paths. The new tests preserve the `issue_planning_turn_started` committed event label and the full suite passed golden/event-schema and recursive package-boundary assertions.

### Decision
**APPROVED**

### Evidence
The integrated diff changes only `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, `test/Main.hs`, and controller-owned `orchestrator/state.json`.

The daemon routing evidence is `prepareDaemonObservation`: the new issue-planning indexed route is restricted to `PlanningReady` plus `ObservedPlanningTurnStarted`; every other observation falls through to `observeDaemonState`.

The focused test evidence is the passing assertions named:
- `indexed issue-planning projection starts planner turn with compatibility labels and request id`
- `indexed issue-planning daemon dry-run emits compatibility start event`
- `indexed issue-planning daemon dry-run preserves labels and request id progression`
- `indexed issue-planning daemon dry-run keeps report and audit surfaces stable`
- `indexed issue-planning daemon execute starts planner turn before append`
- `indexed issue-planning daemon execute writes compatibility after event append`
- `indexed issue-planning daemon rejects turn start outside ready state like compatibility`

The baseline evidence is passing `cabal build all`, passing `cabal test watcher-core-test` before and after the build, and clean `git diff --check`.
