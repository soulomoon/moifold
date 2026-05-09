# Runtime File Behavior Gates

Round: `round-055`

Scope: evidence-only behavior-gate readiness for runtime compatibility files
selected by `direction-004-runtime-file-behavior-gates`. This round does not
rename files, change schemas, alter write timing, change event JSON `type`
fields, redesign healthcheck or repair, change daemon ownership, change
app-server policy, change cleanup policy, or approve removal.

Readiness notes here are conservative evidence labels only:

- `keep`: current runtime/operator contract; no plausible removal path from
  current evidence.
- `defer`: replacement or weaker usage may exist, but required old-log,
  healthcheck, repair, write-timing, fixture, or external-operator evidence is
  missing.
- `remove-later`: all gates named here are protected by current tests or
  fixtures. No selected surface reached this status in this round.

## Refreshed Scan Evidence

Commands run from the round worktree
`orchestrator/worktrees/round-055`:

```sh
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|pr_url|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|runtime owner|compatibility snapshot|issue-snapshot\\.json|snapshot" src app test scripts docs examples golden orchestrator
rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\\.json|Healthcheck|healthcheck|runtime-owner\\.json|RuntimeOwner|issue-snapshot\\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile|removeFile" src test scripts
```

Representative results:

- `find` found only checked-in selected state-file fixtures for
  `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`,
  `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`, and
  `golden/pr-review/mlf2-pr6-blocked/block-state.json`.
- The filename/text scan returned 647 lines. True current source/test hits for
  selected surfaces remain concentrated in
  `src/CodexWatcher/Runtime/Compatibility.hs`,
  `src/CodexWatcher/EffectInterpreter.hs`,
  `src/CodexWatcher/Cli/Command/Replay.hs`,
  `src/CodexWatcher/Healthcheck.hs`,
  `src/CodexWatcher/Snapshot.hs`,
  `src/CodexWatcher/Runtime/Owner/{Store,Cli}.hs`,
  `src/CodexWatcher/AutomaticLoop/{Runner,StartupThreads,IssuePlanningFanout,PrReviewHandoff}.hs`,
  `src/CodexWatcher/Cli/Command/IssueFanout.hs`,
  `test/Main.hs`, and `scripts/restart-watcher`.
- The focused runtime/healthcheck/repair/golden scan returned 427 lines.
- The file-IO scan returned 156 lines. JSON compatibility writes still route
  through `Runtime.File.writeJsonValue`, which writes `<path>.tmp` and
  `renameFile`s into place. Event logs remain line-appended JSON; selected
  compatibility state files are whole JSON values.
- No checked-in file named `planning-state.json`, `repair-state.json`,
  `runtime-owner.json`, `*pr-url*`, `*pr-state*`, or live
  `issue-snapshot.json` was found. PR URL compatibility is currently the
  `pr_url` field in `issue-state.json` plus PR review config `prUrl`, not a
  dedicated PR URL file.

## Summary Table

