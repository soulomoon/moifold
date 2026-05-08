# Event Log and Transactions

Status: implemented internal API contract.

## Purpose

The event log is workflow truth. Runtime snapshots, compatibility files, local
plans, branch state, PR bodies, healthcheck output, repair state, and
app-server turns are external or derived state unless a concrete workflow
commits them as event payload.

The reusable framework contract answers:

- what event type and schema were encoded;
- how replay initialized and applied events;
- which transition failed, at which event index, and after which prior state;
- which effects are pre-commit or post-commit;
- whether an effect is idempotent, check-then-act, at-most-once, or a derived
  write;
- which transaction stage failed;
- which audit and daemon projection an operator can inspect.

Concrete JSON schemas, old-log compatibility, fixture contents, filesystem
writes, process execution, healthcheck, repair, daemon leases, and compatibility
file names remain moifold-owned.

## Codec Contract

`CodexWatcher.Workflow.Codec` freezes a generic codec contract over an event
type and an encoded representation:

- `WorkflowEventTypeLabel` is the stable event type label;
- `WorkflowSchemaVersion` is the event schema version label;
- `WorkflowMetadataLabel` names metadata fields a codec recognizes;
- `WorkflowDecodeError` records optional type label, optional schema version,
  and a reason;
- `WorkflowCodecContract` supplies event type labels, schema versions, metadata
  labels, encode, encoded-type-label extraction, and decode;
- `validateWorkflowCodecRoundTrip` checks encode/decode equality for a value;
- `validateWorkflowCodecEncodedTypeLabel` checks that encoded data carries the
  expected type label;
- `formatWorkflowDecodeError` renders a stable diagnostic.

This generic contract deliberately does not depend on Aeson. A concrete
workflow may use Aeson for its event JSON, but the reusable package only
requires a typed encoded value and decode/encode hooks.

## Event Log Lines

`CodexWatcher.Workflow.EventLog.File.Core` freezes generic line handling:

- blank lines are ignored by `numberedNonBlankWorkflowEventLogLines`;
- a caller-provided line decoder is used by `decodeWorkflowEventLogLines`;
- `WorkflowEventLogLineDecodeError` records the original line number and
  reason;
- `formatWorkflowEventLogLineDecodeError` renders line-addressable failures.

Opening files, choosing `events.jsonl`, preserving old fixture paths, and
repairing bad logs are concrete workflow or moifold responsibilities.

## Replay

`CodexWatcher.Workflow.EventLog.Core` freezes pure replay helpers around
`WorkflowSpec`:

- `initializeWorkflowEvent` calls `workflowInitialEvent`;
- `applyWorkflowEvent` calls `workflowApplyEvent`;
- `replayWorkflowEventLog` delegates to `workflowReplayEvents`;
- `replayWorkflowEventLogDetailed` reports an empty log, initialization
  failure, transition failure, final state, per-event effect plans, event
  count, and the first terminal event index;
- `WorkflowTransitionFailure` records the failed event, event label, prior
  state label, spec error, and rendered reason;
- `WorkflowReplayFailure` records event index, optional event, event label,
  prior state label, and reason;
- `WorkflowReplaySummary` records final state, effect-plan history, event
  count, and optional terminal event index;
- `EventLogFixtureContract` validates expected final state label and optional
  event count.

Replay is pure. It does not read files, write compatibility snapshots, execute
actions, call GitHub, or inspect app-server state.

## Commit Boundary

`CodexWatcher.Workflow.EventLog.Commit.Core` freezes the event commit
abstraction:

```haskell
newtype WorkflowEventCommitter m event failure =
  WorkflowEventCommitter
    { runWorkflowEventCommitter :: event -> m (Either failure ()) }
```

`commitWorkflowEvent` runs the committer. `appendEncodedWorkflowEvent` encodes
once and appends the encoded value through a caller-supplied append function.
`workflowEncodedEventCommitter` combines an effectful encoder and append action
into a committer.

The core abstraction owns commit sequencing. The concrete append target, file
locking, backup policy, and compatibility event-log format remain outside the
framework package.

## Execution Metadata

`CodexWatcher.Workflow.Execution.Core` freezes generic effect metadata and
action traversal:

- `WorkflowCapability`: `ReadWorld`, `StartAgent`, `WriteLocal`,
  `MutateRemote`, `Merge`, `Sleep`, and `Stop`;
- `EffectCommitOrder`: `PreCommit` or `PostCommit`;
- `EffectIdempotency`: `Idempotent`, `CheckThenAct`, `AtMostOnce`, or
  `DerivedWrite`;
