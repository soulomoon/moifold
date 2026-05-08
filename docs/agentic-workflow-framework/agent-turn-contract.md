# Agent Turn Contract

Status: implemented internal API contract.

## Purpose

Agent turns are one source of observations. They are not workflow truth.

The reusable Codex adapter owns typed agent plans, app-server request
construction, response parsing, transport, turn references, retry metadata,
side-effect-scope metadata, deterministic classification helpers, and the bridge
from classified turn output to workflow observation planning.

Concrete workflows own when to start a role, which prompt and schema it uses,
what evidence is required, how output becomes a durable event, when retries are
exhausted, and what lifecycle state follows.

## Typed Ids and Role Data

`CodexWatcher.Workflow.Agent.Ids` freezes:

- `ThreadId`;
- `TurnId`;
- `RequestId`;
- `nextRequestId`.

`CodexWatcher.Workflow.Agent.Types` freezes:

- `AgentRoleId`;
- role marker types for the current moifold roles;
- stable role ids such as `planner`, `pr-review-worker`,
  `issue-plan-worker`, `issue-implementation-worker`, `reviewer`,
  `pr-review-verification-reviewer`, and `final-reviewer`;
- `AgentRetryReason`, `AgentRetryDecision`, `AgentRetryPolicy`,
  `defaultAgentRetryPolicy`, and `agentRetryDecision`;
- `AgentSideEffectScope`: read-only, writes worktree, mutates remote, or
  unknown side effects.

These values are reusable metadata. Moifold still owns which roles are used in
which issue/PR phase and what each role is allowed to prove.

## Thread and Turn Plans

The stable start/read/interrupt data is:

- `AgentThreadPlan`: role id, cwd, approval policy, sandbox, model, and
  developer instructions;
- `AgentThreadStart`: role id and thread id;
- `AgentTurnPlan`: role id, thread id, cwd, effort, model, approval policy,
  sandbox policy, input, optional output schema, and optional collaboration
  mode;
- `AgentTurnStart`: role id, thread id, and turn id;
- `AgentTurnInterrupt`: thread id and turn id;
- `AgentTurnReadResult turn`: optional turn plus optional thread system error;
- `AgentTurnReadFailure failure`: typed wrapper for read failure;
- `TurnRef agentRole output`: typed thread/turn handle;
- `agentTurnStartRef`: converts an `AgentTurnStart` into a typed `TurnRef`.

Workflow states should store active turn refs explicitly when an agent is
running. A concrete workflow decides which event records the start and which
later observation accepts completion, blocking, malformed output, or failure.

## Role Classification

`CodexWatcher.Workflow.Agent` freezes:

```haskell
data AgentRole input output = AgentRole
  { agentRoleName :: Text
  , renderAgentInput :: input -> Text
  , agentOutputSchema :: Maybe Value
  , agentRetryPolicy :: AgentRetryPolicy
  , agentSideEffectScope :: AgentSideEffectScope
  , agentClassifyTurn :: AppServerTurn -> Either Text (ClassifiedAgentOutput output)
  }
```

It also freezes:

- `AgentOutputClass`: complete, incomplete, blocked, problems, clean, noop, and
  malformed;
- `ClassifiedAgentOutput`;
- `classifyAgentRoleTurn`;
- `agentOutputRetryReason`, which returns retry reasons for incomplete and
  malformed output.

Classifiers must be deterministic and testable. They should not call external
tools. They normalize raw app-server turn data into typed output, but the
workflow spec decides whether that output becomes an observation and then an
event.

## App-Server Protocol

`CodexWatcher.AppServerProtocol` freezes the JSON-RPC request data:

- `AppServerRequest`;
- `ThreadStartOptions`;
- `TurnStartOptions`;
- `initializeRequest`;
- `initializedNotification`;
- `threadStartRequest`;
- `threadNameSetRequest`;
- `threadReadRequest`;
- `turnStartRequest`;
- `turnInterruptRequest`;
- `planCollaborationMode`.

The protocol constructors render deterministic request objects for the current
app-server methods. Sandbox-policy rendering is part of this protocol layer.
Runtime configuration values are data in the plan, not hidden prompt text.

## Codex Adapter Helpers

`CodexWatcher.Workflow.Agent.Codex.Protocol` maps typed plans to protocol
requests:

- `agentThreadPlanFromThreadStartOptions`;
- `agentThreadStartRequest`;
- `agentTurnStartRequest`;
- `agentThreadReadRequest`;
- `agentThreadInterruptRequest`.

`CodexWatcher.Workflow.Agent.Codex.Client` parses incoming app-server data:

- JSON-RPC responses, error responses, and notifications;
- app-server turn records and turn output;
- thread start ids and turn start ids;
- thread read turn lists;
- thread system-error status;
- thread-read materialization fallback;
- latest turn lookup by id;
- client failure formatting.

`CodexWatcher.Workflow.Agent.Codex.Interpreter` is the minimal adapter record:

```haskell
data AppServerInterpreter m = AppServerInterpreter
  { appServerSendRequest :: AppServerRequest -> m Value
  }
```

`CodexWatcher.Workflow.Agent.Codex.Transport` owns websocket transport and
endpoint-backed interpretation:

- `AppServerEndpoint` and client options;
- websocket connection wrapper;
- connect/send helpers;
- initialized request sessions;
- response timeout handling;
- thread-read fallback request handling;
- endpoint-backed `AppServerInterpreter`;
- thread-start helpers with endpoint or interpreter.

`CodexWatcher.Workflow.Agent.Codex` ties the protocol, client, interpreter, and
transport pieces together with parse/start/read/interrupt helpers and a cached
interpreter used by tests.

## Observation Bridge

`CodexWatcher.Workflow.Observation.Agent` freezes the generic bridge from
agent output to workflow planning:

- `classifiedAgentTurnObservation` classifies an `AppServerTurn` with an
  `AgentRole` and maps the payload into an observation value;
- `classifiedAgentTurnObservationPayload` returns only the mapped payload when
  classification succeeds;
- `planAgentTurnObservation` classifies a turn, builds a `WorkflowObservation`,
  and calls `workflowPlanObservation`.

This bridge keeps the observation boundary explicit:

```text
raw app-server turn -> classified agent output -> workflow observation -> planned transition
```

It does not commit events, write compatibility state, start daemons, publish
review comments, or decide lifecycle policy.

## Retry and Side-Effect Policy

The reusable package records retry counts and side-effect-scope metadata. It
does not decide when an issue planner, implementation worker, reviewer, or final
reviewer should be retried in a concrete workflow.

Concrete workflows must still decide:

- malformed output retry;
- incomplete work retry;
- transient app-server failure retry;
- blocked output handling;
- policy failure handling;
- whether an agent that writes a worktree has produced acceptable durable
  evidence.

Retry counters should come from event history or workflow state, not from
mutable adapter memory.

## Moifold-Owned Agent Policy

The reusable Codex adapter does not own:

- role-specific prompt text;
- structured output schemas and compatibility parsing policy;
- required evidence for success, clean review, or blocker findings;
- whether review findings are published;
- whether review threads are resolved or replied to;
- when a child workflow is launched;
- when an agent result becomes `WatcherEvent` truth;
- app-server process startup, persistent runtime ownership, or operator
  runbooks.

Those policies remain in moifold. The adapter provides typed request,
transport, parse, classification, and observation-planning surfaces that those
policies can use.