| Surface | Golden replay | Repair | Healthcheck | Write timing | Old snapshot/file evidence | Protecting tests | Missing evidence | Readiness |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `issue-state.json` | Issue implement golden bootstrap/replay fixtures include blocked, plan-ready, and incomplete issue snapshots. | `repair-invalid-state --execute` rewrites compatibility files from repaired replay state. | `Healthcheck.stateFileSpecs` reads `issueState` for issue implement. | Compatibility projection from `compatibilityStateWrites`; observed daemon execute appends event before writing compatibility state; launch/fanout writes after initial event/config setup. | Checked-in issue fixtures cover selected states; `Snapshot` decodes optional `pr_url` and blocked fields. | `prop_issueImplementationCompatibilityWritesPrUrl`, golden replay/bootstrap cases, observed daemon write-order tests, healthcheck source assertion. | No exhaustive old live state-directory matrix; external operator readers are not represented locally. | `keep` |
| `daemon-state.json` | Issue implement incomplete golden fixture includes `daemon-state.json`; golden snapshot replay tolerates it. | Rewritten through repaired replay compatibility writes when final state produces daemon state. | `Healthcheck.sharedStateFiles` reads `daemonState` for issue planning and issue implement. | Same compatibility projection timing as `issue-state.json`; startup/reconciliation writes from replay before loop tick. | Old incomplete fixture includes older `lastCompletedTurn` shape. | Golden replay/bootstrap cases, observed daemon write-order tests, repair source-order assertion, healthcheck source assertion. | No checked-in active daemon fixture with current active fields; no stopped daemon fixture. | `keep` |
| `planning-state.json` | No checked-in state-file fixture. Issue-planning event-log golden fixtures replay planning behavior. | Repair can rewrite it only when repaired final state is issue-planning waiting-ready-issues. | No current healthcheck reader. | Direct `RecordPlanningGraph` planned write and compatibility projection write from `PlanningWaitingForReadyIssues`; daemon execute writes compatibility after append. | No checked-in old `planning-state.json` fixture. | `prop_effectInterpreterRecordPlanningGraphWritesState`, indexed issue-planning compatibility parity tests, canonical planning graph tests. | Missing healthcheck coverage by design; no old snapshot fixture. | `defer` |
| PR review state files and PR URL state fields | PR review golden snapshots include `watcher-state.json`, `checker-state.json`, `reviewer-state.json`, optional `agent-state.json`, and config `prUrl`; issue golden snapshots include `pr_url`. | PR review state files are compatibility projections when repaired final state is a PR-review state; no dedicated PR URL file repair path exists. | Healthcheck reads PR review `watcherState`, `checkerState`, `agentState`, `reviewerState`, `blockedState`, and `runtimeOwner`. | `compatibilityStateWrites` emits PR review state files from PR review states; reviewer turn inputs point at `reviewer-state.json`. | Checked-in PR review golden directories cover merged, unresolved, blocked, and clean-ready shapes. | `prop_prReviewCompatibilityClearsCheckerState`, reviewer-state classifier tests, golden replay/bootstrap cases, PR URL compatibility test. | No separate PR URL file exists; no external script inventory proving no one expects one. | `keep` for PR review state files, `defer` for the absent dedicated PR URL file wording |
| `block-state.json` | PR review blocked golden fixture includes `block-state.json`; issue blocked snapshots cover blocked state through issue state and event logs. | Successful repair removes stale `block-state.json`; runner writes repair-failure `block-state.json` when replay fails. | Healthcheck reads `blockedState` for issue planning, issue implement, and PR review. | Direct `RecordBlocked` planned write; compatibility projection writes `BlockedState`; repair-failure write happens before runner exits. | Checked-in PR-review blocked fixture and blocked event-log fixtures exist. | `prop_effectInterpreterRecordBlockedWritesBlockState`, repair CLI source-order assertion, healthcheck source assertion, golden replay/bootstrap cases. | No checked-in fixture for the runner repair-failure JSON shape. | `keep` |
| `repair-state.json` | No golden replay fixture; this is a repair summary output, not replay input. | `repair-invalid-state --execute` archives old log, writes repaired `events.jsonl`, writes `repair-state.json`, rewrites compatibility files, then removes stale `block-state.json`. | No current healthcheck or production reader found. | Written only in execute repair path after repaired events are persisted and before compatibility rewrite. | No checked-in `repair-state.json` fixture. | `issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract` source-order assertion. | No fixture round trip; no healthcheck surfacing; no production reader. | `defer` |
| `runtime-owner.json` | No golden replay fixture; owner file is runtime lease state, not event-log replay state. | Not rewritten by event-log repair; runtime owner CLI can validate, renew, clear, or remove current-process leases. | Healthcheck reads `runtimeOwner`; `scripts/restart-watcher` also reads/removes it. | Automatic loop validates lease before startup, renews before each tick, and clears current-process lease on exit. | Tests reject owner-only and old top-level-owner-plus-lease JSON; no checked-in owner fixture. | `prop_runtimeOwnerJsonAndParsing`, `runtimeOwnerLeaseParsingRejectsOwnerOnlyJson`, `runtimeOwnerClearRejectsRunningLease`, `runtimeOwnerCleanupClearsOnlyCurrentProcessLease`, healthcheck source assertion. | No checked-in fixture; healthcheck lookup also accepts an `owner` path while current writer emits `lease.runtime`; external operator shell parsing remains in `scripts/restart-watcher`. | `keep` |
| Compatibility snapshots | Golden snapshot directories are checked in for PR review and issue implement; event-log golden fixtures replay PR review, issue implement, and issue planning. | Repair writes compatibility files from repaired replay state; live `issue-snapshot.json` is not repair input. | Healthcheck does not read live `issue-snapshot.json`. | Live issue-planning `issue-snapshot.json` is written in execute mode before planner turn start; closed-scope completion also writes snapshot without starting a planner turn. | Golden directories are checked-in compatibility snapshots; no checked-in live `issue-snapshot.json` fixture. | `goldenReplayCases`, `goldenBootstrapCases`, `goldenEventLogCases`, `automaticDaemonLoopPlanningExecuteWritesSnapshotBeforeStart`, `automaticDaemonLoopPlanningClosedScopeCompletesWithoutPlannerTurn`. | No checked-in live `issue-snapshot.json` fixture; old live snapshots are represented only by write-timing tests. | `defer` |

