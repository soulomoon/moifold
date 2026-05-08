### Changes Made
- `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`: added indexed projection helpers for active-turn `ObservedPlanningIssuesRequested` and `ObservedPlanningGraphUpdated`, including the blocked target edge for invalid graph observations that compatibility turns into `WatcherBlocked`.
- `src/CodexWatcher/Daemon.hs`: routed only active-turn issue-request and graph-update issue-planning observations through the indexed adapter before projecting back to the existing daemon transaction surface.
- `test/Main.hs`: added focused direct projection, daemon dry-run, daemon execute, wrong-source rejection, and invalid-graph blocked-route assertions for the selected observations.

### Tests
- `test/Main.hs`: direct projection tests verify event/effect parity, source and target labels, final state shape, request-id stability for issue requests, graph recording effects, and `planning-state.json` compatibility write content.
- `test/Main.hs`: daemon parity tests verify dry-run mutation behavior, execute action ordering, issue creation command plans, graph recording writes, compatibility writes after append, audit labels, and invalid graph `WatcherBlocked` behavior.
- Validation run: `cabal test watcher-core-test` passed before `cabal build all`.
- Validation run: `cabal build all` passed.
- Validation run: `cabal test watcher-core-test` passed again after `cabal build all`.

### Notes
Only `ObservedPlanningIssuesRequested` and normalized `ObservedPlanningGraphUpdated` were added to indexed daemon routing in this round. Retry, blocked, scope-complete, ready-issues-fixed, and completed observations still fall through to the existing compatibility route for item 016. No worker fan-out or `worker-plan.json` was used.
