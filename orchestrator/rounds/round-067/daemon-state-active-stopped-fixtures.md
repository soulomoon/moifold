# `daemon-state.json` Active/Stopped Fixture Evidence

Round: `round-067`
Direction: `direction-016-daemon-state-active-stopped-fixtures`

## Scope And Non-Goals

This is source-backed evidence for the current `daemon-state.json`
compatibility surface. It records projection producers, checked-in fixture
coverage, snapshot/golden replay readback, healthcheck readback, repair
readback, restart cleanup readback, existing assertion coverage, and blockers
before any later cleanup decision.

This round does not change filenames, schemas, event JSON `type` fields,
daemon summary compatibility, compatibility projection behavior, healthcheck
behavior, repair behavior, restart cleanup behavior, production source, tests,
fixtures, scripts, docs, roadmap files, `orchestrator/state.json`, migration
status, deprecation status, removal approval, publication, upload, or release
approval.

The project contract keeps compatibility files such as `daemon-state.json`
available with current names and field meanings unless explicitly migrated.
The active verification contract requires runtime compatibility cleanup to
preserve event schemas, golden logs, repair behavior, healthcheck behavior or
explicit policy, write timing, fixture behavior, and operator recovery.

## Compatibility Projection Readback

Current producers are in
`src/CodexWatcher/Runtime/Compatibility.hs` through
`compatibilityStateWrites stateDir state`.

The issue-planning and issue-implementation states that currently write
`daemon-state.json` are:

- `PlanningReady`: idle daemon JSON.
- `PlanningTurnActive`: active daemon JSON with purpose `plan`.
- `PlanningWaitingForReadyIssues`: idle daemon JSON.
- `IssueReadyToPlan`: idle daemon JSON.
- `IssueInPlanMode`: active daemon JSON with purpose `plan`.
- `IssuePlanReady`: idle daemon JSON.
- `IssueImplementationReady`: idle daemon JSON.
- `IssueImplementing`: active daemon JSON with purpose `implement`.
- `IssueHandoffReady`: idle daemon JSON.
- `IssueHandoffInitialized`: idle daemon JSON.
- `IssueWaitingForPrMerge`: idle daemon JSON.
- `IssuePostMergeReviewPendingReviewer`: idle daemon JSON.
- `IssuePostMergeReviewReady`: idle daemon JSON.
- `IssuePostMergeReviewing`: active daemon JSON with purpose
  `post-merge-review`.
- `IssueWaitingForIssueClose`: idle daemon JSON.
- `StoppedState`: stopped daemon JSON.

PR-review states do not write `daemon-state.json` through this projection.
Blocked states write `block-state.json`, and complete states write their
domain-specific compatibility summaries.

## Active Daemon Evidence

`activeDaemonJson` currently emits exactly these fields:

```json
{
  "activeTurnId": "<turn id>",
  "activeTurnPurpose": "<purpose>",
  "activeThreadId": "<thread id>"
}
```

The source-derived active purposes are:

- `plan` for `PlanningTurnActive`.
- `plan` for `IssueInPlanMode`.
- `implement` for `IssueImplementing`.
- `post-merge-review` for `IssuePostMergeReviewing`.

The checked-in fixture search found no current-shape active
`daemon-state.json` fixture. Active evidence is therefore source-derived and
test/parity-backed only; it is not checked-in active fixture coverage.

## Stopped Daemon Evidence

`stoppedDaemonJson` currently emits exactly these fields:

```json
{
  "activeTurnId": null,
  "activeTurnPurpose": null,
  "stopReason": "<stop reason>"
}
```

`compatibilityStateWrites` writes this shape only for `StoppedState reason`.
The checked-in fixture search found no stopped `daemon-state.json` fixture.
Stopped evidence is therefore source-derived only; it is not checked-in
stopped fixture coverage.

## Idle Daemon Evidence

`idleDaemonJson` currently emits exactly these null fields:

```json
{
  "activeTurnId": null,
  "activeTurnPurpose": null,
  "activeTurnCollaborationMode": null
}
```

Idle daemon JSON is emitted for planning ready, planning waiting-ready-issues,
issue ready-to-plan, issue plan-ready, issue implementation-ready, issue
handoff, issue waiting/post-merge/waiting-close states listed above. The
current snapshot decoder also has an optional `activeTurnCollaborationMode`
field, so this idle null field is part of the current supported readback.

## Checked-In Fixture Search

