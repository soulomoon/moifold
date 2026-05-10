### Goal

Add focused checked-in fixture coverage and watcher-core assertions for the
current repair-failure `block-state.json` compatibility shape.

This round should cover the next `direction-007-runtime-compatibility-fixtures`
blocker from the round-087 inventory: the richer `block-state.json` written by
the automatic loop when event-log replay fails and
`repairFailureBlockStateJson` is used. The implementation must preserve the
current file name, schema, direct `RecordBlocked` producer behavior,
compatibility projection behavior, automatic-loop repair-failure writer,
snapshot reader tolerance, healthcheck reader behavior, successful-repair
stale-block cleanup, and restart cleanup behavior. It must not rename, delete,
migrate, deprecate, or remove `block-state.json`, and it must not expand into
`repair-state.json`, `runtime-owner.json`, checked-in snapshot, live
`issue-snapshot.json`, healthcheck-contract, operator/downstream inventory,
production behavior, docs/policy, roadmap, or controller-state work.

### Approach

Use one serial implementation pass. Worker fan-out is not justified because
the selected fixture file and assertions belong to one small test surface:
`golden/runtime-compatibility/...` plus the already-wired
`test/RuntimeCompatibilityFixtureSpec.hs`.

Extend the existing runtime-compatibility fixture namespace with a repair
failure block-state fixture, keeping it separate from full golden snapshot
directories so it is not mistaken for a `loadNodeSnapshot` input:

- `golden/runtime-compatibility/block-state/repair-failure/block-state.json`

Use a deterministic `ReplayFailure` in the test and fixture. Prefer a simple
issue-implementation event whose current JSON shape is stable, such as:

```haskell
ReplayFailure
  { eventIndex = 3
  , event = IssueImplementationCompletedEvent (PrNumber 42) Nothing
  , reason = "event issue_implementation_completed is invalid in IssueImplement/PlanReady"
  }
```

The fixture should match the current `repairFailureBlockStateJson` output for
that replay failure:

```json
{
  "blocked": true,
  "blockedKind": "invalid_event_log",
  "reason": "event issue_implementation_completed is invalid in IssueImplement/PlanReady",
  "eventIndex": 3,
  "eventType": "issue_implementation_completed",
  "event": {
    "type": "issue_implementation_completed",
    "prNumber": 42
  }
}
```

Add assertions to `test/RuntimeCompatibilityFixtureSpec.hs` rather than
creating a new test module. The module is already listed in `moifold.cabal`
and already called from `test/Main.hs`, so no test-suite wiring should be
needed unless the implementer finds that the current branch diverged from the
observed round-090/round-091 state.

### Steps

1. Reconfirm current scope and inputs before editing:
   - `git status --short --untracked-files=all`
   - `python3 -m json.tool orchestrator/state.json`
   - `sed -n '1,220p' orchestrator/rounds/round-092/selection.md`
   - `sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '1,260p' orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`
   - `sed -n '1,260p' orchestrator/rounds/round-069/block-state-repair-failure-evidence.md`
2. Reconfirm the current block-state producer, reader, repair, and restart
   paths before editing:
   - `rg -n "repairFailureBlockStateJson|recordInvalidReplayBlockState|block-state\\.json|blockedStateJson|RecordBlocked|stateFileSpecs|NodeBlockedState|writeCompatibilityFiles|cleanup_state" src test scripts golden -g '!dist-newstyle/**'`
   - inspect `src/CodexWatcher/EventLogRepair.hs` around
     `repairFailureBlockStateJson`;
   - inspect `src/CodexWatcher/AutomaticLoop/Runner.hs` around
     `recordInvalidReplayBlockState`;
   - inspect `src/CodexWatcher/Runtime/Compatibility.hs` and
     `src/CodexWatcher/EffectInterpreter.hs` for the normal blocked writers;
   - inspect `src/CodexWatcher/Snapshot.hs`,
     `src/CodexWatcher/Healthcheck.hs`,
     `src/CodexWatcher/Cli/Command/Replay.hs`, and
     `scripts/restart-watcher` for the reader and cleanup contracts.
3. Add the repair-failure fixture file listed in the Approach section. Keep
   JSON formatting deterministic and keep the fixture path limited to
   `golden/runtime-compatibility/block-state/repair-failure/block-state.json`.
4. Extend `runtimeCompatibilityFixtureTests` with a block-state
   repair-failure fixture group. Keep the existing planner/planning and
   daemon-state tests intact.
5. In the block-state fixture group, load the new fixture as `Value` with
   `eitherDecodeStrict'` and assert exact equality with
   `repairFailureBlockStateJson fixtureReplayFailure`.
