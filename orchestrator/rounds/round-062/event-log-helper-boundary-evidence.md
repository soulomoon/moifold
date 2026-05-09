### Scope

This round is evidence-only for `CodexWatcher.Workflow.EventLog`. No production
source, tests, Cabal descriptors, public docs, golden fixtures, runtime
compatibility files, roadmap files, `orchestrator/project-contract.md`, or
`orchestrator/state.json` were changed.

The current boundary is:

- `src/CodexWatcher/Workflow/EventLog.hs` is the moifold-facing compatibility
  facade. It reexports reusable event-log and audit helpers, defines the
  concrete moifold audit type alias, and keeps moifold wrappers over
  `MoifoldSpec`, `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and
  `ReplayFailure`.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs` owns generic
  initialization, apply, detailed replay, replay summaries/failures, fixture
  contracts, validation, and formatting. It does not read files, execute
  effects, or own concrete event schemas.
- `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` owns reusable audit
  values, labels, reports, daemon recommendations, and generic audit
  constructors.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs` owns
  generic numbered nonblank line decoding and line-error formatting.
- `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs` owns
  generic event commit and encoded append helpers.
- `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/EventLog/Replay.hs`,
  and `src/CodexWatcher/EventLog/File.hs` remain concrete moifold event,
  replay, and file wrappers around `WatcherEvent` and current event JSON
  behavior.

### Import Inventory

Command:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
```

Current output count: 11 matching import lines.

Current output:

```text
test/Main.hs:79:import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
test/Main.hs:80:import CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit
test/Main.hs:81:import CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore
agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs:24:import CodexWatcher.Workflow.EventLog.Core
agent-workflow-core/src/CodexWatcher/Workflow/Transaction/Core.hs:25:import CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter, commitWorkflowEvent)
src/CodexWatcher/Daemon.hs:54:import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog
src/CodexWatcher/Daemon.hs:55:import CodexWatcher.Workflow.EventLog.Commit.Core
src/CodexWatcher/EventLog/File.hs:6:import CodexWatcher.Workflow.EventLog.File.Core
src/CodexWatcher/Workflow/EventLog.hs:55:import CodexWatcher.Workflow.EventLog.Core
src/CodexWatcher/Workflow/DocsMigration.hs:71:import CodexWatcher.Workflow.EventLog
src/CodexWatcher/Workflow/DocsMigration.hs:80:import CodexWatcher.Workflow.EventLog.Commit.Core (WorkflowEventCommitter (..))
```

Command:

```sh
rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
```

Current file count: 7 files.

Current file list:

```text
agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs
agent-workflow-core/src/CodexWatcher/Workflow/Transaction/Core.hs
src/CodexWatcher/Daemon.hs
src/CodexWatcher/EventLog/File.hs
src/CodexWatcher/Workflow/DocsMigration.hs
src/CodexWatcher/Workflow/EventLog.hs
test/Main.hs
```

