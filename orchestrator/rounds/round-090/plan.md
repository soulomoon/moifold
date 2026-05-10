### Goal

Add focused checked-in fixture coverage and watcher-core tests for the
current `planner-state.json` and `planning-state.json` compatibility shapes.

This round should turn the reviewed round-088 contract into fixture evidence:
`planner-state.json` remains the issue-planning summary/status file for
ready, active, waiting-ready-issues, and complete planner states;
`planning-state.json` remains the planning graph file written by both
compatibility projection for `PlanningWaitingForReadyIssues` and direct
`RecordPlanningGraph`; healthcheck continues to read `planner-state.json` for
issue planning and not `planning-state.json`.

The round must not rename, delete, migrate, deprecate, or remove either file;
must not change healthcheck reader behavior; must not change producer or write
timing behavior; must not edit roadmap or controller state; and must not expand
into daemon, block, repair, runtime-owner, checked-in snapshot, or live
`issue-snapshot.json` fixtures.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because the
fixture files, producer assertions, direct-effect assertion, healthcheck reader
boundary, and watcher-core wiring are one tightly coupled compatibility slice
with overlapping test ownership.

Use the round-088 reviewed contract as the behavioral source of truth and add
only fixture-backed evidence for the selected pair. Put the new fixtures under
a runtime-compatibility fixture namespace rather than the existing full
snapshot directories so they are not mistaken for `loadNodeSnapshot` inputs:

- `golden/runtime-compatibility/issue-planning/planner-ready/planner-state.json`
- `golden/runtime-compatibility/issue-planning/planner-active/planner-state.json`
- `golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planner-state.json`
- `golden/runtime-compatibility/issue-planning/planner-waiting-ready-issues/planning-state.json`
- `golden/runtime-compatibility/issue-planning/planner-complete/planner-state.json`

Use a deterministic fixture config such as `RepoName "soulomoon/mlf2"`,
`maxParallel = 2`, and scope issue `#12`. The ready, active, and
waiting-ready-issues `planner-state.json` fixtures should contain the current
summary/status object shape:

```json
{
  "repoFullName": "soulomoon/mlf2",
  "maxParallel": 2,
  "scopeIssueNumbers": [12],
  "status": "<ready|active|waiting_ready_issues>"
}
```

The complete `planner-state.json` fixture should contain the current terminal
shape:

```json
{
  "status": "complete"
}
```

The `planning-state.json` fixture should contain the current `PlanningGraph`
JSON shape, for example:

```json
{
  "ready_issues": [12],
  "blocked_issues": [
    {
      "issueNumber": 13,
      "blockedBy": [12],
      "reason": "wait for prerequisite"
    }
  ],
  "dependencies": [
    {
      "issueNumber": 13,
      "dependsOn": [12]
    }
  ]
}
```

Add a focused watcher-core test module, preferably
`test/RuntimeCompatibilityFixtureSpec.hs`, and wire it through
`watcher-core-test` with the smallest Cabal/Main changes:

- add `RuntimeCompatibilityFixtureSpec` to the `watcher-core-test`
  `other-modules` list in `moifold.cabal`;
- import `runtimeCompatibilityFixtureTests` in `test/Main.hs`;
- call it from `main` and include its boolean in the final success condition.

Do not add docs or policy text unless review discovers the round-088 policy
row is missing from the current branch. The current selected task is fixture
coverage and tests, not another policy edit.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-090/selection.md`
   - `sed -n '1,180p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
   - `sed -n '1,220p' orchestrator/rounds/round-088/review.md`
2. Reconfirm the current producer and reader code paths before editing:
   - `rg -n "planner-state\\.json|planning-state\\.json|PlanningWaitingForReadyIssues|RecordPlanningGraph|stateFileSpecs|plannerState" src test docs -g '!dist-newstyle/**'`
   - `sed -n '56,75p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '150,175p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '168,178p' src/CodexWatcher/EffectInterpreter.hs`
   - `sed -n '246,263p' src/CodexWatcher/Healthcheck.hs`
3. Add the five fixture files listed in the Approach section. Keep the JSON
   formatted deterministically and limit the new checked-in fixture paths to
   `golden/runtime-compatibility/issue-planning/...`.