Command run:

```sh
find . -path './.git' -prune -o -name 'daemon-state.json' -print
```

Result:

```text
./golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json
```

The only checked-in `daemon-state.json` fixture currently contains the older
tolerated shape:

```json
{
  "lastCompletedTurn": {
    "id": "turn-previous",
    "purpose": "implement",
    "status": "completed"
  }
}
```

This is old-shape fixture evidence. It is not evidence for current active,
current stopped, or current idle projection fixtures.

## Snapshot And Golden Replay Readback

`src/CodexWatcher/Snapshot.hs` reads issue-implementation snapshots with:

- required `config.json`;
- optional `daemon-state.json`;
- optional `issue-state.json`;
- optional `block-state.json`.

The current `NodeIssueDaemonState` parser reads optional `activeTurnId`,
optional `activeTurnPurpose`, and optional `activeTurnCollaborationMode`.
Because those fields are optional and unknown fields are ignored by the
object parser, the checked-in older `lastCompletedTurn` fixture is tolerated
as a snapshot/golden compatibility input.

`src/CodexWatcher/GoldenReplay.hs` uses `activeIssueTurn` by reading
`daemon.activeTurnId` and `daemon.activeTurnPurpose`; when both are present,
it bootstraps active issue turn events with the snapshot `threadId`. This
means old-shape tolerance is represented as snapshot/golden replay
compatibility, not as a typed current daemon summary parser and not as
approval to remove or narrow `daemon-state.json`.

## Healthcheck Readback

`src/CodexWatcher/Healthcheck.hs` builds `states` by calling
`readStateFiles kind stateDir'`, which reads each configured state file as an
optional JSON value and returns `Null` for missing files.

Current `stateFileSpecs` behavior:

- `SIssuePlanning` uses `sharedStateFiles` plus `planner-state.json`.
- `SIssueImplement` uses `sharedStateFiles` plus `issue-state.json`.
- `sharedStateFiles` includes `("daemonState", "daemon-state.json")`,
  `("blockedState", "block-state.json")`, and
  `("runtimeOwner", "runtime-owner.json")`.
- `SPrReview` reads `watcher-state.json`, `checker-state.json`,
  `agent-state.json`, `reviewer-state.json`, `block-state.json`, and
  `runtime-owner.json`; it does not use the shared issue/planning state-file
  list and therefore does not read `daemonState`.

This is read-only healthcheck surfacing for issue planning and issue
implementation. It is not approval to change healthcheck behavior.

## Repair Readback

`src/CodexWatcher/Cli/Command/Replay.hs` handles
`repair-invalid-state --execute` in this order:

1. Archive the invalid event log.
2. Write the repaired `events.jsonl`.
3. Write `repair-state.json`.
4. Call `writeCompatibilityFiles options.repairCliStateDir
   plan.repairReplayResult.replayState`.
5. Remove stale `block-state.json`.

`writeCompatibilityFiles` writes exactly the list from
`compatibilityStateWrites stateDir state`. Therefore repair writes
`daemon-state.json` only when the repaired final replay state produces a
daemon-state compatibility write. This round records that ordering; it does
not change repair behavior or compatibility rewrite ordering.

## Restart Cleanup Readback

`scripts/restart-watcher` calls `stop_pid` for the configured pid file,
default pid file, and runtime-owner pid; then calls
`drop_blocked_tail_if_requested`; then calls `cleanup_state`; then either
exits for `--no-start` or starts the watcher.

`cleanup_state` removes:

- `$pid_file`;
- `$default_pid_file`;
- `$state_dir/runtime-owner.json`;
- `$state_dir/block-state.json`;
- `$state_dir/daemon-state.json`;
- `$state_dir/stale-active-turn.json`.

This is operator-script evidence only. It is not approval to change restart
cleanup behavior.

## Focused Scan Results

The focused source/test/docs/operator scans separated current production
readers/writers from tests, docs, scripts, policy evidence, and prior-round
artifacts.

Current production write/projection sites:

- `src/CodexWatcher/Runtime/Compatibility.hs` defines
  `compatibilityStateWrites`, `idleDaemonJson`, `activeDaemonJson`, and
  `stoppedDaemonJson`.
- `src/CodexWatcher/Daemon.hs`,
  `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`,
  `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`,
  `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`, and
  `src/CodexWatcher/AutomaticLoop/Runner.hs` call
  `compatibilityStateWrites` and write compatibility projections from replay,
  fanout, handoff, reconciliation, or daemon execution paths.
