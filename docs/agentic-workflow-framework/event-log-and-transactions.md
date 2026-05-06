# Event Log and Transactions

Status: design draft.

## Purpose

The event log is the workflow source of truth. Runtime snapshots, compatibility files, local plans, branch state, PR bodies, and app-server turns are external or derived state.

The framework must make event commit behavior explicit enough that an operator can answer:

- What fact was accepted?
- What effects were attempted before the fact was committed?
- What effects were attempted after the fact was committed?
- Can this daemon tick be retried safely?
- If recovery is needed, which event is the first invalid fact?

## Event log format

Each workflow instance owns one append-only `events.jsonl` file.

Each line is one JSON object with:

- `type`: stable event name.
- `schemaVersion`: event schema version.
- workflow-specific payload fields.
- optional metadata that replay may ignore.

Recommended metadata:

- `emittedAt`: wall-clock time.
- `workflowId`: stable workflow instance id.
- `domain`: rendered domain label.
- `phase`: rendered source phase when known.
- `actor`: daemon, agent role, human, repair tool, or test.
- `source`: command, app-server turn, GitHub read, repair, or manual import.
- `correlationId`: id tying runtime reads and effects to the committed event.

Replay must ignore unknown metadata fields, but it must not ignore unknown event `type` values.

## Initialization

The first event initializes exactly one workflow instance.

Rules:

- Empty logs are invalid unless the caller is explicitly creating a new workflow.
- A second initialization event is invalid.
- Initialization events must contain all data needed to reconstruct the first typed state.
- A workflow may define multiple initialization event types, but only one may appear in a log.

## Replay

Replay is pure:

```text
[Event] -> Either ReplayFailure ReplayResult
```

Replay result should include:

- final typed state.
- effect plan history, if needed for diagnostics.
- event count.
- first terminal event, if any.
- warnings for compatibility or deprecated events.

Replay failure should include:

- event index.
- event type.
- parse or transition reason.
- prior state label when available.

## Schema evolution

Event schemas must be versioned deliberately.

Allowed compatible changes:

- Add optional metadata fields.
- Add optional payload fields with deterministic defaults.
- Rename only by accepting both old and new fields during a transition window.
- Add new event types if old replays are unaffected.

Breaking changes require:

- A new schema version.
- A migration or repair command.
- Golden fixtures for old and new logs.
- A documented reason.

The framework should prefer preserving old event meanings over rewriting history.

## Transaction model

One daemon tick has this shape:

```text
load events
-> replay current state
-> collect observation
-> classify observation into planned transition
-> validate effects
-> run pre-commit effects
-> append event
-> replay final state
-> write derived compatibility state
-> run post-commit effects
-> report
```

The planned transition should expose:

```haskell
data PlannedTransition spec =
  PlannedTransition
    { transitionEvent :: SomeEvent spec
    , transitionPreCommitEffects :: EffectPlan spec
    , transitionPostCommitEffects :: EffectPlan spec
    }
```

## Pre-commit effects

Pre-commit effects run before the event is appended.

Use pre-commit effects when the event claims that an external mutation already happened or when failed mutation means the fact should not be accepted.

Examples:

- Create a PR before recording `PullRequestCreated`.
- Start an app-server turn before recording `TurnStarted`.
- Push a branch before recording `BranchAdvanced`.

If a pre-commit effect fails, the event is not committed. The daemon can retry the same observation or report a runtime failure.

## Post-commit effects

Post-commit effects run after the event is appended and final state is replayed.

Use post-commit effects when the event is the durable truth and the effect is a consequence that may be retried.

Examples:

- Write compatibility snapshots.
- Sleep until the next poll.
- Stop the daemon.
- Write local diagnostic state.

If a post-commit effect fails, the event remains committed. Recovery should replay the log and decide whether the missing derived effect can be retried.

## Idempotency

Every effect must declare an idempotency expectation:

- `Idempotent`: safe to repeat.
- `CheckThenAct`: safe if the interpreter checks current external state first.
- `AtMostOnce`: should not be repeated after unknown success.
- `DerivedWrite`: can be regenerated from replay.

The default for remote mutation should be `CheckThenAct` or `AtMostOnce`, not `Idempotent`.

## Failure classification

Runtime failures should be classified independently of workflow policy:

- `TransientFailure`: retry may succeed.
- `PermanentFailure`: retry without changes is not useful.
- `PolicyViolation`: the workflow attempted a forbidden effect.
- `ExternalStateMismatch`: external state contradicts workflow state.
- `InterpreterBug`: adapter returned malformed data or violated its contract.

Workflow code may convert some external-state mismatches into blocked state. Runtime code should not silently do that without a typed event.

## Derived state

Compatibility snapshots and generated files should be treated as derived state unless the workflow explicitly commits them as event payload.

Rules:

- Derived state can be regenerated from event replay.
- Derived writes should normally be post-commit effects.
- Missing derived files should cause repair or regeneration, not semantic drift.
- If an artifact is part of the durable protocol, store the relevant content or hash in the event.

## Repair

Repair is a workflow action, not arbitrary log editing.

Repair tools should:

- Load and parse the original event log.
- Identify the first invalid event.
- Propose an explicit repair plan.
- Preserve the original log or write a backup.
- Insert repair marker events when history is changed.
- Re-run replay after repair.

Repair should not erase evidence of a bad event unless the operator explicitly requests destructive cleanup.

## Concurrency and ownership

Each workflow instance should have one active owner in execute mode.

The framework should specify:

- Lease acquisition.
- Lease renewal.
- Stale lease detection.
- PID/process validation where available.
- Active turn marker cleanup.
- Parent/child workflow ownership.

Two execute daemons must not append to the same event log concurrently. Dry-run may inspect the same log concurrently because it does not mutate state.

## Parent and child workflows

Fanout and handoff should be represented as typed effects and events.

Parent rules:

- Parent state records which children are expected or active.
- Parent effects create child workflow state directories and initialization events.
- Parent fanout respects max parallel limits.
- Parent must not infer child completion from missing process state alone.

Child rules:

- Child initialization records parent reference when applicable.
- Child terminal events are observed by the parent through explicit observation.
- Child state directories are stable and unique.

## Audit output

Every tick should produce an audit report containing:

- prior state label.
- observation label.
- committed event, if any.
- final state label.
- pre-commit effect reports.
- post-commit effect reports.
- failure classification, if any.
- next daemon recommendation.

This report is separate from event truth. It is for operators and tests.
