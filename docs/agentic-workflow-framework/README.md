# Agentic Workflow Framework

Status: design draft.

This directory captures the plan for abstracting an agent workflow framework out of moifold.

The framework thesis is:

```text
Agent work should be written as a typed protocol, not as prompts plus shell scripts.
```

The current moifold implementation proves the shape with GitHub issue planning, issue implementation, PR review fixing, merge readiness, durable event logs, dry-run execution, and recovery. The extracted framework should keep those correctness properties while letting other agent workflows define their own domains, observations, events, effects, and interpreters.

## Big picture

The reusable idea is a typed operating layer around unreliable agent output:

```text
external world
  -> observation
  -> typed event
  -> state transition
  -> typed effect plan
  -> runtime interpreter
```

Agents may produce incomplete, blocked, or incorrect output. The workflow boundary should still be replayable, deterministic, permission-checked, and inspectable.

## Documents

- [extraction-plan.md](extraction-plan.md): package boundaries, migration phases, acceptance criteria, and risks.
- [workflow-spec.md](workflow-spec.md): contract every concrete workflow must implement.
- [event-log-and-transactions.md](event-log-and-transactions.md): replay, event schema, commit ordering, idempotency, and failure semantics.
- [agent-turn-contract.md](agent-turn-contract.md): agent roles, inputs, output classification, retry behavior, and observation boundaries.
- [monad-dsl.md](monad-dsl.md): Haskell-shaped DSL sketch for authoring workflows without giving workflow code direct IO authority.

## Design constraints

- Preserve the current `State -> Event -> Decision -> EffectPlan -> Interpreter` model.
- Keep the event log as durable truth.
- Treat agent output as an observation that must be classified before it becomes accepted workflow state.
- Make effects first-class data so dry-run can render intended mutation.
- Check effects against domain and phase permissions before execution.
- Keep runtime IO behind interpreters.
- Avoid abstracting so far that moifold-specific GitHub assumptions become hidden framework assumptions.

## Non-goals

- Do not build a generic prompt runner.
- Do not expose `liftIO` in the workflow DSL.
- Do not replace typed states with configurable YAML.
- Do not hide GitHub, Codex, or filesystem behavior behind vague "tool" blobs.
- Do not split packages until a second workflow has forced the boundary.

## Target shape

The eventual layering should be:

```text
agent-workflow-core
  typed workflow kernel, event replay, effect plans, permissions, daemon loop contracts

agent-workflow-codex
  Codex app-server thread/turn protocol, structured output classification, turn lifecycle helpers

agent-workflow-github
  GitHub/git command adapters and typed GitHub effects

moifold
  issue planning, issue implementation, PR review, merge readiness, runbooks
```

The first extraction should be internal module extraction inside this repository. External package splitting should come later, after the internal API is exercised by at least one workflow outside the existing issue/PR lifecycle.