## Surface Details

### `issue-state.json`

`src/CodexWatcher/Runtime/Compatibility.hs` produces `issue-state.json` for
issue implementation states, including ready-to-plan, planning, plan-ready,
implementation-ready, implementing, handoff, waiting for PR merge, post-merge
review, waiting for issue close, and complete issue states. Its fields include
`repoFullName`, `issueNumber`, `branch`, `issue_status`, `pr_number`,
`pr_url`, and `blocked_reason` where applicable.

Golden fixtures are present at:

- `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`
- `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`
- `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`

Healthcheck reads `issueState` for issue implement. Repair rewrites this file
through `writeCompatibilityFiles` after repaired replay succeeds. Existing
tests prove PR URL projection, golden replay/bootstrap, healthcheck surfacing,
and daemon write timing. The file remains a current operator/runtime contract,
so the readiness note is `keep`.

### `daemon-state.json`

`compatibilityStateWrites` writes idle, active, stopped, and concrete domain
daemon summaries. Daemon observed execute writes happen after event append, and
automatic-loop startup/reconciliation rewrites compatibility files from replay
before loop work continues.

Golden fixture evidence exists at:

- `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`

Healthcheck reads `daemonState` through shared state files. Repair rewrites
daemon state through the same compatibility projection when the repaired final
state produces it. Missing active/stopped fixture coverage keeps this away
from any removal-later classification; because it remains an operator contract,
the readiness note is `keep`.

### `planning-state.json`

There are two producer shapes:

- `EffectInterpreter.compileEffectPlan` compiles `RecordPlanningGraph` to a
  direct `PlannedWriteJson` at `<stateDir>/planning-state.json`.
- `compatibilityStateWrites` writes the same graph JSON for
  `PlanningWaitingForReadyIssues`.

Existing tests protect direct planned writes and compatibility parity for
indexed issue-planning behavior. Healthcheck does not currently read
`planning-state.json`, and no checked-in old `planning-state.json` fixture was
found. The readiness note is `defer`.

### PR Review State Files And PR URL Fields

The selected roadmap phrase maps to current files and fields as follows:

- Issue PR URL is the `pr_url` field in `issue-state.json`.
- PR review launch/config fixtures use `prUrl`.
- PR review compatibility files are `watcher-state.json`,
  `checker-state.json`, optional `agent-state.json`, and
  `reviewer-state.json`.

