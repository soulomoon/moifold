# Repair State Fixture And Reader Policy Evidence

## Scope And Non-Goals

This round records current evidence for `repair-state.json` only. It does not
change repair behavior, compatibility rewrite behavior, healthcheck behavior,
event schemas, filenames, fixtures, production source, tests, roadmap files,
controller state, package metadata, cleanup policy classification, migration
approval, or removal approval.

The selected direction remains
`direction-014-repair-state-fixture-reader-policy` from roadmap
`2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`. The active
verification contract requires runtime compatibility evidence to preserve event
JSON `type` fields, schema versions, golden logs, repair behavior, healthcheck
behavior or explicit non-healthcheck policy, write timing, fixture behavior,
and operator recovery unless a selected direction explicitly authorizes a
proven migration. No such migration direction is selected here.

## Repair Writer Readback

`src/CodexWatcher/Cli/Command/Replay.hs` is the only production writer found
for `repair-state.json`. In `repairInvalidState`, a failed replay is planned by
`repairIssueImplementEventLog`. The repair summary is written only inside the
`if options.repairCliExecute` branch, so dry-run reports the plan and does not
write `repair-state.json`.

The execute order in the current source is:

1. `archivePath <- archiveEventLog options.repairCliEventsPath`
2. `writeWatcherEventsFile options.repairCliEventsPath plan.repairRepairedEvents`
3. `writeRepairSummary options.repairCliStateDir archivePath plan`
4. `writeCompatibilityFiles options.repairCliStateDir plan.repairReplayResult.replayState`
5. `removeFileIfExists (options.repairCliStateDir </> "block-state.json")`

This preserves the current ordering: archive invalid event log, write repaired
`events.jsonl`, write `repair-state.json`, rewrite compatibility files from the
repaired replay state, then remove stale `block-state.json`.

## Compatibility Rewrite Ordering

`writeCompatibilityFiles` maps over
`compatibilityStateWrites stateDir plan.repairReplayResult.replayState` after
`writeRepairSummary` has completed. The compatibility files are therefore
derived from the final repaired replay state, not from the invalid pre-repair
state, and the stale `block-state.json` cleanup occurs after compatibility
rewrite.

This round does not authorize any change to that order. In particular, it does
not authorize moving stale `block-state.json` removal before compatibility
rewrite, changing compatibility projection content, or changing the repaired
event-log write timing.

## Repair Summary JSON Fields

`writeRepairSummary` writes `<stateDir>/repair-state.json` with these fields:

- `repaired`: hard-coded `True`.
- `strategy`: `plan.repairStrategy`.
- `archivePath`: the archive path returned by `archiveEventLog`.
- `failedEventIndex`: `plan.repairFailure.eventIndex`.
- `failedEventType`: `eventName plan.repairFailure.event`.
- `failedReason`: `plan.repairFailure.reason`.
- `insertedEvents`: `eventName` for each `plan.repairInsertedEvents`.
- `droppedEvents`: `eventName` for each `plan.repairDroppedEvents`.
- `finalDomain`: `show (someDomain plan.repairReplayResult.replayState)`.
- `finalPhase`: `show (somePhase plan.repairReplayResult.replayState)`.

`src/CodexWatcher/EventLogRepair.hs` feeds those fields through
`EventLogRepairPlan`: `repairFailure`, `repairStrategy`,
`repairOriginalEvents`, `repairRepairedEvents`, `repairInsertedEvents`,
`repairDroppedEvents`, and `repairReplayResult`. The repair rules currently
cover deterministic issue-implementation repairs for stale planning-ready
markers, missing plan events before pull-request events, and completion without
an implementation turn. The failure details include event index, event type,
and reason. Inserted and dropped event names come from the repaired candidate,
and final domain/phase come from the replay result for that candidate.

This artifact records the current summary shape only. It does not approve a
schema change, field rename, event `type` change, or new repair rule.

## Production Reader Inventory

Focused scans across `src`, `app`, `scripts`, `docs`, `test`, `golden`, and
prior round evidence found one production command path that invokes repair:
`app/Main.hs` dispatches `CliRepairInvalidState` to
`CodexWatcher.Cli.Command.Replay.repairInvalidState`. The Haskell production
source hits for `repair-state.json` are in
`src/CodexWatcher/Cli/Command/Replay.hs`, where the file is written.

No production Haskell reader of `repair-state.json` was found. The scan found
operator documentation/runbook mentions of repair commands and compatibility
policy mentions of repair state; those are operator-policy context, not
production readers. Test and prior-round hits are evidence and assertions, not
runtime consumers.

This absence is not removal evidence. External operator, script, runbook, and
downstream direct-reader inventory remains a blocker before any later cleanup,
migration, deprecation, or removal decision.

## Healthcheck Non-Healthcheck Policy

`src/CodexWatcher/Healthcheck.hs` reads state files through
`readStateFiles`, `stateFileSpecs`, and `sharedStateFiles`.

The current healthcheck state-file lists are:

- Issue planning: shared `daemon-state.json`, `block-state.json`,
  `runtime-owner.json`, plus `planner-state.json`.
- Issue implementation: shared `daemon-state.json`, `block-state.json`,
  `runtime-owner.json`, plus `issue-state.json`.
- PR review: `watcher-state.json`, `checker-state.json`, `agent-state.json`,
  `reviewer-state.json`, `block-state.json`, and `runtime-owner.json`.

None of these lists include `repair-state.json`. The current policy evidence
for this round is therefore explicit non-healthcheck status: `repair-state.json`
is a repair summary output written by `repair-invalid-state --execute`, not a
file surfaced by current healthcheck.

This is not approval to remove the file or change healthcheck. A later
healthcheck behavior change would need its own selected direction, behavior
evidence, and review.

## Fixture Evidence

The checked-in fixture search was:

```sh
find . -path './.git' -prune -o -name 'repair-state.json' -print
```

Result: no output. No checked-in file named `repair-state.json` exists in this
worktree.

This is a fixture gap. No fixture was created because the selected scope is
evidence-only and does not authorize adding fixtures, source changes, or tests.

## Existing Test Coverage

`test/Main.hs` contains
`issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract`. The
existing assertions cover source-order behavior:

- dry-run reports strategy, failed index, event counts, and repaired phase
  before mutation;
- execute archives the invalid event log, rewrites `events.jsonl`, writes
  repair state, rewrites compatibility files, then removes stale block state;
- repair rules keep stale-marker and unsafe-completion drops deterministic.

This is not fixture round-trip coverage. It proves the current source-order
contract, including repair-state-before-compatibility and stale-block removal
after compatibility rewrite, but it does not parse a checked-in
`repair-state.json` fixture or prove old/current JSON fixture compatibility.

## Blockers

`repair-state.json` remains `defer`. The current blockers are:

- missing checked-in `repair-state.json` fixture;
- missing fixture round-trip coverage for old and current repair summary JSON
  shapes;
- missing external operator, script, runbook, and downstream direct-reader
  inventory;
- no selected authorization for healthcheck surfacing or healthcheck behavior
  changes;
- no migration, deprecation, cleanup, or removal approval;
- no approval to alter repair write order, compatibility rewrite order, stale
  `block-state.json` cleanup timing, filename, schema, or event `type` fields;
- no production-reader expectation decision beyond the current local
  no-production-reader evidence.

These blockers are conservative. This round closes the local explicit
non-healthcheck-policy evidence gap, but it does not make `repair-state.json`
a removal candidate.
