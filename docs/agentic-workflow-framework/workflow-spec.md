# Workflow Spec

Status: implemented internal API contract, with explicit design direction.

## Purpose

A workflow spec is the boundary between a concrete workflow and the reusable
framework kernel. The framework owns pure replay, observation planning,
effect-plan validation, labels, transaction execution, and interpreter
boundaries. A concrete workflow owns its states, events, observations, effects,
errors, replay result, lifecycle policy, codecs, prompts, compatibility files,
and runtime decisions.

The rule remains:

```text
Generic framework code should not know moifold issue, PR, branch, review-thread, or merge semantics.
```

## Current Unindexed Contract

`CodexWatcher.Workflow.Spec` exposes the current `WorkflowSpec` class and
`PlannedTransition` value:

```haskell
data PlannedTransition spec = PlannedTransition
  { plannedEvent :: WorkflowEvent spec
  , plannedPreCommitEffects :: WorkflowEffectPlan spec
  , plannedPostCommitEffects :: WorkflowEffectPlan spec
  }

class WorkflowSpec spec where
  type WorkflowState spec
  type WorkflowEvent spec
  type WorkflowObservation spec
  type WorkflowObservedTick spec
  type WorkflowEffect spec
  type WorkflowEffectPlan spec
  type WorkflowReplayResult spec
  type WorkflowError spec
```

The associated types are intentionally broad. A spec can use closed ADTs,
GADTs, indexed wrappers, or compatibility views internally, but the framework
only depends on this contract.

The current methods group into five responsibilities:

- replay: `workflowInitialEvent`, `workflowApplyEvent`,
  `workflowReplayEvents`, and `workflowReplayState`;
- observations and decisions: `workflowObserve`,
  `workflowObservedTransition`, `workflowObservedState`,
  `workflowPlanTransition`, and `workflowPlanObservation`;
- effect validation: `workflowValidateEffects`,
  `workflowEffectPlanEffects`, and `workflowEffectAllowed`;
- lifecycle closure: `workflowIsTerminal`;
- diagnostics: `workflowStateLabel`, `workflowEventLabel`,
  `workflowObservationLabel`, and `workflowEffectLabel`.

`workflowPlanObservation` is a framework helper, not a separate policy hook. It
uses the spec's pure observation function and extracts the resulting planned
transition.

## Transition Semantics

The framework treats a planned transition as accepted protocol intent:

```text
current state + observation -> planned event + pre-commit effects + post-commit effects
```

The planned event is the durable fact to append. Pre-commit effects are actions
that must succeed before the event is accepted. Post-commit effects are
consequences of accepted event truth and may be retried or regenerated from
replay depending on their metadata.

A spec should keep this division deterministic. Runtime reads may become
observations, and runtime writes may be effects, but spec code should not call
GitHub, git, the filesystem, or the app-server directly.

## Current Indexed Contract

`CodexWatcher.Workflow.Indexed.Spec` exposes the public indexed workflow
contract. It does not replace the unindexed contract; it provides stronger
phase/source and target markers for adapters that can carry them.

The current indexed class provides associated types for:

- `IndexedWorkflowState spec state`;
- `IndexedWorkflowEvent spec source target`;
- `IndexedWorkflowObservation spec source target`;
- `IndexedWorkflowObservedTick spec source target`;
- `IndexedWorkflowEffect spec source target`;
- `IndexedWorkflowEffectPlan spec source target`;
- `IndexedWorkflowReplayResult spec state`;
- `IndexedWorkflowError spec`.

It mirrors the unindexed responsibilities with indexed initial/apply/observe,
transition projection, replay, effect validation, permission checks, terminal
checks, and source/target labels.

Mixed event logs and daemon dispatch use existential wrappers:

- `SomeIndexedWorkflowState`
- `SomeIndexedWorkflowEvent`
- `SomeIndexedWorkflowObservation`
- `SomeIndexedWorkflowEffect`
- `SomeIndexedWorkflowEffectPlan`
- `SomeIndexedPlannedTransition`
- `SomeIndexedWorkflowObservedTick`
- `SomeIndexedWorkflowReplayResult`

The helper functions that unwrap these existentials and read their labels are
part of the current contract. They keep source/target labels available at
replay, diagnostics, and daemon boundaries without requiring every caller to be
fully indexed.

## Bridge Surface

