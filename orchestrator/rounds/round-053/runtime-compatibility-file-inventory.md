# Runtime Compatibility File Inventory

Round: `round-053`

Scope: evidence-only inventory for `issue-state.json`, `daemon-state.json`,
`planning-state.json`, PR URL/state files, block state, repair state, runtime
owner files, and compatibility snapshots. This round does not rename files,
change fields, migrate schemas, alter compatibility writes, remove snapshots,
or classify any surface as cleanup-ready.

## Scan Evidence

Commands run from the round worktree:

```sh
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\.json|daemon-state\.json|planning-state\.json|pr-url|pr state|PR URL|block state|blocked|repair state|runtime owner|owner file|compatibility snapshot|snapshot" src app test scripts docs examples orchestrator
rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile" src test scripts
```

Representative results:

- Checked-in runtime file fixtures found by `find`: `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`, `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`, `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`, `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`, and `golden/pr-review/mlf2-pr6-blocked/block-state.json`.
- The broad text scan produced 1125 lines. True production hits for selected file names cluster in `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/Cli/Command/Replay.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Snapshot.hs`, `src/CodexWatcher/Runtime/Owner/{Store,Cli}.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`, `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, and `scripts/restart-watcher`.
- The file-IO scan shows JSON writes use `src/CodexWatcher/Runtime/File.hs` `writeJsonValue`, which writes `<path>.tmp` and renames it into place. The selected compatibility writes are not string-appended JSON except event logs; compatibility state files are normal JSON values.
- No filename fixture named `planning-state.json`, `repair-state.json`, `runtime-owner.json`, `*pr-url*`, or `*pr-state*` is checked in. PR URL compatibility is represented as the `pr_url` field in `issue-state.json` and PR review state/config fixtures, not as a separate `pr-url` file.

Focused lookups:

```sh
rg -n "issue-state\.json|daemon-state\.json|planning-state\.json|block-state\.json|repair-state\.json|runtime-owner|issue-snapshot\.json|pr-url" src test scripts docs golden orchestrator/rounds/round-0{1,2,3,4,5}*
rg -n "compatibilityStateWrites|CompatibilityWrite|RecordBlocked|Repair|repair|Healthcheck|healthcheck|runtime-owner|runtimeOwner|RuntimeOwner|issue-snapshot|pr-url|block-state|repair-state" src/CodexWatcher test/Main.hs scripts docs golden
rg -n "old log|old-log|old event|legacy|snapshot fixture|golden" src test docs golden orchestrator/rounds/round-0{1,2,3,4,5}*
```

## Shared Write And Read Mechanics

- Primary compatibility producer: `src/CodexWatcher/Runtime/Compatibility.hs` defines `CompatibilityWrite`, `writeCompatibility`, and `compatibilityStateWrites`. The selected files are derived from `SomeWatcherState`; these writes are compatibility projections from event-log state, not the event-log source of truth.
- Compatibility file write API: `writeCompatibility` delegates to `RuntimeInterpreter.runtimeWriteJsonValue`; the concrete IO helper in `src/CodexWatcher/Runtime/File.hs` writes JSON to `<path>.tmp` then `renameFile`s the final path.
- Daemon/runtime timing: `src/CodexWatcher/Daemon.hs` computes `daemonObservedCompatibilityWrites` from the observed final state. Tests around `test/Main.hs` lines 3904-3941 assert observed dry-run computes compatibility writes and observed execute writes them after the event append.
- Startup and reconciliation timing: `src/CodexWatcher/AutomaticLoop/StartupThreads.hs` appends startup thread refresh events, replays the event log including the new event, then writes compatibility files. `src/CodexWatcher/AutomaticLoop/Runner.hs` renews runtime ownership, repairs the pid file, reconciles compatibility from event-log replay, then runs the loop tick.
- Repair timing: `src/CodexWatcher/Cli/Command/Replay.hs` execute mode archives the old event log, writes repaired `events.jsonl`, writes `repair-state.json`, rewrites compatibility files from repaired replay state, then removes stale `block-state.json`.

## Surface Inventory

### `issue-state.json`

- Current producers: `compatibilityStateWrites` writes this for issue-implementation states: ready-to-plan, planning, plan-ready, implementation-ready, implementing, handoff, waiting for PR merge, post-merge review, waiting for issue close, and issue-complete states. `src/CodexWatcher/Cli/Command/Replay.hs` can rewrite it after repair through `writeCompatibilityFiles`. `src/CodexWatcher/Cli/Command/IssueFanout.hs` writes initial issue implementer compatibility state during launch. `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`, `IssuePlanningFanout.hs`, `StartupThreads.hs`, and `Runner.hs` can rewrite it after event-log transitions or reconciliation.
- Path and fields: path is `<stateDir>/issue-state.json`. Current fields include `repoFullName`, `issueNumber`, `branch`, `issue_status`, `pr_number`, `pr_url`, and `blocked_reason`; complete issue state writes at least `issue_status` and `pr_number`.
- Write timing: launch writes config, appends the initial event, then writes launch compatibility files. Daemon observed execute writes happen after the event append. Automatic-loop reconciliation writes from replay before each loop tick in execute mode.
- Current consumers: healthcheck reads it for issue implementers and exposes `issueStatus`; `src/CodexWatcher/Snapshot.hs` reads it for node snapshots and golden replay bootstrap; tests inspect direct compatibility write values.
- PR URL/state relationship: no separate `pr-url` file was found. The PR URL compatibility surface is the `pr_url` field in `issue-state.json`, produced by `issuePrUrl` from repo and PR number.
- Fixtures and old-state assumptions: checked-in issue fixtures include blocked, plan-ready, and incomplete `issue-state.json`. Golden fixture decode reads optional `pr_url` and `blocked_reason`.
- Protecting tests: `prop_issueImplementationCompatibilityWritesPrUrl` verifies PR number and PR URL fields; golden replay/bootstrap cases load issue snapshots; indexed issue planning and issue implementation parity tests compare `compatibilityStateWrites`; healthcheck source assertions verify read-only surfacing.
- Unknowns: there is no separate local old-log fixture proving every historical `issue-state.json` field combination. External operators may read this file directly, but that dependency is not represented by repo-local tests.

### `daemon-state.json`

- Current producers: `compatibilityStateWrites` writes idle, active, stopped, and issue-planning/issue-implementation daemon summaries. Repair and startup/reconciliation paths can rewrite it through the same compatibility projection.
- Path and fields: path is `<stateDir>/daemon-state.json`. `activeDaemonJson` and `stoppedDaemonJson` are produced in `Runtime.Compatibility`; golden issue fixture `mlf2-issue42-incomplete` contains `lastCompletedTurn` fields that the snapshot reader tolerates.
- Write timing: same compatibility timing as `issue-state.json`; repair writes it only after repaired replay state is known.
- Current consumers: healthcheck reads shared `daemonState`; `src/CodexWatcher/Snapshot.hs` reads it for issue implement snapshots; `scripts/restart-watcher` removes it during restart cleanup.
- Fixtures and old-state assumptions: `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json` proves old snapshot decode still tolerates an older `lastCompletedTurn` shape.
- Protecting tests: golden replay/bootstrap cases; repair CLI source-order assertion; healthcheck source assertion for `("daemonState", "daemon-state.json")`; broad watcher-core indexed parity tests compare daemon compatibility write lists.
- Unknowns: no checked-in fixture was found for active daemon state with current `activeTurnId`/`activeTurnPurpose` fields, and no fixture explicitly covers stopped daemon state.

### `planning-state.json`

- Current producers: `compatibilityStateWrites` writes it when issue planning is waiting for ready issues. `src/CodexWatcher/EffectInterpreter.hs` also compiles `RecordPlanningGraph` to a direct `PlannedWriteJson` at `<stateDir>/planning-state.json`. Fanout and daemon paths write it through compatibility projection.
- Path and fields: path is `<stateDir>/planning-state.json`; value is the `PlanningGraph` JSON.
- Write timing: graph update effect planning writes `planning-state.json` as a planned action, while compatibility projection writes it as part of final-state compatibility. Tests expect graph recording/action ordering and compatibility writes to agree.
- Current consumers: no healthcheck state-file spec reads `planning-state.json`. Tests read/write it through fake action calls and compatibility write comparisons. Docs and prior round evidence identify it as a compatibility file.
- Fixtures and old-state assumptions: no checked-in `planning-state.json` fixture was found by `find`.
- Protecting tests: `prop_effectInterpreterRecordPlanningGraphWritesState` verifies the direct planned write path; indexed issue-planning tests assert compatibility writes contain the normalized graph; fanout tests assert canonical planning graph records normalized state.
- Unknowns: healthcheck has no observed coverage for this file. There is no local snapshot fixture proving old `PlanningGraph` JSON compatibility.

### PR URL/state files

- Current producers: no dedicated `pr-url` or `pr-state` file producer was found. PR URL is produced as the `pr_url` field in `issue-state.json`; PR review compatibility state is written as `watcher-state.json`, `checker-state.json`, and `reviewer-state.json` for PR review states.
- Path and fields: issue PR URL is an `issue-state.json` field. PR review state files use `watcher-state.json`, `checker-state.json`, and `reviewer-state.json`; config fixtures also include `prUrl` and path fields such as `blockedStatePath`.
- Write timing: PR review compatibility files are emitted by `compatibilityStateWrites` for PR review states; reviewer turn inputs point agents at `reviewer-state.json`.
- Current consumers: `src/CodexWatcher/Snapshot.hs` decodes `pr_url` in `NodeIssueState` and reads PR review watcher/checker/agent/reviewer state files. Healthcheck reads PR review `watcherState`, `checkerState`, `agentState`, and `reviewerState`.
- Fixtures and old-state assumptions: PR review golden directories include `watcher-state.json`, `checker-state.json`, `reviewer-state.json`, optional `agent-state.json`, and config `prUrl`. Issue golden fixtures include `pr_url` in `issue-state.json`.
- Protecting tests: `prop_issueImplementationCompatibilityWritesPrUrl`, golden replay/bootstrap cases, reviewer-state classifier tests, and PR-review compatibility write tests.
- Unknowns: the selected roadmap phrase "PR URL/state files" maps to fields and PR review state files in current source, not to a separately named PR URL file. External scripts might still refer to old path names; no repo-local old-log fixture proves otherwise.

### Block state

- Current producers: `compatibilityStateWrites` writes `block-state.json` for `BlockedState`; `src/CodexWatcher/EffectInterpreter.hs` compiles `RecordBlocked` to a direct planned write; `src/CodexWatcher/AutomaticLoop/Runner.hs` writes repair-failure block state when event replay fails; golden fixtures include a PR review blocked state.
- Path and fields: path is `<stateDir>/block-state.json`; current simple blocked shape is `{"blocked": true, "reason": ...}`. Repair failure block state comes from `repairFailureBlockStateJson`.
- Write timing: `RecordBlocked` is a post-commit effect in blocked paths. Automatic-loop invalid replay writes block state before dying. Repair execute removes stale `block-state.json` after successful event-log repair and compatibility rewrite.
- Current consumers: healthcheck reads `blockedState` for issue planning, issue implement, and PR review. `src/CodexWatcher/Snapshot.hs` reads optional `block-state.json` for PR review and issue implement snapshots. `scripts/restart-watcher` may remove it during restart cleanup.
- Fixtures and old-state assumptions: `golden/pr-review/mlf2-pr6-blocked/block-state.json` and issue blocked `issue-state.json` cover blocked snapshot cases; event-log fixtures include blocked events.
- Protecting tests: `prop_effectInterpreterRecordBlockedWritesBlockState`; repair CLI source-order assertion; healthcheck lifecycle source assertion; golden replay/bootstrap cases; mergeability tests assert non-blocking paths do not write block state.
- Unknowns: repair failure block-state JSON has source coverage, but no checked-in fixture for that exact shape was found.

### Repair state

- Current producers: `src/CodexWatcher/Cli/Command/Replay.hs` writes `<stateDir>/repair-state.json` only in `repair-invalid-state --execute` after archiving and rewriting the event log.
- Path and fields: fields include `repaired`, `strategy`, `archivePath`, `failedEventIndex`, `failedEventType`, `failedReason`, `insertedEvents`, `droppedEvents`, `finalDomain`, and `finalPhase`.
- Write timing: write order is archive old event log, write repaired event log, write repair state, rewrite compatibility files, remove block state.
- Current consumers: no production reader or healthcheck reader for `repair-state.json` was found in the selected scans. Tests assert the source-order contract.
- Fixtures and old-state assumptions: no checked-in `repair-state.json` fixture was found.
- Protecting tests: `issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract` verifies dry-run output and execute ordering, including repair-state write before compatibility rewrite and block-state removal.
- Unknowns: healthcheck does not report repair state. The format is locally write-tested by source-order assertion, not by a fixture round trip.

### Runtime owner files

- Current producers: `src/CodexWatcher/Runtime/Owner/Store.hs` writes `<stateDir>/runtime-owner.json` with a top-level `lease` object. `src/CodexWatcher/Runtime/Owner/Cli.hs` writes fresh leases, removes the file when clearable, and clears only the current process lease in execute mode. `src/CodexWatcher/AutomaticLoop/Runner.hs` validates ownership at startup and renews the lease before each loop tick.
- Path and fields: current file is `runtime-owner.json`; current accepted marker contains `lease.runtime`, `lease.pid`, `lease.hostname`, `lease.claimedAt`, `lease.expiresAt`, and `lease.eventLogHeadHash`.
- Write timing: automatic loops validate ownership before starting, renew ownership before each tick, and clear the current process lease on exit. Runtime lease fingerprint uses the current event-log head hash.
- Current consumers: runtime owner CLI validates/clears/renews; healthcheck reads `runtimeOwner` state and also accepts configured `runtimeOwner`; `scripts/restart-watcher` extracts pid with a shell `sed` lookup and removes the file during cleanup.
- Fixtures and old-state assumptions: no checked-in `runtime-owner.json` fixture was found. Tests explicitly reject owner-only JSON and older top-level owner-plus-lease JSON.
- Protecting tests: `prop_runtimeOwnerJsonAndParsing`, `runtimeOwnerLeaseParsingRejectsOwnerOnlyJson`, `runtimeOwnerClearRejectsRunningLease`, and `runtimeOwnerCleanupClearsOnlyCurrentProcessLease`; healthcheck tests assert runtime owner is surfaced read-only.
- Unknowns: healthcheck's `lookupStateText ["runtimeOwner", "owner"]` does not appear to read the current lease runtime field, while runtime owner parsing uses `lease.runtime`. This inventory records the mismatch only; it does not classify cleanup readiness.

### Compatibility snapshots

- Current producers: checked-in fixture directories under `golden/` are compatibility snapshots. Runtime `issue-snapshot.json` is produced by `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` before planner turn start; it is a live issue-planning snapshot, not a checked-in golden fixture.
- Snapshot readers: `src/CodexWatcher/Snapshot.hs` reads PR review `config.json`, `watcher-state.json`, optional `checker-state.json`, `agent-state.json`, `reviewer-state.json`, `block-state.json`; issue implement snapshots read `config.json`, optional `daemon-state.json`, `issue-state.json`, and `block-state.json`.
- Write timing: issue planning snapshot write happens in execute mode before planner turn start. Tests assert snapshot write precedes turn start and closed-scope completion writes the snapshot without starting a planner thread.
- Fixtures and old-state assumptions: golden snapshots cover PR review merged/unresolved/blocked/clean-ready and issue implement plan-ready/incomplete/blocked. Golden event-log fixtures cover PR review, issue implementation, and issue planning replay.
- Protecting tests: `goldenReplayCases`, `goldenBootstrapCases`, `goldenEventLogCases`, `automaticDaemonLoopPlanningExecuteWritesSnapshotBeforeStart`, and `automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn`.
- Unknowns: no checked-in `issue-snapshot.json` fixture exists, and old live snapshots are not represented locally beyond tests that inspect write timing.

## Healthcheck Coverage

`src/CodexWatcher/Healthcheck.hs` is read-only for selected surfaces. It reads:

- issue planning: `daemon-state.json`, `planner-state.json`, `block-state.json`, and `runtime-owner.json`.
- issue implement: `daemon-state.json`, `issue-state.json`, `block-state.json`, and `runtime-owner.json`.
- PR review: `watcher-state.json`, `checker-state.json`, `agent-state.json`, `reviewer-state.json`, `block-state.json`, and `runtime-owner.json`.

No observed healthcheck reader was found for `planning-state.json`,
`repair-state.json`, or live `issue-snapshot.json`.

## Repair Coverage

`repair-invalid-state` reads `events.jsonl`, plans issue-implement event-log
repair, and in execute mode archives the invalid log, writes repaired
`events.jsonl`, writes `repair-state.json`, rewrites compatibility files from
the repaired replay state, and removes stale `block-state.json`. It can
therefore rewrite `issue-state.json`, `daemon-state.json`, and other
compatibility files produced by the repaired final state, but it does not
directly consume old compatibility files as authoritative input.

Runner guard repair launches a repair worker for invalid or blocked runtime
conditions, but the deterministic compatibility-file rewrite path above is the
source-backed repair path found for selected files.

## Cross-Cutting Unknowns

- Runtime compatibility files remain current contract surfaces under
  `orchestrator/project-contract.md`; this inventory does not approve removal.
- Old-log coverage is mostly event-log based. Checked-in JSON snapshots cover
  selected state-file names, but there is no broad archive of old live state
  directories for every selected file.
- Some compatibility behavior is protected by source-order assertions in
  `test/Main.hs`, not by black-box fixture execution.
- `planning-state.json`, `repair-state.json`, and `runtime-owner.json` have
  weaker checked-in fixture coverage than `issue-state.json`,
  `daemon-state.json`, and `block-state.json`.
- No external operator or downstream script inventory was performed beyond
  repo-local source, scripts, docs, tests, golden fixtures, and orchestrator
  evidence.
