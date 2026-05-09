# Repair-Failure Block-State Evidence

Scope: round-local evidence for
`direction-018-block-state-repair-failure-fixture` under roadmap
`2026-05-09-01-compatibility-surface-cleanup` rev-002. This round changes no
production source, tests, fixtures, scripts, docs policy, roadmap files,
`project-contract.md`, or `orchestrator/state.json`.

Non-goals: no filename, schema, event `type`, write-timing, healthcheck,
repair, compatibility projection, stale-block cleanup, migration,
deprecation, removal, publication, upload, or release approval.

## Repair-Failure Runner Write Path

`src/CodexWatcher/AutomaticLoop/Runner.hs` records repair-failure block state
only on invalid replay failure:

- `runLoopIterations` calls `recordInvalidReplayBlockState loopConfig failure`
  in the `Left failure` path, then calls `die` with the formatted failure
  (`Runner.hs:155-157`).
- `recordInvalidReplayBlockState` writes only for
  `DaemonLoopDaemonFailure (DaemonReplayFailed replayFailure)`
  (`Runner.hs:178-180`).
- The writer derives the runtime state dir from
  `loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir`, creates it,
  and writes `<stateDir>/block-state.json` with
  `repairFailureBlockStateJson replayFailure` (`Runner.hs:181-183`).
- All other loop failures are ignored by this writer (`Runner.hs:184`).

This is repair-failure runner behavior, not the normal blocked-state effect
path. The file is written before the automatic loop exits from the replay
failure.

## Repair-Failure JSON Shape

`src/CodexWatcher/EventLogRepair.hs` defines the repair-failure block-state
JSON shape in `repairFailureBlockStateJson` (`EventLogRepair.hs:227-236`):

```json
{
  "blocked": true,
  "blockedKind": "invalid_event_log",
  "reason": "<replay failure reason>",
  "eventIndex": "<failure event index>",
  "eventType": "<eventName failure.event>",
  "event": "<serialized failing event>"
}
```

This shape is intentionally richer than the normal direct blocked shape. It
keeps the failing event embedded and retains the current event serialization;
this round does not authorize changing field names, event serialization, event
`type` fields, or failure classification.

## Normal Direct Blocked Writes

Normal blocked writes use `src/CodexWatcher/Runtime/BlockedState.hs`.
`blockedStateJson` returns exactly:

```json
{
  "blocked": true,
  "reason": "<blocked reason>"
}
```

Source readback:

- `blockedStateJson` builds `blocked = true` and `reason =
  unBlockedReason reason` (`Runtime/BlockedState.hs:10-15`).
- `src/CodexWatcher/EffectInterpreter.hs` compiles `RecordBlocked reason` to
  `PlannedWriteJson <stateDir>/block-state.json (blockedStateJson reason)`
  (`EffectInterpreter.hs:175-176`).
- `test/Main.hs` has
  `prop_effectInterpreterRecordBlockedWritesBlockState`, which asserts the
  direct planned-write path and the simple JSON shape (`Main.hs:2952-2959`).

## Compatibility Projection Writes

`src/CodexWatcher/Runtime/Compatibility.hs` projects terminal
`BlockedState reason` to the same simple blocked shape:

- `compatibilityStateWrites` matches `SomeWatcherState (BlockedState reason)`
  and emits `write "block-state.json" (blockedStateJson reason)`
  (`Runtime/Compatibility.hs:150-151`).
- This projection is distinct from the repair-failure runner path and does not
  include `blockedKind`, `eventIndex`, `eventType`, or embedded `event`.

## Healthcheck Readback And Summary

`src/CodexWatcher/Healthcheck.hs` reads `block-state.json` as the
`blockedState` state file for issue planning, issue implementation, and PR
review:

- `summarizeLoadedItem` calls `readStateFiles`, then surfaces `blocked` from
  `["blockedState", "blocked"]` and `blockedReason` from
  `["blockedState", "reason"]` (`Healthcheck.hs:205-208`).
- The summary defaults `blocked` to `False` when the field is absent and keeps
  `blockedReason` as the optional readback result (`Healthcheck.hs:233-234`).
- Issue planning and issue implementation use `sharedStateFiles`, which
  includes `("blockedState", "block-state.json")`
  (`Healthcheck.hs:252-260`, `271-276`).
- PR review lists `("blockedState", "block-state.json")` directly
  (`Healthcheck.hs:262-268`).
- Raw decoded state files remain available in the `states` field
  (`Healthcheck.hs:241`).

Compatibility consequence: a repair-failure `block-state.json` has
`blocked = true` and `reason`, so current healthcheck summary behavior can
surface the watcher as blocked while retaining repair-failure-specific fields
such as `blockedKind`, `eventIndex`, `eventType`, and `event` in raw
`states.blockedState`.

Existing source assertions include the healthcheck read-only state-file check
in `test/Main.hs`, which looks for `("blockedState", "block-state.json")` and
asserts healthcheck source does not contain `writeJsonValue`
(`Main.hs:7369-7380`).

## Snapshot And Golden Replay Readback

`src/CodexWatcher/Snapshot.hs` decodes optional `block-state.json` for PR
review and issue implementation snapshots:

- `NodeBlockedState` requires `blocked` and accepts optional `reason`
  (`Snapshot.hs:184-194`).
- PR review snapshots decode optional `block-state.json`
  (`Snapshot.hs:221-236`).
- Issue implementation snapshots decode optional `block-state.json`
  (`Snapshot.hs:238-249`).

`src/CodexWatcher/GoldenReplay.hs` treats any decoded `blocked = true` as a
blocked watcher state:

- PR review bootstrap emits `WatcherBlocked` from optional blocked state
  (`GoldenReplay.hs:80-84`), and normalization returns a typed PR-review
  `BlockedState` (`GoldenReplay.hs:203-209`).