4. Add `test/RuntimeCompatibilityFixtureSpec.hs` using the existing
   `IO Bool` test style and helpers from `TestSupport.Workflow` where useful.
   The module should export `runtimeCompatibilityFixtureTests :: IO Bool`.
5. In that test module, add fixture parsing/shape assertions:
   - load every selected fixture as `Value` with `eitherDecodeStrict'`;
   - decode the `planning-state.json` fixture as `PlanningGraph` and compare it
     with the deterministic in-test `PlanningGraph`;
   - assert each `planner-state.json` fixture equals the exact expected
     summary/status object for the deterministic planner config and state;
   - assert the `planner-state.json` fixture values and `planning-state.json`
     fixture value are not interchangeable.
6. Add compatibility projection assertions against
   `compatibilityStateWrites`:
   - `PlanningReady` writes the ready `planner-state.json` fixture and no
     `planning-state.json`;
   - `PlanningTurnActive` writes the active `planner-state.json` fixture and
     no `planning-state.json`;
   - `PlanningWaitingForReadyIssues` writes both the waiting
     `planner-state.json` fixture and the `planning-state.json` graph fixture;
   - `CompleteState PlanningComplete` writes the complete
     `planner-state.json` fixture and no `planning-state.json`.
7. Add the direct-effect assertion for `RecordPlanningGraph`:
   - `compileEffectPlan` for `[SomeEffect (RecordPlanningGraph graph)]` writes
     exactly `planning-state.json` with the graph fixture value;
   - it does not write `planner-state.json`;
   - this assertion should complement, not weaken, the existing
     `prop_effectInterpreterRecordPlanningGraphWritesState`.
8. Preserve the current healthcheck reader boundary with a focused assertion
   in the fixture test module or by strengthening the existing
   `BoundaryPolicySpec` source-policy check:
   - `src/CodexWatcher/Healthcheck.hs` keeps
     `("plannerState", "planner-state.json")` for `SIssuePlanning`;
   - `planning-state.json` is not listed in `stateFileSpecs`;
   - this is a behavior lock only, not a healthcheck behavior change.
9. Wire the new module into `watcher-core-test`:
   - add `RuntimeCompatibilityFixtureSpec` to `moifold.cabal`;
   - import and run `runtimeCompatibilityFixtureTests` in `test/Main.hs`;
   - include its result in the final success condition so fixture failures
     fail the suite.
10. Inspect the final diff and keep it inside the selected implementation
    surface. Expected implementation paths are the five fixture files,
    `test/RuntimeCompatibilityFixtureSpec.hs`, `test/Main.hs`,
    `moifold.cabal`, and the round's implementation notes. Do not edit
    `orchestrator/state.json`, roadmap files, production code,
    docs/policy files, healthcheck behavior, repair behavior, compatibility
    file names, or unrelated fixtures.

### Verification

Run the focused checks first:

- `rg -n "planner-state\\.json|planning-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|PlanningWaitingForReadyIssues|RecordPlanningGraph|stateFileSpecs|plannerState" golden test moifold.cabal src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/EffectInterpreter.hs src/CodexWatcher/Healthcheck.hs -g '!dist-newstyle/**'`
- `find golden/runtime-compatibility/issue-planning -type f | sort`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests, fixtures, and Cabal test wiring are
expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the fixture files are checked in at the expected
  `golden/runtime-compatibility/issue-planning/...` paths;
- fixture tests would fail if `planner-state.json` and `planning-state.json`
  were collapsed, swapped, renamed, or treated as equivalent;
- fixture tests would fail if ready, active, or complete planner states start
  writing `planning-state.json`;
- direct `RecordPlanningGraph` remains a `planning-state.json` writer only;
- healthcheck still reads `planner-state.json` as `plannerState` for issue
  planning and does not read `planning-state.json`;
- no daemon, block, repair, runtime-owner, checked-in snapshot, or live
  `issue-snapshot.json` fixture work escaped into this round;
- no production behavior, healthcheck behavior, repair behavior, roadmap,
  controller state, docs/policy, rename, deletion, migration, deprecation, or
  removal change appears in the diff.

### Worker Fan-Out

No worker fan-out is used. The round is serial and does not write
`worker-plan.json`.
