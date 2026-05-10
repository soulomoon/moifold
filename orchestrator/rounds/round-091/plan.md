### Goal

Add focused checked-in fixture coverage and watcher-core assertions for the
current `daemon-state.json` active and stopped compatibility shapes.

This round should cover the next `direction-007-runtime-compatibility-fixtures`
blocker from the round-087 inventory: current daemon active and stopped JSON
shapes. The implementation must preserve the current file name, schema,
producer behavior, snapshot reader tolerance, healthcheck reader behavior,
repair compatibility rewrite behavior, and restart cleanup behavior. It must
not rename, delete, migrate, deprecate, or remove `daemon-state.json`, and it
must not expand into block, repair, runtime-owner, checked-in snapshot, live
`issue-snapshot.json`, healthcheck-contract, operator/downstream inventory, or
roadmap/controller-state work.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because
the selected fixture files and assertions belong to one small test surface:
`golden/runtime-compatibility/...` plus the already-wired
`test/RuntimeCompatibilityFixtureSpec.hs`.

Extend the existing runtime-compatibility fixture namespace with daemon-state
fixtures, keeping them separate from full golden snapshot directories so they
are not mistaken for `loadNodeSnapshot` inputs:

- `golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json`
- `golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`

Use deterministic fixture values that match the current producers in
`src/CodexWatcher/Runtime/Compatibility.hs`.

The active fixture should represent the current `PlanningTurnActive` daemon
write shape:

```json
{
  "activeTurnId": "daemon-turn",
  "activeTurnPurpose": "plan",
  "activeThreadId": "daemon-thread"
}
```

The stopped fixture should represent the current `StoppedState` daemon write
shape:

```json
{
  "activeTurnId": null,
  "activeTurnPurpose": null,
  "stopReason": "stopped for fixture"
}
```

Add assertions to `test/RuntimeCompatibilityFixtureSpec.hs` rather than
creating a new test module. The module is already listed in `moifold.cabal`
and already called from `test/Main.hs`, so no test-suite wiring should be
needed unless the implementer finds that the current branch diverged from the
observed round-090 state.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-091/selection.md`
   - `sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
2. Reconfirm the current daemon producer and reader paths before editing:
   - `rg -n "daemon-state\\.json|activeDaemonJson|stoppedDaemonJson|StoppedState|PlanningTurnActive|stateFileSpecs|writeCompatibilityFiles|cleanup_state|NodeIssueDaemonState" src test scripts golden -g '!dist-newstyle/**'`
   - `sed -n '56,118p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '150,170p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '252,270p' src/CodexWatcher/Runtime/Compatibility.hs`
   - `sed -n '170,185p' src/CodexWatcher/Snapshot.hs`
   - `sed -n '246,282p' src/CodexWatcher/Healthcheck.hs`
3. Add the two daemon fixture files listed in the Approach section. Keep JSON
   formatting deterministic and keep the fixture paths limited to
   `golden/runtime-compatibility/daemon-state/...`.
4. Extend `runtimeCompatibilityFixtureTests` with a daemon-state fixture group.
   Keep the existing planner/planning tests intact.
5. In the daemon fixture group, load both new fixtures as `Value` with
   `eitherDecodeStrict'` and assert exact equality with the expected current
   JSON objects.
6. Decode both new fixtures as `NodeIssueDaemonState` from
   `CodexWatcher.Snapshot` to prove the current issue-implementation snapshot
   reader still tolerates the focused daemon fixtures:
   - the active fixture decodes with `activeTurnId = Just "daemon-turn"` and
     `activeTurnPurpose = Just "plan"`;
   - the stopped fixture decodes successfully with no active turn id or
     purpose;
   - the test does not require snapshot reader behavior to consume
     `stopReason`, because the current reader ignores unknown daemon-state
     fields.
7. Add `compatibilityStateWrites` assertions for representative producer
   states:
   - `PlanningTurnActive fixturePlannerConfig (ActiveTurn (ThreadId "daemon-thread") (TurnId "daemon-turn"))`
     writes `daemon-state.json` with the active fixture value;
   - `StoppedState (StopReason "stopped for fixture")`, with an explicit
     domain type annotation such as `WatcherState 'IssuePlanning 'Stopped`,
     writes `daemon-state.json` with the stopped fixture value;
   - active and stopped fixture shapes are not interchangeable;
   - no assertion weakens the existing planner/planning fixture checks.
8. Add or extend a focused source-boundary assertion for current
   daemon-state compatibility interactions:
   - `Healthcheck.hs` keeps `("daemonState", "daemon-state.json")` in
     shared state files for issue planning and issue implementation;
   - `Snapshot.hs` still reads optional `daemon-state.json` for
     issue-implementation snapshots;
   - `Cli/Command/Replay.hs` still rewrites compatibility files from repaired
     replay state through `writeCompatibilityFiles`;
   - `scripts/restart-watcher` still removes
     `"$state_dir/daemon-state.json"` during cleanup.
   These are behavior locks only; do not change healthcheck, snapshot, repair,
   restart, or producer behavior in this round.
9. Inspect the final diff and keep it inside the selected implementation
   surface. Expected implementation paths are the two daemon fixture files,
   `test/RuntimeCompatibilityFixtureSpec.hs`, and the implementer's
   `orchestrator/rounds/round-091/implementation-notes.md`. Do not edit
   `orchestrator/state.json`, roadmap files, production code, docs/policy
   files, healthcheck behavior, repair behavior, restart behavior,
   compatibility file names, Cabal exposure, public facades, or unrelated
   fixtures.

### Verification

Run the focused checks first:

- `find golden/runtime-compatibility/daemon-state -type f | sort`
- `python3 -m json.tool golden/runtime-compatibility/daemon-state/planning-active/daemon-state.json`
- `python3 -m json.tool golden/runtime-compatibility/daemon-state/stopped/daemon-state.json`
- `rg -n "daemon-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|activeDaemonJson|stoppedDaemonJson|NodeIssueDaemonState|writeCompatibilityFiles|cleanup_state" golden test src scripts -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests and fixtures are expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the two fixture files are checked in at the expected
  `golden/runtime-compatibility/daemon-state/...` paths;
- fixture tests would fail if active and stopped daemon shapes were collapsed,
  swapped, renamed, or treated as equivalent;
- `compatibilityStateWrites` still emits the active daemon fixture for a
  representative active turn and the stopped daemon fixture for a stopped
  state;
- snapshot reader compatibility is tested without changing the reader;
- healthcheck, repair rewrite, and restart cleanup behavior are preserved by
  assertions or existing reachable tests;
- no block, repair, runtime-owner, checked-in snapshot, live
  `issue-snapshot.json`, healthcheck-contract, operator/downstream,
  production behavior, docs/policy, roadmap, controller-state, rename,
  deletion, migration, deprecation, or removal work escaped into this round.

### Worker Fan-Out

No worker fan-out is used. The round is serial and does not write
`worker-plan.json`.