`WorkflowSpecIndexedBridge` adapts an unindexed `WorkflowSpec` to an
`IndexedWorkflowSpec`. The bridge owns wrap/unwrap functions for state, event,
observation, observed tick, effect, effect plan, and replay result. It also
owns source and target label projection for events, observations, and observed
ticks.

The exported bridge helpers delegate the indexed operations through the
unindexed spec:

- initial event;
- event application;
- observation planning;
- observed transition/state projection;
- planned transition construction;
- event replay and replay-state projection;
- effect validation and effect extraction;
- permission checks;
- terminal checks;
- labels.

This bridge is the implemented compatibility path for existing moifold indexed
adapters and the second workflow proof. Richer domain/phase public APIs are
future design unless they are expressed through these exported indexed types and
bridge helpers.

## State Rules

Concrete workflow state remains spec-owned.

State definitions should satisfy:

- a state value identifies exactly one concrete lifecycle position;
- active agent turns are represented by explicit typed handles;
- terminal states preserve evidence for why the workflow stopped;
- runtime handles and compatibility facts are explicit, not hidden in untyped
  blobs;
- replay-derived facts are not duplicated unless compatibility or performance
  requires it.

`WorkflowState` values may be existential or indexed internally. Framework
helpers only require labels, terminal checks, replay-state projection, and
permission validation through the spec.

## Event Rules

Events are durable accepted facts. They are not arbitrary snapshots.

Every event must answer:

- what fact was accepted;
- which prior state can accept it;
- which next state it produces through replay;
- which effects are planned by replay/application;
- whether replay is deterministic.

Concrete event JSON, event `type` strings, schema versions, old-log migration,
and golden fixtures are owned by moifold or by another concrete workflow. The
core package provides generic codec and replay contracts; it does not own the
current moifold `WatcherEvent` schema.

## Observation Rules

Observations are external or runtime facts before they become event truth.

Examples include:

- a classified agent turn;
- remote PR metadata;
- review-thread data;
- a command failure report;
- a human stop or repair request.

Observation handling must be pure:

```text
current state + observation -> rejected OR planned transition
```

Adapters read the world and build observations. Specs decide whether those
observations are acceptable and which event/effect plan follows.

## Effect Rules

Effects describe intended runtime behavior. They do not perform it.

Every effect plan should be inspectable before interpretation and should expose
enough information for:

- permission checking;
- dry-run rendering;
- pre/post commit ordering;
- idempotency or retry policy;
- failure classification;
- adapter interpretation.

The generic core currently supplies reusable effect metadata and traversal
helpers in `CodexWatcher.Workflow.Execution.Core`. Concrete effect values remain
spec-owned.

## Capability Rules

The implemented generic capability vocabulary is:

- `ReadWorld`
- `StartAgent`
- `WriteLocal`
- `MutateRemote`
- `Merge`
- `Sleep`
- `Stop`

Permission is checked through `workflowValidateEffects`,
`workflowEffectPlanEffects`, `workflowEffectAllowed`, and the reusable helpers
in `CodexWatcher.Workflow.Permission.Core`. The DSL does not enforce permission
by itself.

## Terminal Semantics

Every spec must define terminal closure with `workflowIsTerminal`.

Default expectation:

- complete states do not accept normal domain events;
- blocked states require explicit retry, repair, stop, or another modeled
  recovery path;
- stopped states reject normal domain events;
- post-terminal repair is an explicit protocol, not silent event acceptance.

The framework uses terminal checks for replay summaries, audit
recommendations, daemon projections, and test laws.

## Implemented Laws

The current framework contract is designed around these laws:

### Replay Determinism

Replaying the same event list yields the same final state and planned effect
history.

### Observation Consistency

If `workflowObserve state observation` accepts an observation and emits an
event, replaying that event from the same state reaches the same next state and
effect plan.

### Permission Soundness

Every effect emitted by replay or observation planning must pass the spec's
effect validation and per-effect permission checks for the state that emitted
it.

### Dry-Run Safety

Dry-run execution renders intended action reports without mutating event logs,
local artifacts, remote systems, app-server state, daemon ownership, or
compatibility files.

### Terminal Closure

Terminal states reject normal domain events unless a concrete repair or stop
protocol explicitly permits a transition.

## Deferred Design Direction

The earlier docs described domain and phase associated data families directly
on `WorkflowSpec`. That remains a useful direction for stronger public APIs,
but it is not the current frozen contract. The implemented contract is the
associated-type surface in `CodexWatcher.Workflow.Spec`, plus the public
indexed workflow contract and bridge in `CodexWatcher.Workflow.Indexed.Spec`.