- `src/CodexWatcher/Cli/Command/Replay.hs` rewrites compatibility files after
  repair through `writeCompatibilityFiles`.

Current production read/surfacing sites:

- `src/CodexWatcher/Snapshot.hs` reads optional issue-implementation
  `daemon-state.json` snapshots.
- `src/CodexWatcher/GoldenReplay.hs` uses snapshot daemon active fields when
  bootstrapping active issue turns.
- `src/CodexWatcher/Healthcheck.hs` surfaces issue planning and issue
  implementation `daemonState` from `daemon-state.json`.
- `scripts/restart-watcher` removes the file during restart cleanup.

Documentation and policy evidence:

- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  currently classifies `daemon-state.json` as `keep`.
- The same policy records active and stopped daemon fixtures plus external
  operator/downstream direct-reader inventory as missing gates.
- The policy explicitly says compatibility-file cleanup readiness does not
  approve migration, removal, filename changes, schema changes, write-timing
  changes, event JSON `type` changes, repair redesign, healthcheck redesign,
  runtime behavior changes, or removal approval.

Prior-round evidence refreshed:

- Rounds 053, 055, and 057 recorded the old incomplete fixture,
  active/stopped fixture gaps, healthcheck readback, repair ordering, and
  `keep` classification.
- Round 058 selected active/stopped `daemon-state.json` fixture evidence as a
  follow-up gap.
- Round 064 confirmed issue-planning healthcheck reads shared
  `daemon-state.json`.
- Round 065 confirmed repair ordering and non-healthcheck policy for
  `repair-state.json` while preserving compatibility rewrite evidence.
- Round 066 confirmed restart cleanup removes `daemon-state.json` together
  with runtime-owner and blocked/stale state files.

Only claims still supported by current source scans are carried forward here.

## Existing Test And Source Assertion Coverage

Existing coverage is source/parity coverage, not checked-in active/stopped
fixture coverage.

- `test/Main.hs` has a repair source-order assertion requiring execute mode
  to archive, rewrite events, write repair state, rewrite compatibility files,
  then remove `block-state.json`.
- `test/Main.hs` has a healthcheck source assertion requiring issue implement
  lifecycle healthcheck surfacing to include `("daemonState",
  "daemon-state.json")` and no `writeJsonValue` mutation in the healthcheck
  source.
- Golden replay/bootstrap cases load issue-implementation snapshots through
  `Snapshot`/`GoldenReplay`, preserving tolerance for the checked-in old-shape
  fixture.
- Indexed workflow parity tests compare compatibility writes from projected
  final states to `compatibilityStateWrites` across issue-planning,
  issue-implementation, and PR-review transitions.
- Launch and daemon execution tests assert compatibility write counts and
  event-before-compatibility write ordering in selected paths.

No existing test or fixture found by the focused scans proves checked-in
current active `daemon-state.json` fixture coverage or checked-in current
stopped `daemon-state.json` fixture coverage.

## Current Classification

Current classification remains `keep`.

Reasons:

- `daemon-state.json` is still a current compatibility projection for issue
  planning, issue implementation, and stopped daemon state.
- Healthcheck still reads it as `daemonState` for issue planning and issue
  implementation.
- Snapshot/golden replay still tolerate the old checked-in fixture shape.
- Repair can rewrite it from the repaired final replay state.
- Restart cleanup treats it as live watcher state.
- The active policy classifies it as `keep` and records missing gates before
  later deprecation, migration, or removal.

## Conservative Blockers

Before any cleanup, migration, schema, timing, healthcheck, repair,
projection, restart, removal, deprecation, or publication decision, these
blockers remain:

- Missing checked-in current active `daemon-state.json` fixture.
- Missing checked-in current stopped `daemon-state.json` fixture.
- Missing old/current active/stopped round-trip fixture coverage.
- Missing exhaustive fixture coverage for every current and supported old
  daemon summary shape.
- Missing external operator/downstream direct-reader inventory beyond
  repo-local source, tests, docs, scripts, and prior round artifacts.
- No selected approval for filename changes, schema changes, event JSON
  `type` changes, daemon summary compatibility changes, projection behavior
  changes, healthcheck behavior changes, repair behavior changes, restart
  cleanup behavior changes, migration, deprecation, removal, package
  publication, upload, or release approval.
