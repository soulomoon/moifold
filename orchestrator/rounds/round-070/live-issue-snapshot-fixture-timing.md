# Live Issue Snapshot Fixture Timing Evidence

Round: `round-070`
Direction: `direction-019-live-issue-snapshot-fixture-timing`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-002`

## Scope And Non-Goals

This artifact records current source-backed evidence for the live
`issue-snapshot.json` issue-planning writer path, write timing before planner
turn start, checked-in fixture coverage, prompt contract, and non-use by
healthcheck, repair, restart, and replay surfaces.

This round is evidence-only. It does not approve filename changes, schema
changes, event JSON `type` changes, planner turn behavior changes,
compatibility projection changes, healthcheck changes, repair changes, replay
changes, cleanup, migration, deprecation, removal, publication, upload, or
release.

## Source Readbacks

Commands used for the focused readback:

```sh
sed -n '45,255p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '255,430p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '280,325p' src/CodexWatcher/PromptTemplates.hs
sed -n '320,345p' src/CodexWatcher/TurnOutput.hs
sed -n '4790,4870p' test/Main.hs
sed -n '4930,5005p' test/Main.hs
find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort
rg -n "issue-snapshot\\.json|issueSnapshotPath|ensureIssuePlanningSnapshot|buildIssuePlanningSnapshot|planningSnapshotScopeCompleted|startPlannerTurn|automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart|automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
rg -n "issue-snapshot\\.json|issueSnapshotPath" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs test docs golden
rg -n "snapshot|Snapshot|issue-snapshot\\.json|issueSnapshotPath|repair|Repair|replay|healthcheck|Healthcheck|restart" src/CodexWatcher/Healthcheck.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/EventLogRepair.hs scripts/restart-watcher src/CodexWatcher/Snapshot.hs src/CodexWatcher/GoldenReplay.hs
rg -n 'Live `issue-snapshot\.json`|issue-snapshot\.json|defer|fixture|healthcheck|external operator|downstream|write-timing|removal|migration' docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-070
```

## Live Writer Path

`src/CodexWatcher/Domain/IssuePlanning/Loop.hs` keeps dry-run and execute
behavior distinct in `runPlanningReady`. In dry-run mode it calls
`startPlannerTurn` directly. In execute mode it first calls
`ensureIssuePlanningSnapshot`, then evaluates
`planningSnapshotScopeCompleted`, and only calls `startPlannerTurn` when the
snapshot does not prove the scoped tree is complete.

The execute-mode write path is:

- `runPlanningReady` calls `ensureIssuePlanningSnapshot` before
  `startPlannerTurn`.
- `ensureIssuePlanningSnapshot` calls `buildIssuePlanningSnapshot`.
- `ensureIssuePlanningSnapshot` writes the JSON value only for
  `ExecuteActions`; `DryRunActions` returns without writing.
- `issuePlanningSnapshotPath` resolves
  `runtimeStateDirFile ... "issue-snapshot.json"`.

Current line readback:

- `Loop.hs` lines 58-73: execute mode calls `ensureIssuePlanningSnapshot`, then
  either observes scoped completion or starts the planner turn.
- `Loop.hs` lines 82-95: `startPlannerTurn` ensures the planner thread and
  prestarts/observes `StartPlannerTurnKind`.
- `Loop.hs` lines 228-238: `ensureIssuePlanningSnapshot` builds the value and
  writes it only under `ExecuteActions`.
- `Loop.hs` lines 240-242: `issuePlanningSnapshotPath` points to
  `<stateDir>/issue-snapshot.json`.

## JSON Shape And Completion

`buildIssuePlanningSnapshot` currently emits:

- `repoFullName`
- `scopeIssueNumbers`
- `issues`
- `note`, only for unscoped planning

Unscoped planning returns an empty `issues` list, empty `scopeIssueNumbers`,
and the note `No explicit issue scope was configured; planner may inspect
GitHub open issues if needed.`

Scoped planning fetches each scoped issue with:

```text
gh issue view <number> --repo <repo> --json number,title,state,closed,body,url,labels,assignees,createdAt,updatedAt
```

It fetches sub-issues with:

```text
gh api repos/<repo>/issues/<number>/sub_issues --paginate --jq '[.[] | {number,title,state,closed:(.closed_at != null),body,url:.html_url,parentIssueNumber:<number>}]'
```

The scoped issue value is augmented with `parentIssueNumber: null` and
`subIssues`, with non-array sub-issue output normalized to an empty array.

`planningSnapshotScopeCompleted` returns `False` for unscoped planning. For a
scoped planner it decodes facts from the snapshot and returns `True` only when
the fact list is non-empty and every fact is closed. Because
`runPlanningReady` evaluates this after `ensureIssuePlanningSnapshot`, a closed
scoped tree can emit `IssuePlanningScopeCompleted` after writing the snapshot
and without starting a planner turn.

## Prompt And Turn-Output Contract

The planner prompt surface treats the live snapshot path as an agent contract:

- `src/CodexWatcher/PromptTemplates.hs` lines 303-316 define
  `issuePlanningThreadDeveloperTemplate`.
- Line 309 instructs the planner to read the issue snapshot from
  `{{issueSnapshotPath}}`.
- `src/CodexWatcher/TurnOutput.hs` lines 329-338 render
  `issueSnapshotPath` as `stateDir </> "issue-snapshot.json"`.

This means the current planner-thread developer instructions name the same live
file that the execute-mode writer creates before planner turn start.

## Timing Tests

`test/Main.hs` contains focused executable coverage for the current timing
contract.

`automaticDaemonLoopPlanningExecuteWritesIssueSnapshotBeforeStart`:

- Configures issue planning in `ExecuteActions`.
- Fakes `gh issue view` and `gh api ... /sub_issues`.
- Computes `snapshotPath` from the runtime state dir and
  `"issue-snapshot.json"`.
- Asserts exactly one `FakeWriteJson` to that path.
- Asserts the snapshot write appears before the first `turn/start` app-server
  request.
- Asserts one planner thread start and one planner turn start.
- Asserts `IssuePlanningTurnStarted`.

`automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn`:

- Configures a scoped issue and sub-issue as closed.
- Asserts exactly one `FakeWriteJson` to `issue-snapshot.json`.
- Asserts `IssuePlanningScopeCompleted`.
- Asserts the observed phase is `Complete`.
- Asserts no planner `thread/start` and no planner `turn/start`.

These tests cover timing and closed-scope behavior, not checked-in old/live
fixture decoding.

## Fixture Inventory

Command:

```sh
find golden -name 'issue-snapshot.json' -o -name '*snapshot*' | sort
```

Result: no paths.

The related checked-in snapshot directories are directory-level golden
fixtures for PR review, issue implementation, and event logs, not live
issue-planning `issue-snapshot.json` files:

```text
golden/event-log/issue-implement
golden/event-log/issue-planning
golden/event-log/pr-review
golden/issue-implement
golden/pr-review
```

Focused scans confirm the live `issue-snapshot.json` evidence is represented by
the writer path, prompt path, docs/round evidence, and the two timing tests. No
checked-in live `issue-snapshot.json` fixture exists in `golden`.

## Healthcheck Repair Restart Replay Readback

Focused scans over:

- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/Cli/Command/Replay.hs`
- `src/CodexWatcher/EventLogRepair.hs`
- `scripts/restart-watcher`
- `src/CodexWatcher/Snapshot.hs`
- `src/CodexWatcher/GoldenReplay.hs`
- `test`
- `docs`
- `golden`

