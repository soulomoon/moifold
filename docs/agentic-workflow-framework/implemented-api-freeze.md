# Implemented API Freeze

Status: implemented local package API contract.

This page freezes the reusable workflow-framework surface implemented by the
current local package candidates:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

The contract is package-internal to this repository. It is not a package
publication promise, not a compatibility-facade removal plan, and not a move of
moifold issue/PR lifecycle policy into the framework.

## Framework Thesis

The stable reusable shape is:

```text
State -> Event -> Decision -> EffectPlan -> Interpreter
```

Framework code owns typed workflow protocols, replay, observation planning,
effect-plan validation, transaction boundaries, adapter data, and dry-runable
effect interpretation contracts. Concrete products own their lifecycle policy,
durable event vocabulary, prompt policy, filesystem layout, process ownership,
healthcheck, repair, and compatibility files.

## Core Package

`agent-workflow-core` exposes these modules:

- `CodexWatcher.Workflow.Spec`
- `CodexWatcher.Workflow.Indexed.Spec`
- `CodexWatcher.Workflow.DSL`
- `CodexWatcher.Workflow.Codec`
- `CodexWatcher.Workflow.EventLog.Core`
- `CodexWatcher.Workflow.EventLog.File.Core`
- `CodexWatcher.Workflow.EventLog.Commit.Core`
- `CodexWatcher.Workflow.Execution.Core`
- `CodexWatcher.Workflow.Permission.Core`
- `CodexWatcher.Workflow.Transaction.Core`
- `CodexWatcher.Workflow.Audit`
- `CodexWatcher.Workflow.Daemon.Core`
- `CodexWatcher.Workflow.Failure`

`CodexWatcher.Workflow.Spec` is the unindexed contract. A `WorkflowSpec`
provides associated types for `WorkflowState`, `WorkflowEvent`,
`WorkflowObservation`, `WorkflowObservedTick`, `WorkflowEffect`,
`WorkflowEffectPlan`, `WorkflowReplayResult`, and `WorkflowError`. It also
provides initial-event replay, event application, observation handling,
observed-transition projection, replay, effect validation, effect extraction,
per-effect permission checks, terminal-state checks, and labels for states,
events, observations, and effects.

`PlannedTransition` is the stable decision value. It carries the accepted
`plannedEvent`, `plannedPreCommitEffects`, and `plannedPostCommitEffects`.
`workflowPlanObservation` is the helper that turns a state and observation into
a planned transition by using the spec's pure observation hook.

`CodexWatcher.Workflow.Indexed.Spec` is the public indexed workflow contract.
It exposes indexed associated types, indexed planned transitions, existential
wrappers for mixed state/event/observation/effect/replay values, and
`WorkflowSpecIndexedBridge` for adapting the unindexed contract into indexed
adapters that keep source and target states visible at the type level. Richer
domain and phase modeling remains design direction unless it is present in
these exported associated types and bridge helpers.

`CodexWatcher.Workflow.DSL` is the pure authoring layer. `WorkflowM` accumulates
a `WorkflowEffectPlan` or fails with `Text`; `Transition` wraps a
`PlannedTransition` and a return value. The implemented helpers are `emit`,
`failWorkflow`, `advance`, `transitionFromPlan`, `transitionEvent`,
`transitionPreCommitEffects`, `transitionPostCommitEffects`, and
`transitionEffects`. The DSL has no `liftIO`; permission validation is performed
by the workflow spec and transaction path after a plan is produced.

`CodexWatcher.Workflow.Codec` freezes the generic codec contract:
`WorkflowEventTypeLabel`, `WorkflowSchemaVersion`, `WorkflowMetadataLabel`,
`WorkflowDecodeError`, `WorkflowCodecContract`,
`validateWorkflowCodecRoundTrip`, and
`validateWorkflowCodecEncodedTypeLabel`. The generic contract validates type
labels, schema labels, metadata labels, decode errors, and round trips without
owning concrete Aeson event schemas.

`CodexWatcher.Workflow.EventLog.Core` freezes pure replay helpers and failure
reporting: initialization, event application, detailed replay summaries,
fixture contracts, transition failures, replay failures, terminal event index
tracking, and human-readable failure formatting. `EventLog.File.Core` owns
line-numbered nonblank log-line decoding as a generic bytes-to-event helper.
`EventLog.Commit.Core` owns the commit abstraction that encodes once and appends
through a `WorkflowEventCommitter`.

`CodexWatcher.Workflow.Execution.Core` freezes generic effect metadata and
execution traversal: `WorkflowCapability`, `EffectCommitOrder`,
`EffectIdempotency`, `WorkflowEffectMetadata`, planned actions, compiled plans,
dry-run traversal, execute traversal, commit-order partitioning, and checked
action execution that stops on the first classified failure.

`CodexWatcher.Workflow.Permission.Core` freezes the reusable permission-check
surface over a spec: permission policies, per-effect check reports, validation
errors, spec-derived policies, and formatted denial messages.

`CodexWatcher.Workflow.Transaction.Core` freezes the observed transaction
contract. Transaction hooks replay prior events, observe, validate effects,
compile effects, partition pre/post actions, dry-run or execute pre-commit
actions, commit one event, replay after commit, run an after-commit callback,
execute post-commit actions, and emit detailed stage-aware failures. The
failure stages are prepare, pre-commit action, event commit, post-commit replay,
post-commit callback, and post-commit action.

`CodexWatcher.Workflow.Audit` and `Daemon.Core` freeze generic operator-facing
projections. Audit values report prior state, observation, committed event,
final state, pre/post reports, failure classification, and daemon
recommendation. Daemon core projects transaction results and failures into
daemon tick result records; it does not own concrete daemon loops or process
leases.

