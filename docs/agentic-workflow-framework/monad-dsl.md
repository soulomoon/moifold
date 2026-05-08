# Monad DSL

Status: implemented internal API contract.

## Principle

The workflow DSL is a pure planning DSL, not an IO DSL.

Workflow code can use ordinary Haskell composition to build typed protocol
intent, but external mutation must still be represented as typed effect plans,
rendered in dry-run, checked against workflow permissions, and interpreted by
runtime adapters.

There is no `liftIO` in the implemented DSL.

## Implemented Types

`CodexWatcher.Workflow.DSL` exposes two authoring values:

```haskell
newtype WorkflowM spec domain phase a = WorkflowM
  { runWorkflowM :: Either Text (a, WorkflowEffectPlan spec)
  }

data Transition spec domain from to a = Transition
  { transitionPlannedTransition :: PlannedTransition spec
  , transitionValue :: a
  }
```

`WorkflowM` accumulates a `WorkflowEffectPlan spec` while staying inside the
same domain and phase markers. The current implementation is pure and
writer-like: `Functor`, `Applicative`, and `Monad` combine effect plans with
`mempty` and `(<>)`.

`Transition` is the phase-change boundary. It wraps the framework
`PlannedTransition` plus the author's return value.

## Implemented Helpers

The current helper set is deliberately small:

- `emit :: WorkflowEffectPlan spec -> WorkflowM spec domain phase ()`
  appends an already-built effect plan.
- `failWorkflow :: Text -> WorkflowM spec domain phase a`
  rejects the authoring computation.
- `advance :: WorkflowSpec spec => WorkflowEvent spec -> WorkflowM spec domain from a -> Either Text (Transition spec domain from to a)`
  turns a phase-local program and event into a transition.
- `transitionFromPlan :: WorkflowSpec spec => WorkflowEvent spec -> a -> WorkflowEffectPlan spec -> Transition spec domain from to a`
  builds a transition directly from an event, value, and effect plan.
- `transitionEvent` reads the planned event.
- `transitionPreCommitEffects` reads the pre-commit effect plan.
- `transitionPostCommitEffects` reads the post-commit effect plan.
- `transitionEffects` combines pre-commit and post-commit plans.

`advance` uses `workflowPlanTransition`, so the split between pre-commit and
post-commit effects remains spec-owned. The DSL only supplies the pure effect
plan accumulated by the authoring computation.

## Runtime Boundary

The DSL lowers to `PlannedTransition`:

```text
WorkflowM effect plan + event -> PlannedTransition
```

After that point, the framework transaction path performs the safety work:

- replay the prior event log;
- observe or use the prepared transition;
- validate the combined pre/post effect plan through the spec;
- compile effects into adapter actions;
- dry-run or execute actions by commit order;
- commit exactly one event in execute mode;
- replay after commit;
- run post-commit callbacks and effects;
- produce audit and daemon projections.

The DSL does not call GitHub, git, the filesystem, app-server transport, sleep,
processes, healthcheck, or repair tools.

## Permission Boundary

Permission validation is not encoded by `WorkflowM` itself. The current
contract validates permissions through:

- `workflowValidateEffects`;
- `workflowEffectPlanEffects`;
- `workflowEffectAllowed`;
- `CodexWatcher.Workflow.Permission.Core`;
- `CodexWatcher.Workflow.Transaction.Core`.

This keeps the DSL useful for existing effect-plan types while preserving the
framework guarantee that effects remain inspectable before interpretation.

## Authoring Shape

A phase-local program can emit effects and return a value:

```haskell
program :: WorkflowM spec domain phase Artifact
program = do
  emit plannedReads
  emit plannedWrites
  pure artifact
```

A phase transition adds the durable event at the boundary:

```haskell
transition :: Either Text (Transition spec domain from to Artifact)
transition =
  advance acceptedEvent program
```

Reviewers should treat this as the implemented authoring contract. More
specific helpers for agent turns, GitHub effects, filesystem effects, or
indexed do-notation are future convenience layers unless they are exported from
`CodexWatcher.Workflow.DSL`.

## Error Model

The DSL can fail with `Text` while constructing a plan. Other failure classes
belong to later framework or concrete workflow layers:

- invalid observation: `WorkflowSpec` observation handling;
- policy rejection: spec permission validation;
- runtime failure: adapter execution;
- agent blocked or malformed output: Codex adapter classification plus concrete
  workflow policy;
- replay failure: event-log replay.

Keeping those layers separate is part of the API freeze.
