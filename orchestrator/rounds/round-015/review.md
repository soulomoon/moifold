### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher-core-test suite passed; output included the new indexed issue-planning projection, active-turn dry-run/execute parity, wrong-source rejection, and invalid graph blocked-route assertions.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass. No staged files, so `git diff --cached --check` was not required by the verification contract.

### Plan Compliance
- Add issue-request and graph-update projection helpers: met. `projectIssuePlanningIssuesRequestedObservation` and `projectIssuePlanningGraphUpdatedObservation` use typed active-turn indexed observations and project back through `projectIssuePlanningObservation`.
- Export only daemon/test helpers and keep moifold policy out of indexed core: met. The new exports are the two projection helpers; graph/request domain types remain moifold-owned and no adapter/runtime/filesystem behavior moved into core.
- Route only selected active-turn daemon observations: met. `prepareDaemonObservation` adds only `PlanningTurnActive` plus `ObservedPlanningIssuesRequested` and `ObservedPlanningGraphUpdated`, with existing turn-start and PR-review routes unchanged and all other observations falling through to compatibility.
- Preserve loop normalization ordering: met. `Domain.IssuePlanning.Loop` is unchanged; graph normalization still occurs before `loopObserveWithExecutor` hands the normalized observation to the daemon route.
- Direct projection tests: met. Tests assert event/effect parity, source/target labels, request-id stability, graph compatibility writes, and graph final state shape.
- Daemon dry-run and execute parity tests: met. Tests cover issue creation commands, graph recording, dry-run mutation behavior, execute action ordering, compatibility writes after append, audit labels, and request-id behavior.
- Automatic-loop graph/request behavior: met. Existing watcher-core-test coverage still passes for issue creation, graph recording, closed-dependency filtering, canonical open-scope coverage, and graph validation behavior.
- Invalid-observation behavior and item-016 boundary: met. Wrong-source request/graph observations reject like compatibility and commit no event. Invalid graph observations still produce `WatcherBlocked` with blocked-state effects. Retry, blocked, scope-complete, ready-issues-fixed, and completed observations were not added to daemon indexed routing.
- Implementation evidence: met. `implementation-notes.md` records changed files, validation, and no worker fan-out.

### Decision
**APPROVED**

### Evidence
`src/CodexWatcher/Daemon.hs` routes exactly three issue-planning indexed daemon cases: the prior `PlanningReady` turn-start route plus the new active-turn issue-request and graph-update routes. There are no new daemon cases for retry, blocked, scope-complete, ready-issues-fixed, or completed observations.

The graph-update projection uses typed target `IssuePlanningIndexedWaitingReadyIssues` while preserving the compatibility target label `IssuePlanning/Initialized`. That is coherent with the existing state model because `PlanningWaitingForReadyIssues` is an `IssuePlanning Initialized` constructor. The tests assert both the compatibility label and the concrete final state shape carrying the graph.

The focused tests prove direct projection parity with `workflowPlanObservation`, dry-run/execute parity, compatibility writes including `planning-state.json`, graph record ordering, issue creation command ordering, wrong-source failures, and invalid graph blocking. The full `watcher-core-test` baseline also exercises package-boundary assertions, golden replay behavior, dry-run/execute surfaces, graph normalization, scope validation, fanout boundaries, and compatibility writes including `issue-snapshot.json`.