`CodexWatcher.Workflow.Failure` freezes a small reusable failure classifier:
transient, fatal, policy violation, and external state mismatch, plus retry
classification for external failure text.

## Codex Adapter Package

`agent-workflow-codex` exposes these modules:

- `CodexWatcher.AppServerProtocol`
- `CodexWatcher.Workflow.Agent`
- `CodexWatcher.Workflow.Agent.Ids`
- `CodexWatcher.Workflow.Agent.Types`
- `CodexWatcher.Workflow.Agent.Codex`
- `CodexWatcher.Workflow.Agent.Codex.Client`
- `CodexWatcher.Workflow.Agent.Codex.Interpreter`
- `CodexWatcher.Workflow.Agent.Codex.Protocol`
- `CodexWatcher.Workflow.Agent.Codex.Transport`
- `CodexWatcher.Workflow.Observation.Agent`

The stable adapter data includes typed request, thread, and turn ids;
`AgentRoleId`; retry policies and decisions; side-effect-scope metadata;
`AgentThreadPlan`; `AgentThreadStart`; `AgentTurnPlan`; `AgentTurnStart`;
`AgentTurnInterrupt`; `AgentTurnReadResult`; `AgentTurnReadFailure`; `TurnRef`;
and `agentTurnStartRef`. Concrete product role marker types and stable moifold
role ids remain moifold-owned.

`CodexWatcher.Workflow.Agent` freezes deterministic role classification around
`AgentRole`, `ClassifiedAgentOutput`, and `AgentOutputClass`. The output class
vocabulary is complete, incomplete, blocked, problems, clean, noop, and
malformed. Retry reasons are derived only for incomplete and malformed output in
the generic helper.

`CodexWatcher.AppServerProtocol` freezes JSON-RPC request construction for
initialize, initialized notification, thread start, thread name set, thread
read, turn start, turn interrupt, and plan collaboration mode. The protocol
surface also freezes thread/turn option records and sandbox-policy rendering.

`CodexWatcher.Workflow.Agent.Codex.Protocol` maps typed agent plans and turn
refs to app-server requests. `Client` parses JSON-RPC responses, turn records,
thread/turn ids, system-error state, thread-read materialization fallback, and
client failure formatting. `Interpreter` is the minimal request-sending record.
`Transport` owns websocket transport, endpoint/options/session handling,
timeouts, initialize sessions, request fallback, and endpoint-backed
interpreters. `CodexWatcher.Workflow.Agent.Codex` ties those pieces together
with parse/start/read/interrupt helpers.

`CodexWatcher.Workflow.Observation.Agent` freezes the generic observation bridge
from a classified `AppServerTurn` to a workflow observation and then to a
planned transition. It does not decide when an agent result becomes durable
truth; the concrete workflow spec still owns that policy.

## GitHub Adapter Package

`agent-workflow-github` exposes these modules:

- `CodexWatcher.Workflow.GitHub.Ids`
- `CodexWatcher.Workflow.GitHub.Remote`
- `CodexWatcher.Workflow.GitHub.Command`

`Ids` freezes typed wrappers for repositories, issues, PRs, branches, review
threads, and commit SHAs.

`Remote` freezes pure parsers and classifiers for GitHub/git observations:
`RepoName`, `IssueNumber`, `PrNumber`, `ReviewThreadId`, and related typed ids
flow into issue lists and issue state, PR lists and PR state, PR create
results, PR checks in JSON or table form, PR view metadata, review-thread
GraphQL payloads, current branch, head SHA, and remote branch SHA. It also
freezes `RemotePullRequestMergeStateStatus`, state rendering,
open/closed/merged predicates, merge-state classification,
`parseGhReviewThreads`, and the merge-state fix message helper.

`Command` freezes `GitHubCommandSpec` pure command specs for the supported `gh`
and `git` command surface: auth status, API user, issue list/view, PR
list/view/checks, `ghReviewThreadsCommand`, review-thread resolve/reply
mutations, PR merge, current branch, head SHA, porcelain status, remote branch
lookup, and push or push dry-run. It renders command data only; moifold owns
when commands are executed and which lifecycle transition requires them.

## Moifold-Owned Policy

The following surfaces are explicitly outside the reusable framework API:

- concrete `WatcherEvent`, `SomeWatcherState`, and moifold workflow states;
- concrete Aeson event codecs, current event `type` fields, schema migrations,
  and golden replay policy;
- issue planning, issue implementation, PR review, merge readiness, child
  workflow fanout, and close/merge/review-publication decisions;
- role-specific prompts, output schemas, evidence requirements, retry
  escalation, and structured-output compatibility policy;
- compatibility file names such as `issue-state.json`, `daemon-state.json`,
  PR URL files, block state, repair state, and runtime owner files;
- filesystem writes, process execution, PID files, leases, runtime ownership,
  concrete daemon loops, app-server startup, and watcher supervision;
- healthcheck, repair tools, operator runbooks, and destructive recovery
  choices;
- package publication, deprecation, and compatibility-facade removal policy.

Those boundaries are part of the freeze. A reusable package may expose data and
pure helpers for effects, adapters, transactions, or daemon projections, but it
must not absorb moifold lifecycle authority by renaming it as framework logic.

## Evidence

The source of truth for this freeze is the package descriptors, the modules
named above, and the boundary assertions in `test/BoundaryPolicySpec.hs`,
`test/AppServerSpec.hs`, and `test/GhGitSpec.hs`. The tests check the core,
Codex, and GitHub package dependency boundaries; current module exports;
source-level absence of moifold lifecycle ownership in reusable packages; Codex
request and parser behavior; GitHub parser behavior; and pure command rendering
parity with moifold runtime command rendering.