No dedicated `pr-url` or `pr-state` file was found. PR review golden
directories cover merged, unresolved, blocked, and clean-ready state-file
shapes. Healthcheck reads all PR review state files named above, plus
`block-state.json` and `runtime-owner.json`. Current PR review state files are
`keep`; the absent dedicated PR URL file wording is `defer` until an external
operator/script inventory proves there is no path expectation outside the repo.

### `block-state.json`

`block-state.json` is produced by both direct effect compilation and
compatibility projection:

- `RecordBlocked` compiles to a direct planned write with
  `Runtime.BlockedState.blockedStateJson`.
- `compatibilityStateWrites` writes `block-state.json` for `BlockedState`.
- `AutomaticLoop.Runner` writes repair-failure block state when replay fails.

Successful `repair-invalid-state --execute` removes stale `block-state.json`
after compatibility rewrite. Healthcheck reads it across issue planning, issue
implement, and PR review. The missing fixture for the runner repair-failure
JSON shape prevents remove-later classification, but the file remains a
current operator contract, so the readiness note is `keep`.

### `repair-state.json`

`repair-state.json` is written only by
`src/CodexWatcher/Cli/Command/Replay.hs` in
`repair-invalid-state --execute`. The source order remains:

1. archive the invalid event log;
2. write repaired `events.jsonl`;
3. write `repair-state.json`;
4. rewrite compatibility files from repaired replay state;
5. remove stale `block-state.json`.

No healthcheck reader, production reader, or checked-in fixture was found for
`repair-state.json`. Existing tests assert the dry-run/execute source-order
contract. The readiness note is `defer`.

### `runtime-owner.json`

`src/CodexWatcher/Runtime/Owner/Store.hs` writes a current lease marker with a
top-level `lease` object containing `runtime`, `pid`, `hostname`,
`claimedAt`, `expiresAt`, and `eventLogHeadHash`. Runtime owner CLI code reads,
validates, renews, clears, and removes leases. Automatic-loop execution
validates ownership before startup, renews before each tick, and clears only
the current process lease on exit.

Healthcheck surfaces `runtimeOwner`, and `scripts/restart-watcher` reads and
removes the file during restart cleanup. Tests reject older owner-only and
old top-level-owner-plus-lease JSON shapes. No checked-in owner fixture exists.
Because this is live daemon ownership state and operator tooling depends on
it, the readiness note is `keep`.

### Compatibility Snapshots

Checked-in golden directories are compatibility snapshots and are distinct
from live `issue-snapshot.json` writes:

- Golden PR review snapshots: `golden/pr-review/mlf2-pr6-merged`,
  `mlf2-pr6-unresolved`, `mlf2-pr6-blocked`, and `mlf2-pr6-clean-ready`.
- Golden issue implement snapshots:
  `golden/issue-implement/mlf2-issue42-plan-ready`,
  `mlf2-issue42-incomplete`, and `mlf2-issue42-blocked`.
- Live issue-planning snapshot path:
  `<stateDir>/issue-snapshot.json`.

Tests prove golden replay/bootstrap and live snapshot write timing before
planner turn start. No checked-in live `issue-snapshot.json` fixture exists,
and healthcheck does not read the live snapshot. The readiness note is
`defer`.

## Missing Evidence Before Any Future Removal

- Exhaustive old live state-directory fixtures for `issue-state.json` field
  combinations.
- Active and stopped `daemon-state.json` fixtures.
- Checked-in `planning-state.json`, `repair-state.json`,
  `runtime-owner.json`, and live `issue-snapshot.json` fixtures.
- A checked-in runner repair-failure `block-state.json` fixture.
- External operator and downstream script inventory for direct file consumers.
- A policy round that explicitly classifies surfaces after this evidence.

No surface in this round is approved for deprecation or removal.
