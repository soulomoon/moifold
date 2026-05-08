### Goal
Route live active-turn issue-planning daemon observations for `ObservedPlanningIssuesRequested` and normalized `ObservedPlanningGraphUpdated` through the moifold-owned indexed issue-planning adapter, then project the indexed transition back to the existing daemon transaction surface.

This round must preserve issue creation command plans, graph recording, `planning-state.json`, `issue-snapshot.json`, graph validation and normalization behavior, dry-run and execute parity, replay effects, action ordering, request-id progression, compatibility writes, and invalid-observation failures. It must not route retry, blocked, scope-complete, ready-issues-fixed, or completed observations; item 016 owns those. It must not move moifold lifecycle policy into `agent-workflow-core`.

### Approach
Keep the implementation sequential and narrow. Extend `CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed` with projection helpers for the two already-covered indexed policy transitions from `PlanningTurnActive`: issue creation requests and graph updates. Each helper should call the generic indexed API with an `IssuePlanningIndexedState IssuePlanningIndexedActiveTurn`, use the precise typed observation edge, and convert the planned indexed transition back to `PlannedTransition MoifoldSpec` with `issuePlanningIndexedTransitionToCompatibility`.

Update `CodexWatcher.Daemon.prepareDaemonObservation` so only `SomeWatcherState PlanningTurnActive {}` with `DaemonIssuePlanningObservation (ObservedPlanningIssuesRequested requests)` or `DaemonIssuePlanningObservation (ObservedPlanningGraphUpdated graph)` uses the indexed projection. The graph passed into the daemon must remain the already-normalized graph produced by `CodexWatcher.Domain.IssuePlanning.Loop.normalizePlanningObservation`; do not move classifier, canonicalization, closed-dependency filtering, snapshot fetching, compatibility writes, daemon runtime, or filesystem behavior into the indexed adapter.

Keep all transaction execution in the existing moifold daemon path. `runWorkflowPreparedDryRunTransaction`, `runWorkflowPreparedExecuteTransactionDetailed`, `DaemonObservedTickResult`, `DaemonObservedTransactionFailure`, audit construction, event append ordering, compatibility writes, and action report rendering should remain unchanged.

Worker fan-out is not used. The roadmap marks this item as non-parallel-safe, and the source change plus parity tests share one integration boundary.

### Steps
1. Add issue-request and graph-update projection helpers to `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`.
   - For `ObservedPlanningIssuesRequested`, use the active-turn to initialized typed edge and preserve `IssuePlanningIssuesRequested`, ordered `CreateIssue` effects, `SleepUntilNextPoll`, labels, final state, and effect plan projection.
   - For `ObservedPlanningGraphUpdated`, use the active-turn to waiting-ready-issues typed edge and preserve `IssuePlanningGraphUpdated`, graph validation outcomes, `RecordPlanningGraph`, `SleepUntilNextPoll`, labels, final state, and effect plan projection.
2. Export only the new projection helpers needed by `CodexWatcher.Daemon` and tests. Keep `PlannerConfig`, `PlanningGraph`, `IssueCreationRequest`, graph normalization, Aeson codecs, daemon-loop runtime, app-server transport, GitHub reads, and filesystem writes out of indexed core.
3. Update `src/CodexWatcher/Daemon.hs` so `prepareDaemonObservation` routes only the two selected active-turn observations through the new indexed helpers. Leave `ObservedPlanningTurnStarted` on the round-014 indexed route, and leave retry, blocked, scope-complete, ready-issues-fixed, completed, PR-review, and issue-implementation observations on their existing routes.
4. Preserve the existing active-loop ordering in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: read the active turn, clear the marker, classify the turn, normalize graph observations, then call `loopObserveWithExecutor`. No production change should be needed there unless a test exposes a routing regression.
5. Add focused projection tests in `test/Main.hs` near the existing indexed issue-planning tests.
   - Assert direct issue-request projection matches `workflowPlanObservation @MoifoldSpec`, emits `IssuePlanningIssuesRequested`, returns to initialized planning state, preserves source and target labels, preserves `CreateIssue` before `SleepUntilNextPoll`, and keeps request id stable when no app-server action is present.
   - Assert direct graph projection matches `workflowPlanObservation @MoifoldSpec`, emits `IssuePlanningGraphUpdated`, reaches the waiting-ready-issues state shape, preserves `RecordPlanningGraph` before `SleepUntilNextPoll`, and includes the same `planning-state.json` compatibility write value.
6. Add daemon dry-run and execute parity tests for both selected observations, modeled on the round-014 start-route tests.
   - For issue requests, assert the daemon result event, final state, compiled command plan, dry-run report shape, execute command ordering before event append, compatibility writes after append, audit labels, and no dry-run mutation match compatibility.
   - For graph updates, assert the daemon result event, final state, graph recording action, `planning-state.json` write value, dry-run report shape, execute write ordering after event append, compatibility writes, audit labels, and no dry-run mutation match compatibility.
7. Strengthen the existing automatic-loop graph/request tests only where needed to prove the live route still receives classified and normalized observations.
   - Preserve issue creation command plans and the non-fanout boundary for issue requests.
   - Preserve graph recording, wait-for-ready behavior, closed-dependency filtering, canonical open-scope coverage, duplicate ready issue rejection, ready/blocked overlap rejection, dependency-on-ready rejection, out-of-scope blocking, and scoped dependency closure.
   - Preserve `issue-snapshot.json` writes during ready-state snapshot handling and keep graph canonicalization fallback behavior unchanged.
8. Add or update invalid-observation coverage so selected active-turn routing failures stay compatible.
   - Wrong-source issue-request and graph observations should still fail with the same rejection text and commit no event.
   - Invalid graph observations that compatibility turns into `WatcherBlocked` should preserve the same blocked event, blocked state, effect plan, action ordering, and compatibility writes through the indexed route.
   - Retry, blocked, scope-complete, ready-issues-fixed, and completed observations must not gain indexed daemon routing in this round.
9. Record implementation evidence later in `orchestrator/rounds/round-015/implementation-notes.md`: changed files, focused assertions added, validation commands, and an explicit note that no `worker-plan.json` was used.

### Verification
The implementation is correct when the selected active-turn observations are routed through indexed projection while all compatibility surfaces remain unchanged: event labels and schemas, source and target labels, final state labels, pre-commit and post-commit effect plans, replay result and replay effects, effect validation, effect permissions, action ordering, request-id progression, dry-run reports, execute reports, detailed transaction failures, compatibility writes, `planning-state.json`, `issue-snapshot.json`, and invalid-observation behavior.

Required validation:

1. Add focused assertions with unique names near the existing indexed issue-planning and automatic planning tests. The current `watcher-core-test` harness is a single exitcode executable without a reliable name filter, so validate the focused assertions through `cabal test watcher-core-test`.
2. Run `cabal build all`.
3. Re-run `cabal test watcher-core-test` after the build.
4. Run `git diff --check`.
5. If changes are staged before review, run `git diff --cached --check`.

Reviewer evidence should explicitly mention that only `ObservedPlanningIssuesRequested` and normalized `ObservedPlanningGraphUpdated` were added to indexed daemon routing, and that item-016 observations remain unrouted by this round.
