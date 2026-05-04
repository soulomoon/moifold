# Correctness model

moifold is built around one boundary: the agent may be unreliable, but the workflow protocol should be explicit, replayable, and constrained by types.

The runtime is intentionally split into a pure correctness core and a small effectful interpreter:

```text
State -> Event -> Decision -> EffectPlan -> Interpreter
```

## Model

### State

Typed watcher state records what kind of watcher is running and which lifecycle phase it is in. The important distinction is that a planning watcher, issue implementer watcher, and PR review watcher do not share one untyped bag of fields.

The type-level model carries domain and phase information so illegal combinations are hard to construct:

- A planner owns issue-tree planning state.
- An implementer owns a concrete issue, branch, and implementation lifecycle.
- A PR watcher owns a concrete PR and review lifecycle.
- Blocked, complete, stopped, and merge-related states are represented explicitly.

The goal is not to put all runtime facts in the type system. The goal is to make the legal workflow shape clear enough that accidental cross-domain transitions are difficult to express.

### Event

Every watcher advances by appending and replaying events. The append-only `events.jsonl` file is the durable source of history for a watcher state directory.

Events describe observed facts and accepted decisions, not arbitrary mutable snapshots. This gives operators and agents a recovery path:

- Inspect the event log.
- Replay state from the beginning.
- Identify the first invalid or blocked transition.
- Repair or resume without discarding unrelated history.

### Decision

A decision is pure data derived from the current typed state plus the next event or observation.

Examples include:

- Create subissues for a scoped planning graph.
- Start an implementer watcher for a ready issue.
- Prepare a branch and Codex turn for an issue.
- Move a PR watcher into review-fix mode.
- Mark a watcher blocked because the observed PR does not match the expected PR.

Decisions should be deterministic for the same replayed state and input event. Probabilistic Codex output is normalized before it becomes accepted workflow state.

### EffectPlan

An effect plan is a typed description of intended mutation. It is not the mutation itself.

Effect plans make permissions explicit:

- A planning watcher may create or update issue-planning artifacts.
- An implementer watcher may prepare issue workdirs, branches, Codex turns, and PR handoff state.
- A PR watcher may inspect review threads, start fix turns, and update review-clean state.
- Runtime guards may acquire leases, check pid ownership, read JSON, append events, and call `gh` or `git`.

This separation is the main trust boundary. Dry-run can render the plan before execute mode interprets it.

### Interpreter

The interpreter is the small runtime boundary that performs external IO:

- `gh`
- `git`
- process and lease checks
- JSON file IO
- Codex app-server JSON-RPC calls
- event-log append and repair helpers

The interpreter should be boring. It receives already-typed intent from the core and either performs it, reports failure, or turns unsafe conditions into blocked state.

## Invariants

moifold uses types for structural lifecycle guarantees and property tests for replay and runtime-data guarantees.

Important invariant classes:

- Replay determinism: replaying the same event log yields the same watcher state.
- Phase/effect permission: a watcher cannot plan or execute effects outside its domain and phase.
- PR consistency: a PR watcher stays attached to the expected PR number, branch, and state directory.
- Scoped fanout: child watchers are created only for concrete planned issues.
- Dry-run safety: render-only execution does not mutate GitHub, git, app-server state, or watcher events.
- Daemon ownership: two execute loops should not own the same state directory at the same time.
- Blocked over corrupt: invalid handoff, missing expected files, stale ownership, or malformed replay should stop in blocked state instead of silently continuing.

## Guarantees

moifold tries to guarantee:

- Workflow transitions are legal for the current watcher domain and phase.
- Planned effects are visible before execution.
- Durable history can be replayed after daemon or app-server failure.
- Agent work stays scoped to explicit GitHub issues, PRs, branches, and state directories.
- Runtime IO is isolated behind typed effect interpretation.

## Non-guarantees

moifold does not guarantee:

- Codex writes correct code.
- GitHub accepts every operation.
- Review feedback is complete or correct.
- The target repository builds unless checks are configured and enforced.
- Operators can ignore PR review, CI, or event-log inspection.

## Design rule

The type-level model owns lifecycle correctness. Runtime policy and external IO stay behind the runtime boundary until driven by typed effects.

Illegal lifecycle transitions should fail at compile time where practical and fail property tests otherwise.