showed no live `issue-snapshot.json` reader in healthcheck, repair, restart,
or replay code.

The positive readbacks are:

- `Healthcheck.hs` replays event logs and reports runtime state, but the
  focused `issue-snapshot.json|issueSnapshotPath` scan found no reference.
- `Cli/Command/Replay.hs` replays event logs and repair writes
  `repair-state.json`, compatibility files, and removes stale
  `block-state.json`; it does not read or rewrite live `issue-snapshot.json`.
- `EventLogRepair.hs` builds repair plans from event logs and repair failure
  block-state JSON; it does not inspect live issue snapshots.
- `scripts/restart-watcher` handles runtime-owner cleanup and restart command
  execution; it does not reference live issue snapshots.
- `Snapshot.hs` and `GoldenReplay.hs` load and replay node PR-review and
  issue-implementation snapshot directories; they do not support a live
  `issue-snapshot.json` fixture type.

This absence is non-use evidence only. It is not removal readiness.

## Current Classification

The current conservative classification remains `defer`.

The policy in
`docs/agentic-workflow-framework/compatibility-deprecation-policy.md` records:

- Checked-in compatibility snapshots are `defer`.
- Live `issue-snapshot.json` is `defer`.
- Round 053 records production before planner turn start.
- Round 055 records no checked-in live `issue-snapshot.json` fixture and no
  healthcheck reader.
- Missing gates include old live snapshot fixture coverage, external operator
  or downstream direct-reader inventory, and explicit write-timing migration
  evidence.

Round 057 keeps the same classification: live `issue-snapshot.json` is
`defer` because write timing before planner turn start is tested, but there is
no checked-in live snapshot fixture and no healthcheck reader.

## Conservative Blockers

These blockers remain before any later decision about filename, schema,
event-type, write-timing, planner-turn, compatibility-projection, healthcheck,
repair, replay, cleanup, removal, migration, publication, upload, or release:

- No checked-in old/live `issue-snapshot.json` fixture coverage was found.
- Timing tests cover current writes and closed-scope completion, but not
  fixture decode/readback for old live files.
- No external operator inventory proves nobody reads the live file directly.
- No downstream direct-reader inventory exists for `issue-snapshot.json`.
- No selected round approves filename or schema migration.
- No selected round approves event JSON `type` changes.
- No selected round approves write-timing or planner-turn behavior changes.
- No selected round approves compatibility projection, healthcheck, repair, or
  replay behavior changes for this surface.
- No migration, deprecation, removal, cleanup, publication, upload, or release
  approval exists.

## Conclusion

Current repo truth supports the write-timing contract: in execute mode, live
`issue-snapshot.json` is built and written before planner turn start, and
closed scoped trees can complete after that write without starting a planner
turn. Current repo truth does not provide checked-in live
`issue-snapshot.json` fixture coverage, nor any healthcheck, repair, restart,
or replay reader for the live file. The appropriate classification remains
`defer`.