6. Decode the new fixture as `NodeBlockedState` from
   `CodexWatcher.Snapshot` to prove the current snapshot reader still
   tolerates the repair-failure shape:
   - `blocked = True`;
   - `reason` is the replay-failure reason;
   - the test does not require the snapshot reader to consume
     `blockedKind`, `eventIndex`, `eventType`, or `event`, because the
     current reader accepts unknown fields and preserves only `blocked` and
     optional `reason`.
7. Add exact-field assertions for the repair-failure-specific shape:
   - `blockedKind` is `invalid_event_log`;
   - `eventIndex` is the deterministic failure index;
   - `eventType` is `eventName fixtureReplayFailure.event`;
   - the embedded `event` equals `toJSON fixtureReplayFailure.event`;
   - the embedded event retains the current event `type` field.
8. Add non-interchangeability assertions against the normal blocked shape:
   - `blockedStateJson (BlockedReason fixtureReplayFailure.reason)` is not
     equal to the repair-failure fixture;
   - `compatibilityStateWrites` for a representative `BlockedState` writes
     the normal `{"blocked": true, "reason": ...}` shape and does not include
     `blockedKind`, `eventIndex`, `eventType`, or `event`;
   - `compileEffectPlan` for `[SomeEffect (RecordBlocked ...)]` writes the
     normal `block-state.json` shape and does not match the repair-failure
     fixture.
9. Add or extend a focused source-boundary assertion for current
   block-state compatibility interactions:
   - `AutomaticLoop/Runner.hs` still writes
     `repairFailureBlockStateJson replayFailure` to `block-state.json` only
     for `DaemonReplayFailed`;
   - `Healthcheck.hs` still keeps `("blockedState", "block-state.json")` in
     issue-planning, issue-implementation, and PR-review state files;
   - `Snapshot.hs` still reads optional `block-state.json` for PR-review and
     issue-implementation snapshots;
   - `Cli/Command/Replay.hs` still removes stale `block-state.json` after
     successful repair compatibility rewrite;
   - `scripts/restart-watcher` still removes
     `"$state_dir/block-state.json"` during cleanup.
   These are behavior locks only; do not change automatic-loop, healthcheck,
   snapshot, repair, restart, or producer behavior in this round.
10. Inspect the final diff and keep it inside the selected implementation
    surface. Expected implementation paths are the one block-state fixture
    file, `test/RuntimeCompatibilityFixtureSpec.hs`, and the implementer's
    `orchestrator/rounds/round-092/implementation-notes.md`. Do not edit
    `orchestrator/state.json`, roadmap files, production code, docs/policy
    files, healthcheck behavior, repair behavior, restart behavior,
    compatibility file names, Cabal exposure, public facades, or unrelated
    fixtures.

### Verification

Run the focused checks first:

- `find golden/runtime-compatibility/block-state -type f | sort`
- `python3 -m json.tool golden/runtime-compatibility/block-state/repair-failure/block-state.json`
- `rg -n "block-state\\.json|RuntimeCompatibilityFixtureSpec|runtimeCompatibilityFixtureTests|repairFailureBlockStateJson|recordInvalidReplayBlockState|NodeBlockedState|writeCompatibilityFiles|cleanup_state" golden test src scripts -g '!dist-newstyle/**'`
- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

Run the roadmap baseline because tests and fixtures are expected to change:

- `cabal build all`

If staging occurs, also run:

- `git diff --cached --check`

Reviewers should specifically confirm:

- the fixture file is checked in at the expected
  `golden/runtime-compatibility/block-state/repair-failure/block-state.json`
  path;
- fixture tests would fail if the repair-failure shape lost `blockedKind`,
  `eventIndex`, `eventType`, or the embedded event;
- fixture tests would fail if the repair-failure shape were collapsed into the
  normal direct blocked shape;
- normal `RecordBlocked` and `BlockedState` compatibility projection writes
  remain the simple blocked shape and are not changed to the repair-failure
  shape;
- snapshot reader tolerance is tested without changing the reader;
- automatic-loop repair-failure writer, healthcheck reader, successful-repair
  stale-block cleanup, and restart cleanup behavior are preserved by
  assertions or existing reachable tests;
- no `repair-state.json`, `runtime-owner.json`, checked-in snapshot, live
  `issue-snapshot.json`, healthcheck-contract, operator/downstream,
  production behavior, docs/policy, roadmap, controller-state, rename,
  deletion, migration, deprecation, or removal work escaped into this round.

### Worker Fan-Out

No worker fan-out is used. The round is serial and does not write
`worker-plan.json`.
