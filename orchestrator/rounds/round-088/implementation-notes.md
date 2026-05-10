### Changes Made
- `test/Main.hs`: added a focused property that locks `planner-state.json` as the planner summary/status compatibility write and `planning-state.json` as the planning graph write for `PlanningWaitingForReadyIssues`; strengthened the direct `RecordPlanningGraph` effect test so it writes only `planning-state.json`.
- `test/BoundaryPolicySpec.hs`: strengthened the healthcheck source-policy assertion so issue-planning healthcheck state keeps `plannerState` backed by `planner-state.json` and does not read `planning-state.json`.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: added a narrow policy row for `planner-state.json` as a distinct kept compatibility surface, with fixture, downstream, write-timing, and reviewed behavior-change gates before any future migration or removal.

### Tests
- `test/Main.hs`: verifies the current producer split between planner summary/status JSON and planning graph JSON, including that ready/active/complete planner states do not emit `planning-state.json`.
- `test/BoundaryPolicySpec.hs`: verifies the current healthcheck reader boundary by source-policy scan without changing `src/CodexWatcher/Healthcheck.hs`.

### Notes
No production behavior, healthcheck reader behavior, repair behavior, fixture batch, roadmap file, controller state, rename, deletion, migration, deprecation, or removal was introduced. No `worker-plan.json` was created.
