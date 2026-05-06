# Workflow Spec

Status: design draft.

## Purpose

A workflow spec is the contract between a concrete agent workflow and the reusable framework kernel.

The framework owns replay, validation, dry-run, daemon execution, and interpreter boundaries. A concrete workflow owns its own domain model: states, phases, events, observations, effects, codecs, and policy.

The key rule:

```text
Generic framework code should not know moifold issue, PR, branch, review-thread, or merge semantics.
```

## Required concepts

Every workflow spec must define:

- `Domain`: the top-level workflow family, such as planning, implementation, review, release, or incident response.
- `Phase`: the lifecycle position within a domain.
- `State domain phase`: typed state for a domain at a phase.
- `Event domain from to`: accepted durable fact that advances replay from one phase to another.
- `Observation domain`: classified external fact that may become an event.
- `Effect capability`: intended mutation or runtime action.
- `Capability`: permission category used to validate effects.
- `Terminal`: blocked, complete, stopped, or another workflow-specific terminal shape.
- `Codec`: event JSON encoding and decoding.
- `Label`: human-readable names for state, event, observation, effect, domain, and phase.

The spec may define richer indexed types than this list, but these concepts must remain visible in the public contract.

## Core class sketch

```haskell
class WorkflowSpec spec where
  data Domain spec
  data Phase spec
  data State spec :: Domain spec -> Phase spec -> Type
  data Event spec :: Domain spec -> Phase spec -> Phase spec -> Type
  data Observation spec :: Domain spec -> Type
  data Effect spec :: Capability spec -> Type
  data Capability spec

  data WorkflowConfig spec
  data WorkflowError spec

  initialEvent
    :: SomeEvent spec
    -> Either (WorkflowError spec) (SomeState spec, EffectPlan spec)

  applyEvent
    :: SomeState spec
    -> SomeEvent spec
    -> Either (WorkflowError spec) (SomeState spec, EffectPlan spec)

  observe
    :: SomeState spec
    -> SomeObservation spec
    -> Either (WorkflowError spec) (ObservedTick spec)

  effectAllowed
    :: SomeState spec
    -> SomeEffect spec
    -> Bool

  isTerminal
    :: SomeState spec
    -> Bool
```

The final implementation may split this into smaller classes. The important part is the shape: the spec provides pure workflow semantics; the framework runs those semantics.

## Existential wrappers

The framework needs existential wrappers for mixed-phase event logs and daemon dispatch:

```haskell
data SomeState spec where
  SomeState
    :: KnownDomain spec domain
    => KnownPhase spec phase
    => State spec domain phase
    -> SomeState spec

data SomeEvent spec where
  SomeEvent
    :: Event spec domain from to
    -> SomeEvent spec

data SomeObservation spec where
  SomeObservation
    :: Observation spec domain
    -> SomeObservation spec

data SomeEffect spec where
  SomeEffect
    :: Effect spec capability
    -> SomeEffect spec
```

The wrappers are not an excuse to erase type information everywhere. Domain code should stay indexed where practical, and only cross existential boundaries at replay, serialization, CLI, and daemon dispatch.

## State rules

State definitions should satisfy:

- A state constructor belongs to exactly one domain and one phase.
- Runtime handles in state should be explicit, not buried in JSON blobs.
- Active agent turns should be represented as typed handles.
- Terminal states should preserve enough evidence to explain why the workflow stopped.
- State should not duplicate derived facts that can be replayed from events unless compatibility or performance requires it.

## Event rules

Events are durable accepted facts. They are not arbitrary snapshots.

Every event must answer:

- What external or internal fact was accepted?
- Which state shape can accept it?
- Which next state does it produce?
- Which effects should be planned after it?
- Is it safe to replay deterministically?

An event should not contain raw agent output unless the raw output is itself part of the durable protocol. Prefer normalized fields such as `status`, `reason`, `planMarkdown`, `reviewEvidence`, or `resolvedThreadIds`.

## Observation rules

Observations are facts gathered from the outside world or from agent turns before they become workflow truth.

Examples:

- A turn completed with structured output.
- A PR has unresolved review threads.
- A release checklist file exists.
- A command reported a transient failure.
- A human requested stop.

Observation handling must be pure:

```text
current state + observation -> rejected OR event + next state + effect plan
```

Observation code should not call GitHub, git, the filesystem, or the app-server directly. Those reads happen in adapters and become observations.

## Effect rules

Effects describe intended runtime behavior. They do not perform it.

Every effect should declare:

- Capability.
- Rendered dry-run form.
- Interpreter adapter.
- Commit ordering: pre-event, event-commit, or post-event.
- Idempotency expectation.
- Failure classification.

Effects should be specific enough to preserve safety. Prefer `CreatePullRequest issueConfig` over `RunShell "gh pr create ..."`.

## Capability rules

Capabilities are the permission vocabulary for effects.

A starting core set:

- `ReadWorld`: inspect external state.
- `StartAgent`: start or resume an agent turn.
- `WriteLocal`: write local workflow artifacts.
- `MutateRemote`: mutate GitHub, issue trackers, or other remote systems.
- `Merge`: perform irreversible integration actions.
- `Sleep`: wait for the next daemon tick.
- `Stop`: stop a daemon or mark terminal lifecycle.

The framework should allow per-spec capability extension, but common validation and rendering should work for the shared set.

## Terminal semantics

Every spec must define terminal states and the events that can occur after terminal state.

Default rule:

- After `Complete`, no more domain events are accepted.
- After `Blocked`, only explicit stop or repair events are accepted.
- After `Stopped`, no more domain events are accepted.

If a workflow needs post-terminal repair, it should model that as a specific repair protocol rather than silently accepting normal events.

## Codec contract

Event codecs must support:

- Stable `type` field.
- Versioned event schema.
- Unknown metadata fields.
- Precise parse errors.
- Round-trip tests for every event constructor.
- Golden replay fixtures for representative logs.

State codecs are optional for the core workflow model. Event replay should be enough to reconstruct workflow state. Compatibility snapshots can exist outside the core.

## Laws

A workflow spec should satisfy these laws:

### Replay determinism

Replaying the same event list yields the same final state and planned effect history.

### Observation consistency

If `observe state observation` accepts an observation and emits `event`, then replaying `event` from `state` reaches the same next state and effect plan.

### Permission soundness

Every effect emitted by `applyEvent` or `observe` must pass `effectAllowed` for the state that emitted it.

### Dry-run safety

Dry-run execution must not mutate event logs, local artifacts, remote systems, app-server state, or daemon ownership.

### Terminal closure

Terminal states reject normal domain events.

## Test obligations

Each workflow spec should provide:

- Event JSON round-trip tests.
- Replay golden tests.
- Invalid transition tests.
- Observation classification tests.
- Effect permission tests.
- Dry-run safety tests.
- Terminal-state tests.