- Issue implementation bootstrap emits `WatcherBlocked` from optional blocked
  state (`GoldenReplay.hs:113-117`), and normalization returns a typed issue
  implementation `BlockedState` (`GoldenReplay.hs:234-239`).

Existing golden tests cover blocked snapshot readback for the checked-in
normal fixtures:

- `goldenReplayCases` includes `golden/pr-review/mlf2-pr6-blocked` and
  `golden/issue-implement/mlf2-issue42-blocked` (`Main.hs:3468-3479`).
- `goldenBootstrapCases` includes the same blocked directories
  (`Main.hs:3559-3570`).

This does not prove repair-failure fixture coverage. It proves the optional
snapshot reader accepts a `blocked`/`reason` block-state file and maps
`blocked = true` to blocked replay/bootstrap state.

## Successful Repair Stale-Block Cleanup

`src/CodexWatcher/Cli/Command/Replay.hs` keeps the successful-repair cleanup
order:

1. archive invalid event log;
2. write repaired `events.jsonl`;
3. write `repair-state.json`;
4. rewrite compatibility files from repaired replay state;
5. remove stale `<stateDir>/block-state.json`.

Source readback is `Replay.hs:56-60`. `test/Main.hs` protects this order with
`issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract`
(`Main.hs:1973-1997`). This is successful-repair cleanup evidence only; this
round does not move or change stale-block cleanup.

## Restart Cleanup

`scripts/restart-watcher` removes block state during operator restart cleanup:

- `cleanup_state` removes pid files, `runtime-owner.json`,
  `block-state.json`, `daemon-state.json`, and `stale-active-turn.json`
  (`scripts/restart-watcher:217-224`).

This is operator-script cleanup evidence only. No script change is selected.

## Fixture Inventory

Focused checked-in fixture search:

```sh
find golden -name 'block-state.json' -o -name '*block*' | sort
```

Result:

```text
golden/event-log/issue-implement/mlf2-issue42-implementation-blocked
golden/issue-implement/mlf2-issue42-blocked
golden/pr-review/mlf2-pr6-blocked
golden/pr-review/mlf2-pr6-blocked/block-state.json
```

The checked-in `block-state.json` fixture is the normal PR-review blocked
shape:

```json
{
  "blocked": true,
  "reason": "workdir is not fast-forwardable to origin/codex/fix-remaining-mlfp-vs-emlf-gap"
}
```

The event-log blocked fixture directory includes a terminal
`issue_implementation_blocked` event. The issue-implementation blocked
snapshot records blocked status through `issue-state.json`.

No checked-in repair-failure `block-state.json` fixture was found by this
search. That is the selected fixture gap for this direction. This evidence-only
round does not add fixtures or tests.

## Existing Tests And Assertions

Current coverage is useful but not a runner repair-failure fixture:

- Direct normal blocked write shape:
  `prop_effectInterpreterRecordBlockedWritesBlockState` asserts
  `RecordBlocked` writes `<stateDir>/block-state.json` with
  `{"blocked": true, "reason": ...}` (`Main.hs:2952-2959`).
- Successful repair stale-block cleanup order:
  `issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract` asserts
  archive, repaired events write, repair summary write, compatibility rewrite,
  and stale `block-state.json` removal in order (`Main.hs:1973-1997`).
- Healthcheck state-file list/source behavior:
  the healthcheck read-only source assertion checks `blockedState` maps to
  `block-state.json` and that healthcheck does not write JSON
  (`Main.hs:7369-7380`).
- Golden replay/bootstrap blocked readback:
  `goldenReplayCases` and `goldenBootstrapCases` include the checked-in
  PR-review and issue-implementation blocked snapshots
  (`Main.hs:3468-3479`, `3559-3570`).
- Blocked transition behavior:
  source scans found many workflow/indexed tests asserting blocked
  observations/events lead to `RecordBlocked` and terminal blocked states.

No test found in the focused scans validates
`repairFailureBlockStateJson` through the automatic-loop replay-failure writer
against a checked-in `block-state.json` fixture.

## Current Classification

Current policy classifies `block-state.json` as `keep`
(`docs/agentic-workflow-framework/compatibility-deprecation-policy.md:127`).
The basis is current source and prior evidence: direct `RecordBlocked`
writes, compatibility projection writes, runner repair-failure writes,
healthcheck reads across all watcher domains, successful-repair stale cleanup,
the normal golden PR-review blocked fixture, and blocked event-log fixtures.

Prior round evidence is consistent:

- Round 053 records current producers, consumers, write timing, fixtures,
  protecting tests, and the missing repair-failure fixture
  (`orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md:87-95`).
- Round 055 records that the missing runner repair-failure JSON fixture blocks
  a stronger classification while `block-state.json` remains a current
  operator contract
  (`orchestrator/rounds/round-055/runtime-file-behavior-gates.md:147-161`).

## Conservative Blockers

Keep these blockers before any later cleanup, migration, schema, timing,
healthcheck, repair, projection, stale-cleanup, removal, publication, upload,
or release decision:

- missing checked-in repair-failure `block-state.json` fixture or equivalent
  automatic-loop runner round-trip coverage for `recordInvalidReplayBlockState`
  and `repairFailureBlockStateJson`;
- missing external operator, runbook, script, and downstream direct-reader
  inventory for `block-state.json`, especially readers that may consume only
  the simple blocked shape or may depend on repair-failure fields;
- no selected approval for changing the filename, JSON fields, event
  serialization, event `type` values, write timing, healthcheck summary/raw
  state behavior, repair behavior, compatibility projection behavior, restart
  cleanup behavior, or stale-block cleanup ordering;
- no migration, deprecation, removal, package publication, upload, or release
  approval in the active roadmap selection.
