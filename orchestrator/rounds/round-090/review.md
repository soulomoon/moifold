### Checks Run
- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass. State JSON is valid and records active `round-090` in `review` for roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, direction `direction-007-runtime-compatibility-fixtures`, extraction `round-090-planner-planning-compatibility-fixtures`.
- Command: `git status --short --untracked-files=all`
  Result: pass. Changed implementation paths are `moifold.cabal`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, and the five expected `golden/runtime-compatibility/issue-planning/...` fixture files. The status also contains controller/round artifacts for active round coordination and this review.
- Command: `rg -n "planner-state\\.json|planning-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|PlanningWaitingForReadyIssues|RecordPlanningGraph|stateFileSpecs|plannerState" golden test moifold.cabal src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/EffectInterpreter.hs src/CodexWatcher/Healthcheck.hs -g '!dist-newstyle/**'`
  Result: pass. The scan shows the new watcher-core module/wiring, the five fixture paths, current compatibility producers, direct `RecordPlanningGraph`, and `Healthcheck.hs` mapping `plannerState` to `planner-state.json`.
- Command: `find golden/runtime-compatibility/issue-planning -type f | sort`
  Result: pass. Exactly the expected selected fixture files are present: ready/active/waiting/complete `planner-state.json` and waiting `planning-state.json`.
- Command: `jq . golden/runtime-compatibility/issue-planning/planner-ready/planner-state.json`
  Result: pass. Fixture is valid JSON and has the expected ready summary/status shape.
- Command: `jq . golden/runtime-compatibility/issue-planning/planner-active/planner-state.json`
  Result: pass. Fixture is valid JSON and has the expected active summary/status shape.
- Command: `jq . golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planner-state.json`
  Result: pass. Fixture is valid JSON and has the expected waiting-ready-issues summary/status shape.
- Command: `jq . golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planning-state.json`
  Result: pass. Fixture is valid JSON and has the expected `PlanningGraph` shape.
- Command: `jq . golden/runtime-compatibility/issue-planning/planner-complete/planner-state.json`
  Result: pass. Fixture is valid JSON and has the expected terminal `{"status":"complete"}` shape.
- Command: `sed -n '56,75p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Current compatibility projection writes `planner-state.json` for ready/active/waiting planner summary states and writes `planning-state.json` only for `PlanningWaitingForReadyIssues`.
- Command: `sed -n '168,178p' src/CodexWatcher/EffectInterpreter.hs`
  Result: pass. Direct `RecordPlanningGraph` still writes only `planning-state.json`.
- Command: `sed -n '246,263p' src/CodexWatcher/Healthcheck.hs`
  Result: pass. Issue planning healthcheck still lists `("plannerState", "planner-state.json")`; `planning-state.json` is not a healthcheck state-file reader.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged diff was present.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite passed, including the new runtime compatibility fixture assertions for JSON decoding, exact planner/planning shapes, non-interchangeability, compatibility projection writes, direct `RecordPlanningGraph`, and the healthcheck reader boundary.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

### Plan Compliance
- Step 1, reconfirm current scope and inputs: met. Reviewed state, selection, plan, project contract, active roadmap verification, round-087 fixture inventory, and round-088 review contract.
- Step 2, reconfirm producer and reader code paths: met. Source inspection confirms current producer names, direct-effect behavior, and healthcheck reader behavior.
- Step 3, add the five fixture files: met. The files are checked in under `golden/runtime-compatibility/issue-planning/...` and no other fixture family was added.
- Step 4, add focused watcher-core test module: met. `test/RuntimeCompatibilityFixtureSpec.hs` exports `runtimeCompatibilityFixtureTests :: IO Bool` and follows the existing `IO Bool` aggregation style.
- Step 5, add fixture parsing and shape assertions: met. The new tests decode every selected fixture, decode `planning-state.json` as `PlanningGraph`, compare exact expected values, and assert planner/planning shapes are not interchangeable.
- Step 6, add compatibility projection assertions: met. The new tests cover `PlanningReady`, `PlanningTurnActive`, `PlanningWaitingForReadyIssues`, and `CompleteState PlanningComplete`, including the no-`planning-state.json` boundary for ready/active/complete.
- Step 7, add direct-effect assertion for `RecordPlanningGraph`: met. The new test verifies direct effect compilation writes exactly `planning-state.json` with the graph fixture shape and does not write `planner-state.json`.
- Step 8, preserve healthcheck reader boundary: met. The fixture test reads `Healthcheck.hs` and asserts issue planning keeps `plannerState` on `planner-state.json` while excluding `planning-state.json`.
- Step 9, wire the new module into `watcher-core-test`: met. `moifold.cabal` lists `RuntimeCompatibilityFixtureSpec`; `test/Main.hs` imports and includes `runtimeCompatibilityFixtureTests` in the final success condition.
- Step 10, inspect final diff and keep scope narrow: met. No production behavior, healthcheck behavior, repair behavior, roadmap, docs/policy, compatibility filename, rename, deletion, migration, deprecation, removal, daemon/block/repair/runtime-owner/live-snapshot fixture, or unrelated runtime-state cleanup change appears in the implementation diff.

### Decision
**APPROVED**

### Evidence
The integrated round turns the reviewed planner/planning contract into checked-in fixture evidence without changing runtime behavior. The new fixtures use the deterministic planner config from the plan (`soulomoon/mlf2`, `maxParallel = 2`, scope issue `#12`) and the new watcher-core assertions compare those files against the current compatibility writers and direct-effect writer.

The tests would fail if `planner-state.json` and `planning-state.json` were collapsed, swapped, renamed, or treated as equivalent: fixture shapes are distinct, ready/active/complete planner states must not emit `planning-state.json`, waiting-ready-issues must emit both distinct files, direct `RecordPlanningGraph` must emit only `planning-state.json`, and healthcheck must continue reading `planner-state.json` as `plannerState`.

The project-contract and roadmap boundaries remain intact. This approval is fixture/test evidence for the selected `planner-state.json` / `planning-state.json` slice only; it does not approve deprecation, migration, rename, deletion, healthcheck reader behavior change, repair behavior change, broader fixture batches, facade removal, Cabal exposure removal, release approval, or terminal roadmap completion.
