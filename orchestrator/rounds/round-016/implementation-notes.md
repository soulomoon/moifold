### Changes Made
- `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`: added indexed projection helpers for ready-issues-fixed, scope-completed, retry, turn-completed, and blocked observations from initialized, active-turn, and waiting-ready-issues states.
- `src/CodexWatcher/Daemon.hs`: routed the remaining issue-planning terminal, retry, ready-issues-fixed, and blocked daemon observations through the indexed adapter while preserving the existing prepared transaction runner and detailed failure path.
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`: changed fanout-side ready-issues-fixed and blocked writes to derive the event and compatibility final state from indexed projections, preserving dry-run text, execute append/write order, stale marker reload behavior, and moifold-local lifecycle policy.
- `test/Main.hs`: added focused indexed projection, daemon dry-run/execute parity, invalid-observation, and fanout boundary assertions for the routed issue-planning observations.

### Tests
- `test/Main.hs`: verifies source/target labels, planned event/final state labels, effect plans, request-id stability, compatibility writes, replay/effect validation/permission parity, daemon dry-run/execute parity, action ordering, audit labels, invalid-observation no-commit behavior, and fanout use of indexed projection boundaries for ready-issues-fixed and blocked writes.

### Notes
- Graph/request behavior from item 015 is unchanged except for shared helper/test coverage.
- `issuePlanningCompletionEvent` remains unchanged: graph update is still the fanout completion boundary; retry, turn-completed, issue requests, turn start, ready-issues-fixed, scope-completed, and blocked are not treated as fanout completion events.
- Verification run:
  - `cabal test watcher-core-test`
  - `cabal build all`
  - `cabal test watcher-core-test`
  - `git diff --check`
