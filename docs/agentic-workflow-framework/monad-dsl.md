# Monad DSL Sketch

Status: design draft.

## Principle

The workflow DSL should be a planning DSL, not an IO DSL.

Workflow code should feel like ordinary Haskell workflow code, but it should only build typed protocol intent:

```text
do-notation for author ergonomics
event sourcing for truth
typed effects for trust
```

The DSL must not expose arbitrary `liftIO`. External mutation has to be represented as typed effects, rendered in dry-run, checked against permissions, and interpreted by the runtime.

## Two-level model

There are two useful levels:

1. `WorkflowM spec domain phase a`: ordinary monad for planning inside the current phase.
2. `Transition spec domain from to a`: indexed transition that commits an event and advances to a new phase.

This avoids forcing every helper into an indexed monad while still making phase changes explicit.

```haskell
newtype WorkflowM spec domain phase a =
  WorkflowM
    { runWorkflowM :: WorkflowContext spec domain phase -> Either WorkflowError (a, EffectPlan spec)
    }

data Transition spec domain from to a =
  Transition
    { transitionEvent :: Event spec domain from to
    , transitionValue :: a
    , transitionEffects :: EffectPlan spec
    }
```

Normal helper code can use ordinary `do` notation while staying in one phase. Phase movement happens at a named boundary.

```haskell
advance
  :: Event spec domain from to
  -> WorkflowM spec domain from a
  -> Transition spec domain from to a
```

## Capabilities

Effects should carry capabilities. A workflow phase should only be able to emit effects allowed by the current state.

```haskell
data Capability
  = ReadWorld
  | StartAgent
  | WriteLocal
  | MutateRemote
  | Merge
  | Sleep
  | Stop

emit
  :: Allowed spec domain phase effect
  => effect
  -> WorkflowM spec domain phase ()
```

The `Allowed` constraint can start as runtime validation through the current phase/effect checker. It can later move more permission information into types when the boundary is stable.

## Agent roles

Agent turns should be typed by role, input, and output.

```haskell
data Agent spec role input output =
  Agent
    { agentName :: Text
    , renderInput :: input -> Text
    , outputSchema :: Maybe Value
    , classifyTurn :: AppServerTurn -> Either Text output
    }

data TurnRef role output =
  TurnRef ThreadId TurnId
```

Starting or reading a turn is still effectful intent, not IO.

```haskell
startAgent
  :: Allowed spec domain phase (StartAgentTurn role)
  => Agent spec role input output
  -> input
  -> WorkflowM spec domain phase (TurnRef role output)

awaitAgent
  :: TurnRef role output
  -> WorkflowM spec domain phase (Maybe output)
```

`awaitAgent` should classify already-read app-server data supplied as an observation. If it needs a runtime read, the workflow should emit a typed read effect and stay idle until a later observation arrives.

## Example: issue implementation

The intended authoring style should look like this:

```haskell
issueImplementation
  :: IssueConfig
  -> WorkflowM Moifold IssueImplement Implementing ()
issueImplementation issue = do
  pr <- ensurePullRequest issue
  plan <- ensureIssuePlan issue pr
  updatePullRequestBody issue pr plan
  turn <- startAgent implementationAgent (ImplementationInput issue pr plan)
  recordActiveTurn turn
```

Completion is a separate observed transition:

```haskell
implementationCompleted
  :: PrNumber
  -> Maybe ThreadId
  -> Transition Moifold IssueImplement Implementing Implementing ()
implementationCompleted pr reviewerThread =
  advance (IssueImplementationCompleted pr reviewerThread) do
    handoffToReview pr reviewerThread
```

Blocked output is also explicit:

```haskell
implementationBlocked
  :: BlockedReason
  -> Transition Moifold IssueImplement Implementing Blocked Void
implementationBlocked reason =
  advance (WatcherBlocked reason) do
    recordBlocked reason
    stopDaemon
```

## Example: PR review

PR review can be expressed as small phase-local programs plus explicit transitions:

```haskell
reviewThreadsFound
  :: ReviewEvidence
  -> ActiveTurn
  -> Transition Moifold PrReview CheckingReviews FixingReviews ()
reviewThreadsFound evidence workerTurn =
  advance (PrReviewFeedbackFound evidence (activeTurnId workerTurn)) do
    startAgent reviewFixAgent (ReviewFixInput evidence)

reviewerClean
  :: CleanReviewEvidence
  -> [ReviewThreadId]
  -> Transition Moifold PrReview ReviewingClean WaitingMergeability ()
reviewerClean evidence resolvedThreads =
  advance (PrReviewCleanFound evidence resolvedThreads) do
    traverse_ resolveReviewThread resolvedThreads
    sleepUntilNextPoll
```

The examples are intentionally close to the current state-machine vocabulary. The first DSL version should clarify existing transitions before inventing a more abstract workflow language.

## Runtime boundary

The DSL should lower to a value the runtime can inspect:

```haskell
data PlannedTransition spec =
  PlannedTransition
    { plannedEvent :: SomeEvent spec
    , plannedPreCommitEffects :: EffectPlan spec
    , plannedPostCommitEffects :: EffectPlan spec
    }
```

The current runtime already distinguishes actions that run before event commit from actions that run after event commit. The framework should make that ordering explicit in the effect or interpreter layer.

## Interpreter contract

Interpreters should receive typed intent:

```haskell
compileEffectPlan
  :: RuntimeConfig adapter
  -> EffectPlan spec
  -> CompiledEffectPlan adapter

executeCompiledEffectPlan
  :: ActionExecutor adapter m
  -> ExecutionMode
  -> CompiledEffectPlan adapter
  -> m [ActionExecutionReport adapter]
```

The workflow DSL does not know how to call `gh`, `git`, the filesystem, or the Codex app-server. It only describes intended effects.

## Error model

The DSL should distinguish:

- Invalid observation: the observation does not apply to the current state.
- Policy rejection: the effect is not allowed from the current phase.
- Runtime failure: the interpreter could not perform a planned action.
- Agent blocked: the agent produced a structured blocked outcome.
- Replay failure: the event log cannot reconstruct a valid state.

Only runtime failure belongs to the interpreter. The other cases are workflow protocol facts and should be visible in replay or validation.

## MVP shape

Do not start with a full indexed monad stack.

Start with:

- `WorkflowM` as a writer-like pure builder for `EffectPlan`.
- `advance` as the only way to produce a phase-changing `Transition`.
- Runtime permission validation reused from the current checker.
- A small set of helpers for agent turns and local/GitHub effects.
- One ported transition from the existing state machine.

After the API feels stable, consider adding indexed do-notation or stronger type-level capability constraints.