The required anchored command also matches replacement submodules under
`CodexWatcher.Workflow.EventLog.*`. A stricter exact-facade scan:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog( +as +| *$| *\()' src test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
```

currently finds only `src/CodexWatcher/Workflow/DocsMigration.hs:71`. The
qualified facade imports in `src/CodexWatcher/Daemon.hs` and `test/Main.hs`
are still product/test users of the facade and are blockers for narrowing.

### Broad Reference Scan

Command:

```sh
rg -n 'CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|CodexWatcher\.Workflow\.Audit|WatcherEvent|golden replay|event-log|event log' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test golden
```

Current output count: 414 lines.

Relevant classifications:

- Observed usage: `src/CodexWatcher/Daemon.hs` imports the facade and commit
  core. It uses facade audit types/accessors for moifold daemon tick output and
  commit reports, while `commitMoifoldObservedEvent` binds concrete
  `WatcherEvent` appends to the daemon event-log path.
- Observed usage: `src/CodexWatcher/Workflow/DocsMigration.hs` imports the
  facade for `EventLogFixtureContract`, `WorkflowReplaySummary`,
  `WorkflowTickAudit`, `formatWorkflowReplayFailure`,
  `replayWorkflowEventLogDetailed`, and audit report accessors. It also imports
  commit core directly for `WorkflowEventCommitter`.
- Observed usage: `src/CodexWatcher/EventLog/File.hs` imports file core and
  keeps concrete file IO plus `WatcherEvent` Aeson decoding in moifold.
- Test assertions: `test/Main.hs` imports the facade plus file/commit cores and
  covers codec contracts, golden type fields, golden event-log replay,
  file-core line numbering/error formatting, concrete file-wrapper behavior,
  core/facade replay parity, moifold initialize/apply facade parity,
  DocsMigration fixture replay, and audit recommendations.
- Package exposure: `moifold.cabal` exposes
  `CodexWatcher.Workflow.EventLog`; `agent-workflow-core.cabal` exposes
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`, and
  `CodexWatcher.Workflow.Audit`.
- Public/policy documentation: `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  records `CodexWatcher.Workflow.EventLog` as a deferred compatibility/product
  facade and says preferred imports are guidance, not deprecation, migration,
  or removal approval. `package-consumer-guide.md` and
  `implemented-api-freeze.md` present generic core modules as preferred
  reusable imports and keep concrete `WatcherEvent`, event `type` fields,
  schemas, and golden replay policy moifold-owned.
- Fixture/replay evidence: `golden/event-log/**/events.jsonl` currently has 10
  checked-in old event logs; `test/Main.hs` lists the same 10 event-log
  fixtures with expected domains/phases.
- Downstream/operator evidence: no downstream or operator repository/reference
  outside this local tree was available in the round worktree. That evidence is
  unavailable, not approval to deprecate, narrow, migrate, or remove the facade.

### Package Exposure

Command:

```sh
rg -n 'CodexWatcher\.Workflow\.EventLog|CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|CodexWatcher\.Workflow\.Audit' moifold.cabal agent-workflow-core/agent-workflow-core.cabal docs/agentic-workflow-framework/compatibility-deprecation-policy.md docs/agentic-workflow-framework/package-consumer-guide.md docs/agentic-workflow-framework/implemented-api-freeze.md
```

Current output confirms:

- `moifold.cabal:116` exposes `CodexWatcher.Workflow.EventLog`.
- `agent-workflow-core/agent-workflow-core.cabal:47` exposes
  `CodexWatcher.Workflow.Audit`.
- `agent-workflow-core/agent-workflow-core.cabal:51-53` expose
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.EventLog.Core`, and
  `CodexWatcher.Workflow.EventLog.File.Core`.
- The public docs name core modules as preferred reusable imports, while
  `CodexWatcher.Workflow.EventLog` remains a moifold product/compatibility
  facade with `defer` status.

### Helper Ownership Table

| Helper exported by `CodexWatcher.Workflow.EventLog` | Current owner | Preferred reusable import | Current facade status | Current callers/tests |
| --- | --- | --- | --- | --- |
| `initializeMoifoldWorkflow` | `src/CodexWatcher/Workflow/EventLog.hs` | none; concrete moifold wrapper over `initializeWorkflowEvent @MoifoldSpec` | concrete moifold compatibility helper | `test/Main.hs` core/facade parity and facade replay tests |
| `applyMoifoldWorkflowEvent` | `src/CodexWatcher/Workflow/EventLog.hs` | none; concrete moifold wrapper over `applyWorkflowEvent @MoifoldSpec` | concrete moifold compatibility helper | `test/Main.hs` core/facade parity and facade replay tests |
| `replayMoifoldWorkflowEvents` | `src/CodexWatcher/Workflow/EventLog.hs` | none; concrete wrapper over `CodexWatcher.EventLog.Replay.replayEventLog` | concrete moifold compatibility helper | `test/Main.hs` facade/direct replay parity |
| `EventLogFixtureContract` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `src/CodexWatcher/Workflow/DocsMigration.hs`; `test/Main.hs` moifold and DocsMigration fixture-contract tests |
| `WorkflowReplayFailure` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | failure formatting and DocsMigration failure tests in `test/Main.hs` |
| `WorkflowReplaySummary` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `src/CodexWatcher/Workflow/DocsMigration.hs`; core detailed replay tests |
| `WorkflowTransitionFailure` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | transition failure label/reason tests in `test/Main.hs` |
| `initializeWorkflowEvent` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `test/Main.hs` moifold and DocsMigration initialization tests |
| `applyWorkflowEvent` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `test/Main.hs` moifold and DocsMigration apply/failure tests |
| `replayWorkflowEventLog` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `test/Main.hs` facade/direct replay parity |
| `replayWorkflowEventLogDetailed` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `src/CodexWatcher/Workflow/DocsMigration.hs`; moifold and DocsMigration replay tests |
| `formatWorkflowReplayFailure` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | `src/CodexWatcher/Workflow/DocsMigration.hs` formats replay failures |
| `formatWorkflowTransitionFailure` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | moifold wrappers and transition failure tests |
| `validateEventLogFixtureContract` | `agent-workflow-core/.../EventLog/Core.hs` | `CodexWatcher.Workflow.EventLog.Core` | reusable helper reexported through compatibility facade | moifold and DocsMigration fixture-contract tests |
| `WorkflowTickAudit` | facade type alias over `CodexWatcher.Workflow.Audit.WorkflowTickAudit spec FailureClassification report` | `CodexWatcher.Workflow.Audit` when not relying on moifold failure binding | product-facing compatibility alias because it fixes moifold `FailureClassification` | `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, many audit assertions in `test/Main.hs` |
| `WorkflowNextDaemonRecommendation` and constructors | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit helper reexported through compatibility facade | daemon/docs/test audit recommendation assertions |
| `workflowAuditCommittedEventLabel` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test audit assertions |
| `workflowAuditFailureClassification` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | retry recommendation test and transaction failure audit tests |
| `workflowAuditFinalStateLabel` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test audit assertions |
| `workflowAuditNextDaemonRecommendation` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test audit assertions |
| `workflowAuditObservationLabel` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | retry recommendation and transaction tests |
| `workflowAuditPostCommitReports` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test pre/post report assertions |
| `workflowAuditPreCommitReports` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test pre/post report assertions |
| `workflowAuditPriorStateLabel` | `agent-workflow-core/.../Audit.hs` | `CodexWatcher.Workflow.Audit` | reusable audit accessor reexported through compatibility facade | daemon/docs/test audit assertions |
| `workflowDryRunAudit` | facade wrapper over `WorkflowAudit.workflowDryRunAudit @spec` | `CodexWatcher.Workflow.Audit` | reusable audit constructor reexported through compatibility facade | audit behavior tested through daemon/transaction paths |
| `workflowSuccessAudit` | facade wrapper over `WorkflowAudit.workflowSuccessAudit @spec` | `CodexWatcher.Workflow.Audit` | reusable audit constructor reexported through compatibility facade | `src/CodexWatcher/Daemon.hs` and observed transaction tests |
| `workflowFailureAudit` | facade wrapper over `WorkflowAudit.workflowFailureAudit @spec failureIsRetryable` | `CodexWatcher.Workflow.Audit` only when caller supplies retry binding explicitly | product-facing compatibility helper because it binds moifold `failureIsRetryable` | `test/Main.hs` failure-audit retry recommendation |

Adjacent replacement imports are not facade exports:

- File helpers: `WorkflowEventLogLineDecodeError`,
  `decodeWorkflowEventLogLines`, `formatWorkflowEventLogLineDecodeError`, and
  `numberedNonBlankWorkflowEventLogLines` are available from
  `CodexWatcher.Workflow.EventLog.File.Core`.
- Commit helpers: `WorkflowEventCommitter`, `appendEncodedWorkflowEvent`,
  `commitWorkflowEvent`, and `workflowEncodedEventCommitter` are available from
  `CodexWatcher.Workflow.EventLog.Commit.Core`.

### Current Caller Groups

- Moifold daemon/product behavior: `src/CodexWatcher/Daemon.hs` uses
  `CodexWatcher.Workflow.EventLog` for `WorkflowTickAudit`,
  `workflowSuccessAudit`, and audit accessors on moifold daemon transaction
  results. It imports commit core directly for `WorkflowEventCommitter` and
  `appendEncodedWorkflowEvent`, while `commitMoifoldObservedEvent` appends
  concrete `WatcherEvent` values to the daemon event log.
- DocsMigration/generic workflow behavior:
  `src/CodexWatcher/Workflow/DocsMigration.hs` imports facade replay, fixture,
  failure formatting, audit type, and audit report helpers. It uses
  `replayWorkflowEventLogDetailed @DocsMigrationSpec` and
  `formatWorkflowReplayFailure` in `replayDocsMigrationEvents`, and it exposes
  `docsMigrationEventLogFixture` plus `docsMigrationEventLogFixtureContract`.
- Test/golden behavior: `test/Main.hs` imports the facade and replacement
  file/commit cores. It validates old `WatcherEvent` codec behavior, golden
  event-log decode/replay, core/file/commit helpers, moifold facade/core parity,
  and DocsMigration fixture replay.
- Public/package docs: `compatibility-deprecation-policy.md` presents the
  facade as a supported compatibility/product surface with `defer` status;
  `package-consumer-guide.md` and `implemented-api-freeze.md` present
  `EventLog.Core`, `EventLog.File.Core`, `EventLog.Commit.Core`, and `Audit` as
  preferred reusable imports.

### Old-Log And Golden Replay Coverage

Command:

```sh
find golden/event-log -type f -name 'events.jsonl' -maxdepth 4 -print | sort
```

Current output count: 10 event-log fixtures.

Current output:

```text
golden/event-log/issue-implement/mlf2-issue42-complete/events.jsonl
golden/event-log/issue-implement/mlf2-issue42-implementation-blocked/events.jsonl
golden/event-log/issue-implement/mlf2-issue42-incomplete-then-complete/events.jsonl
golden/event-log/issue-implement/mlf2-issue42-pr-created/events.jsonl
golden/event-log/issue-implement/mlf2-issue42-pr-reused/events.jsonl
golden/event-log/issue-planning/mlf2-planning-ready/events.jsonl
golden/event-log/pr-review/mlf2-pr6-merged/events.jsonl
golden/event-log/pr-review/mlf2-pr6-reviewer-comments/events.jsonl
golden/event-log/pr-review/mlf2-pr6-reviewer-incomplete/events.jsonl
golden/event-log/pr-review/mlf2-pr6-worker-incomplete/events.jsonl
```

Readback evidence:

- `src/CodexWatcher/EventLog/Types.hs` parses the `"type"` field and maps it
  through the current `eventName` strings; it reports schema version 1 through
  `watcherEventSchemaVersion` and exposes `watcherEventCodecContract`.
- `test/Main.hs` asserts canonical JSON round trips, codec event labels,
  schema version 1, encoded type-label validation, metadata tolerance, and
  golden event-log type fields matching decoded `WatcherEvent` values.
- `test/Main.hs` lists the 10 event-log fixtures with expected
  domains/phases and replays them through `loadEventLogFile` plus
  `replayEventLog`.
- `test/Main.hs` runs `goldenReplayCases`, `goldenEventLogCases`, and
  `goldenBootstrapCases` in the test entry path.
- `test/Main.hs` covers `replayMoifoldWorkflowEvents` versus
  `replayWorkflowEventLog @MoifoldSpec`, `initializeMoifoldWorkflow` versus
  `initializeWorkflowEvent @MoifoldSpec`, and `applyMoifoldWorkflowEvent`
  versus `applyWorkflowEvent @MoifoldSpec`.
- `test/Main.hs` covers `replayWorkflowEventLogDetailed` and
  `validateEventLogFixtureContract` for moifold fixtures.
- `test/Main.hs` covers DocsMigration fixture codec/replay validation through
  `replayWorkflowEventLogDetailed @DocsMigrationSpec` and
  `validateEventLogFixtureContract`.
- `src/CodexWatcher/EventLog/File.hs` keeps concrete file loading and
  `WatcherEvent` decoding in moifold while delegating only numbered-line
  decoding/error formatting to file core. Tests cover existing fixture decode
  and malformed line error formatting.

### Blockers Before Any Later Cleanup

- Current source/test imports through the facade remain observed in
  `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`,
  and `test/Main.hs`; replacement imports existing in core modules do not prove
  those callers can be migrated now.
- The concrete moifold helpers bind `MoifoldSpec`, `WatcherEvent`,
  `SomeWatcherState`, `EffectPlan`, `ReplayFailure`, `failureIsRetryable`, and
  moifold replay policy. These are product/compatibility obligations, not
  reusable-package ownership.
- Current `WatcherEvent` JSON `type` fields, schema version, parse behavior,
  old logs, and golden replay fixtures are compatibility contracts.
- Public docs still describe `CodexWatcher.Workflow.EventLog` as a deferred
  compatibility/product facade. The docs explicitly say preferred-import
  guidance is not deprecation, migration, or removal approval.
- Downstream/operator evidence was unavailable from this worktree. Absence of
  local downstream/operator references is not approval.
- No selected later round authorizes production import rewrites, facade
  narrowing, helper movement, deprecation pragmas, Cabal exposure changes,
  fixture rewrites, event schema changes, or removal.
