# Planning State Fixture Policy Evidence

## Scope And Non-Goals

This round records source-backed evidence for the current
`planning-state.json` compatibility projection. The current classification
remains `defer`.

Non-goals for this round:

- no filename, schema, event `type`, write-timing, healthcheck, repair, or
  compatibility projection behavior change;
- no production source, test, fixture, roadmap, controller-state, migration,
  removal, deprecation, package publication, or release approval change;
- no checked-in fixture creation unless an existing old/current fixture
  contract is proven.

## Producer Readback

`src/CodexWatcher/EffectInterpreter.hs:173-174` compiles
`RecordPlanningGraph graph` to one direct planned JSON write:
`PlannedWriteJson (runtimeStateDirFile ... "planning-state.json") (toJSON graph)`.
The file value is therefore the `PlanningGraph` JSON.

`src/CodexWatcher/Runtime/Compatibility.hs:56-69` emits
`planning-state.json` from `compatibilityStateWrites` only for
`SomeWatcherState (PlanningWaitingForReadyIssues config graph)`. That state
also emits `planner-state.json` and `daemon-state.json`; the
`planning-state.json` value is `toJSON graph`.

`src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs:304` writes compatibility
projection output after appending the blocked ready-issues event, and
`src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs:329` does the same after
appending the ready-issues-fixed event. Both paths call
`compatibilityStateWrites cli.loopCliStateDir projection.issuePlanningIndexedProjectionFinalState`,
so the daemon/fanout compatibility output includes `planning-state.json` only
when the projected final state is `PlanningWaitingForReadyIssues`.

This evidence records the current producers and value shape only. It does not
propose any schema or write-timing change.

## Healthcheck Readback And Non-Healthcheck Policy

`src/CodexWatcher/Healthcheck.hs:252-272` defines healthcheck state-file
readback through `stateFileSpecs` and `sharedStateFiles`.

For `SIssuePlanning`, healthcheck reads:

- `plannerState` from `planner-state.json`;
- shared `daemonState` from `daemon-state.json`;
- shared `blockedState` from `block-state.json`;
- shared `runtimeOwner` from `runtime-owner.json`.

No healthcheck state-file spec reads `planning-state.json`.

Current policy: preserve `planning-state.json` as a write-only compatibility
projection with explicit non-healthcheck status. Any future healthcheck
surfacing, reporting, or readback behavior would be a behavior change and needs
its own selected round with reviewer-approved evidence.

## Existing Fixture And Test Coverage

Required fixture search:

```sh
find . -name 'planning-state.json' -print
```

Result: no output. There is no checked-in `planning-state.json` fixture in this
worktree.

Existing tests still protect the current write behavior:

- `test/Main.hs:2961-2967`
  `prop_effectInterpreterRecordPlanningGraphWritesState` checks direct
  `RecordPlanningGraph` compilation writes `planning-state.json` with
  `toJSON graph`.
- `test/Main.hs:5100-5105` automatic daemon graph-update coverage asserts
  `planning-state.json` is written for a planning graph update.
- `test/Main.hs:5238-5239` canonical planning graph coverage asserts the
  normalized graph is recorded to `planning-state.json`.
- `test/Main.hs:9867-9889` indexed issue-planning projection parity checks the
  graph-update compatibility plan and that compatibility writes contain the
  planning graph.
- `test/Main.hs:10894-10895` defines
  `compatibilityWritesContainPlanningGraph`, which requires
  `CompatibilityWrite "/tmp/state/planning-state.json" (toJSON graph)`.

These tests are behavior coverage, not old/current state-file fixture coverage.

## Blockers Before Later Cleanup

Keep the conservative `defer` classification. The following blockers remain
before any later deprecation, migration, cleanup, timing, schema, healthcheck,
or removal decision:

- no checked-in old/current `planning-state.json` state-file fixture;
- no external operator or downstream direct-reader inventory;
- no reviewed behavior-change selection for healthcheck surfacing;
- no migration or removal approval in the active roadmap milestone;
- no proof that changing producer timing, schema, or compatibility projection
  behavior preserves old logs, daemon recovery, repair behavior, and operator
  expectations.
