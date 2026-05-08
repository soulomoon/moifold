# Extraction Plan

Status: historical migration background.

The implemented internal API freeze now lives in
[implemented-api-freeze.md](implemented-api-freeze.md). This file preserves the
earlier extraction plan and design rationale; future-tense package-splitting
language below should be read as historical context unless the API-freeze page
or current source modules confirm it as implemented contract.

## Thesis

moifold should grow into a reusable agent workflow framework by extracting the typed workflow kernel from the concrete GitHub issue/PR workflows.

The framework should preserve the current correctness model:

```text
State -> Event -> Decision -> EffectPlan -> Interpreter
```

The goal is not to make every workflow generic. The goal is to let each workflow define its own precise protocol while reusing the machinery for replay, effect planning, permissions, dry-run, execution, daemon ownership, and recovery.

## What already looks reusable

These parts are already close to framework concepts:

- Typed domains, phases, action kinds, and mutability markers.
- GADT states that encode legal lifecycle shape.
- Observation classification before event commit.
- Append-only event logs and deterministic replay.
- Decisions that produce a next state plus an effect plan.
- Phase/effect permission validation.
- Effect compilation into planned runtime actions.
- Dry-run versus execute mode.
- Pre-commit and post-commit action ordering.
- Daemon loop support for active turns, idle ticks, terminal states, and recovery.
- Runtime interpreter records for process, file, JSON, app-server, and sleep/stop behavior.

## What is still moifold-specific

These are the main things that prevent immediate extraction:

- `Domain` is closed over `IssuePlanning`, `IssueImplement`, and `PrReview`.
- `Phase` names are shaped by the GitHub issue/PR lifecycle.
- `WatcherState` constructors mix generic lifecycle structure with moifold-specific payloads.
- `WatcherEvent` is one large ADT for all current moifold workflows.
- `ActionKind` and `Effect` include GitHub, PR review, branch, issue, and Codex turn concepts directly.
- `RuntimeCommand` is mostly a GitHub/git command surface.
- The daemon loop dispatches by pattern matching every concrete `WatcherState`.
- Codex app-server protocol, GitHub commands, and workflow policy live close together.

## Target abstractions

### Workflow spec

Introduce a spec type that owns the domain-specific associated types:

```haskell
class WorkflowSpec spec where
  data Domain spec
  data Phase spec
  data State spec :: Domain spec -> Phase spec -> Type
  data Event spec :: Domain spec -> Phase spec -> Phase spec -> Type
  data Observation spec :: Domain spec -> Type
  data Effect spec :: Capability -> Type

  initialFromEvent
    :: SomeEvent spec
    -> Either WorkflowError (SomeState spec, EffectPlan spec)

  applyEvent
    :: SomeState spec
    -> SomeEvent spec
    -> Either WorkflowError (SomeState spec, EffectPlan spec)

  observe
    :: SomeState spec
    -> SomeObservation spec
    -> Either WorkflowError (ObservedTick spec)

  effectAllowed
    :: SomeState spec
    -> SomeEffect spec
    -> Bool
```

This keeps the framework generic without requiring every workflow to share the same state constructors.

### Core kernel

The core package or module family should provide:

- Existential wrappers for state, event, observation, and effect.
- Event log encoding/decoding hooks.
- Replay runner.
- Decision and observed tick types.
- Effect plan accumulation.
- Permission validation.
- Dry-run rendering contract.
- Execute-mode action ordering.
- Daemon loop interfaces that do not know about GitHub.

### Agent protocol layer

Codex-specific behavior should move behind a reusable agent adapter:

- Start thread.
- Start turn.
- Read turn.
- Interrupt turn.
- Classify structured output.
- Normalize incomplete, blocked, complete, clean, and problems outcomes.
- Represent active turns as typed handles.

This layer should still be pure at the workflow boundary. It should emit typed `StartAgentTurn` or `ReadAgentTurn` effects that are interpreted later.

### Runtime adapters

GitHub, git, filesystem, JSON, process, and app-server effects should be separate interpreter adapters.

The framework should define the effect planning and execution contract. Adapters should define concrete effect constructors and interpreters.

## Migration phases

### Phase 0: Document the target

Deliverables:

- This directory.
- A short README index.
- A workflow spec contract.
- Event-log and transaction semantics.
- Agent turn contract.
- A DSL sketch.

Acceptance criteria:

- The plan names the reusable kernel and the moifold-specific parts.
- The plan keeps the typed protocol model as the central abstraction.

### Phase 1: Isolate generic effect execution

Move toward generic names around:

- `EffectPlan`.
- `CompiledEffectPlan`.
- `PlannedAction`.
- `ActionExecutionMode`.
- `ActionExecutionReport`.
- Dry-run and execute-mode traversal.

The first code movement can stay under `CodexWatcher.Workflow.*` to avoid premature package churn.

Acceptance criteria:

- Existing moifold effects still compile.
- Dry-run output is unchanged.
- `cabal test watcher-core-test` passes.

### Phase 2: Introduce an internal workflow kernel facade

Add internal modules such as:

```text
CodexWatcher.Workflow.Spec
CodexWatcher.Workflow.State
CodexWatcher.Workflow.EventLog
CodexWatcher.Workflow.EffectPlan
CodexWatcher.Workflow.Daemon
```

Initially these can wrap existing moifold types. The goal is to create stable names and contracts before changing representation.

Acceptance criteria:

- Replay, observed ticks, decisions, and effect validation can be described through the facade.
- Existing domain modules can import the facade without semantic changes.
- Golden replay remains unchanged.

### Phase 3: Split Codex app-server protocol from workflow policy

Move app-server request building and turn lifecycle helpers into an agent protocol adapter.

Acceptance criteria:

- Workflow code emits typed agent-turn effects.
- App-server JSON-RPC details are interpreted outside workflow transitions.
- Classifiers remain deterministic and testable.

### Phase 4: Parameterize one vertical slice

Pick one narrow workflow slice, preferably PR review checking, and express it through the internal `WorkflowSpec` facade.

Acceptance criteria:

- The slice still emits the same events for the same observations.
- The slice still produces the same effect plans.
- Phase/effect permission failures remain line-addressable in tests.

### Phase 5: Add the monad DSL as syntax over the kernel

Add a pure planning DSL that lowers to decisions and effect plans.

Acceptance criteria:

- The DSL cannot run IO.
- Effects are visible before interpretation.
- Phase changes are explicit.
- At least one existing transition is ported to the DSL with equal replay behavior.

### Phase 6: Prove the boundary with a second workflow

Before package splitting, add or prototype a second workflow that is not just another PR review path. Good candidates:

- Release checklist workflow.
- Incident triage workflow.
- Docs migration workflow.
- Repository maintenance workflow.

Acceptance criteria:

- The second workflow defines its own states, events, observations, effects, and agent roles.
- It reuses the core replay, effect plan, dry-run, execution, and daemon loop contracts.
- It does not require GitHub PR review concepts in the core.

### Phase 7: Split packages only after the facade holds

Once two workflows use the internal facade, consider package extraction:

```text
agent-workflow-core
agent-workflow-codex
agent-workflow-github
moifold
```

Acceptance criteria:

- Package boundaries follow real imports, not wishful architecture.
- `agent-workflow-core` has no GitHub or Codex app-server dependency.
- `agent-workflow-codex` has no moifold issue/PR lifecycle dependency.
- `agent-workflow-github` has no moifold state-machine dependency.

## Recommended first implementation slice

Start with a non-invasive facade, not a package split.

First patch sequence:

1. Add `CodexWatcher.Workflow.Types` with generic aliases and wrappers around current decision, effect, and observed tick concepts.
2. Move phase/effect validation naming behind `CodexWatcher.Workflow.Permission`.
3. Move dry-run/execute traversal naming behind `CodexWatcher.Workflow.Execution`.
4. Port one test module to import the facade.
5. Only then start replacing closed moifold ADTs with associated data families.

This gives immediate pressure on naming and contracts without risking a large semantic refactor.

## Open design decisions

- Associated data families versus typeclass methods over closed ADTs.
- Indexed monad syntax versus ordinary monad syntax with explicit phase commits.
- Whether event JSON codecs live in the core class or in separate schema modules.
- How much daemon lifecycle belongs in core versus adapter packages.
- Whether capabilities should be a closed core kind or a per-spec associated kind.
- How to represent pre-commit versus post-commit effects generically.
- How to version event logs once multiple workflow specs exist.

## Risks

- Abstracting too early and producing a renamed moifold instead of a framework.
- Making the DSL too powerful and losing dry-run/replay guarantees.
- Making the type layer too clever and slowing down workflow authors.
- Hiding GitHub assumptions behind generic names.
- Splitting packages before import boundaries are proven.

## Validation strategy

Every extraction phase should keep these checks green:

- Focused unit tests around the changed module.
- Golden replay for existing event logs.
- Effect permission tests.
- Dry-run safety tests.
- `cabal test watcher-core-test`.

When package boundaries appear, add dependency checks that prevent `agent-workflow-core` from importing GitHub, Codex app-server, or moifold domain modules.
