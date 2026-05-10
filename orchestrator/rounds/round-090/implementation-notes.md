### Changes Made
- `golden/runtime-compatibility/issue-planning/planner-ready/planner-state.json`: added the current ready `planner-state.json` summary fixture for `soulomoon/mlf2`, `maxParallel = 2`, and scope issue `#12`.
- `golden/runtime-compatibility/issue-planning/planner-active/planner-state.json`: added the current active `planner-state.json` summary fixture for the same deterministic planner config.
- `golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planner-state.json`: added the current waiting-ready-issues `planner-state.json` summary fixture.
- `golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planning-state.json`: added the current `PlanningGraph` fixture written to `planning-state.json`.
- `golden/runtime-compatibility/issue-planning/planner-complete/planner-state.json`: added the current terminal `planner-state.json` fixture.
- `test/RuntimeCompatibilityFixtureSpec.hs`: added fixture-backed checks for JSON decoding, exact planner/planning shapes, non-interchangeability, compatibility projection writes, direct `RecordPlanningGraph`, and the healthcheck reader boundary.
- `test/Main.hs`: wired `runtimeCompatibilityFixtureTests` into `watcher-core-test` and the final success condition.
- `moifold.cabal`: added `RuntimeCompatibilityFixtureSpec` to the `watcher-core-test` `other-modules` list.

### Tests
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies the selected fixtures decode, match the current `planner-state.json` and `planning-state.json` shapes, and fail if the two surfaces are collapsed or swapped.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies `PlanningReady`, `PlanningTurnActive`, `PlanningWaitingForReadyIssues`, and `PlanningComplete` write the expected selected fixture values and preserve the `planning-state.json` write boundary.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies direct `RecordPlanningGraph` writes only `planning-state.json`.
- `test/RuntimeCompatibilityFixtureSpec.hs`: verifies `Healthcheck.hs` still maps issue planning `plannerState` to `planner-state.json` and does not list `planning-state.json`.

### Notes
- `cabal test watcher-core-test`: pass.
- `cabal build all`: pass.
- `git diff --check`: pass.
- `git status --short --untracked-files=all`: shows the expected implementation files plus pre-existing controller-owned `orchestrator/state.json`, `selection.md`, and `plan.md`; those controller artifacts were not edited by this implementation.
- `git diff --cached --check`: not run because this implementation did not stage files.
- No production code, healthcheck behavior, repair behavior, docs/policy files, roadmap files, compatibility file names, or unrelated fixture surfaces were changed.