- `WorkflowEffectMetadata`: capability, commit order, and idempotency;
- `WorkflowPlannedActionOf`: original effect, compiled action, and metadata;
- `WorkflowCompiledEffectPlanOf`: compiled actions;
- `WorkflowCheckedActionFailureOf`: the failed action, failed report, prior
  reports, and classified reason.

The reusable traversal helpers compile effects to actions, dry-run compiled
plans, execute compiled plans, execute checked actions until the first failure,
partition actions by commit order, and partition reports using the same action
ordering. Concrete effects, command text, and IO interpreters remain adapter or
moifold responsibilities.

## Permission Validation

`CodexWatcher.Workflow.Permission.Core` freezes reusable permission checks:

- `WorkflowPermissionPolicy` contains state labels, effect labels, effect-plan
  extraction, and per-effect permission checks;
- `workflowSpecPermissionPolicy` derives that policy from a `WorkflowSpec`;
- `workflowEffectPermissionChecks` and
  `workflowEffectPermissionChecksWithPolicy` produce per-effect check records;
- `validateWorkflowEffectPlanCore` and
  `validateWorkflowEffectPlanWithPolicy` return the first denial;
- `WorkflowPermissionValidationError` and
  `formatWorkflowPermissionValidationError` make denials operator-readable.

Permission validation happens after a plan is produced and before transaction
execution. The DSL does not provide arbitrary IO authority, and it does not
replace spec-level permission validation.

## Transaction Model

`CodexWatcher.Workflow.Transaction.Core` freezes the observed transaction
contract. `WorkflowObservedTransactionHooks` supplies:

- spec-error mapping into a transaction failure type;
- effect compilation;
- action partitioning into pre-commit and post-commit actions;
- dry-run rendering;
- action execution;
- event commit;
- after-commit callback;
- retryability classification.

The observed dry-run path is:

```text
replay prior events
-> observe current state
-> validate combined pre/post effects
-> compile effects
-> partition actions
-> dry-run pre actions
-> dry-run post actions
-> build audit
```

The observed execute path is:

```text
replay prior events
-> observe current state
-> validate combined pre/post effects
-> compile effects
-> execute pre-commit actions
-> commit one event
-> replay events plus committed event
-> run after-commit callback
-> execute post-commit actions
-> build audit
```

`runWorkflowPreparedDryRunTransaction` and
`runWorkflowPreparedExecuteTransactionDetailed` allow callers that already have
a replay result and planned transition to use the same validation and execution
boundary.

## Failure Stages

Detailed execute transactions classify failure by `WorkflowTransactionFailureStage`:

- `WorkflowTransactionPrepareFailure`;
- `WorkflowTransactionPreCommitActionFailure`;
- `WorkflowTransactionEventCommitFailure`;
- `WorkflowTransactionPostCommitReplayFailure`;
- `WorkflowTransactionPostCommitCallbackFailure`;
- `WorkflowTransactionPostCommitActionFailure`.

`WorkflowObservedTransactionFailure` records the stage, reason, optional prior
replay, optional plan, optional final state, committed events, optional compiled
effects, pre/post reports, and optional audit. This is the framework-owned
diagnostic boundary; concrete workflows decide whether a failure becomes a
blocked event, an operator error, or a retry.

## Audit and Daemon Projections

`CodexWatcher.Workflow.Audit` freezes operator-facing `WorkflowTickAudit`
values:

- prior state label;
- optional observation label;
- optional committed event label;
- optional final state label;
- pre/post reports;
- optional failure classification;
- next daemon recommendation: continue, retry, repair, or stop.

Dry-run audits have no committed event. Success audits include the committed
event and stop when the final state is terminal. Failure audits classify retry
or stop from caller-provided failure retryability.

`CodexWatcher.Workflow.Daemon.Core` freezes generic daemon projections from
transaction results and failures. `WorkflowObservedDaemonTickResult` records
replay, compiled effects, action reports, committed events, final state,
pre/post reports, and audit; the failure projection records the failure stage
and related transaction evidence. This module does not own concrete daemon
loops, PID files, leases, process supervision, app-server startup, sleep policy,
or repair behavior.

## Moifold-Owned Event Policy

The reusable framework does not own these concrete event-log and runtime
decisions:

- moifold `WatcherEvent` constructors and JSON `type` fields;
- Aeson object shapes and golden replay fixture contents;
- schema migration policy and old-log repair commands;
- `events.jsonl` path selection, file append locking, and backups;
- compatibility writes such as `issue-state.json`, `daemon-state.json`,
  `planning-state.json`, PR URL files, block state, repair state, and runtime
  owner files;
- concrete command execution, process failure interpretation, healthcheck, and
  repair;
- issue/PR lifecycle choices such as when to merge, close, publish a review, or
  fan out child workflows.

Those decisions can use the framework contracts, but they are not part of the
reusable API freeze.
