# Agent Turn Contract

Status: design draft.

## Purpose

Agent turns are one source of observations. They are not the source of truth.

The workflow decides when to start an agent, what role it has, what input it receives, what output schema is expected, and how output is classified. Only classified output can become a typed observation and then a durable event.

## Agent role

An agent role should be a typed value:

```haskell
data AgentRole spec role input output =
  AgentRole
    { roleName :: Text
    , roleInstructions :: input -> Text
    , roleOutputSchema :: Maybe Value
    , roleClassifier :: RawTurnOutput -> Either ClassificationError output
    }
```

The role defines:

- Name.
- Purpose.
- Input type.
- Output type.
- Output schema.
- Classifier.
- Retry policy.
- Allowed workflow phases.
- Expected side effects, if any.

The role does not run the turn. It describes the turn that the workflow may ask the runtime to start.

## Turn handles

A started turn should be represented by a typed handle:

```haskell
data TurnRef role output =
  TurnRef
    { turnThreadId :: ThreadId
    , turnId :: TurnId
    }
```

The workflow state should store active turn handles explicitly. A phase with an active agent turn should not pretend to be idle.

## Starting a turn

Starting a turn is a planned effect:

```haskell
StartAgentTurn :: AgentRole spec role input output -> input -> Effect spec StartAgent
```

The runtime starts the app-server turn and returns a concrete turn id. The workflow records that fact with a typed event such as `TurnStarted`.

Rules:

- A turn-start event should not be committed until the runtime has a thread id and turn id.
- Dry-run should render the turn request without starting it.
- The input text and output schema should be deterministic for the same workflow state.
- Approval, sandbox, model, and effort settings are runtime configuration, not hidden prompt text.

## Reading a turn

Reading a turn is a runtime observation step.

The adapter reads app-server state and produces one of:

- turn still running.
- turn completed with output.
- turn failed.
- thread entered system error.
- turn disappeared or cannot be found.

The workflow then classifies the result:

```text
raw app-server result -> classified agent output -> workflow observation
```

If the turn is still running, the workflow should stay in the active phase and normally emit only a sleep effect.

## Output classes

Most agent roles should normalize to a small set of output classes:

- `Complete`: the requested role claims the work is done.
- `Incomplete`: the role made progress but needs another turn.
- `Blocked`: the role cannot proceed without external change.
- `Problems`: reviewer or verifier found issues.
- `Clean`: reviewer or verifier found no blocking issues.
- `Noop`: nothing to do.
- `Malformed`: output could not be classified.

Each concrete role can add typed payloads:

- implementation PR number.
- plan markdown.
- review evidence.
- resolved review thread ids.
- follow-up issue text.
- validation command output summary.

Do not store large raw transcripts as the primary workflow event. Keep normalized output in events and make raw turn data inspectable through runtime logs or app-server history.

## Classifier contract

Classifiers must be deterministic and testable.

Rules:

- Structured JSON output wins over free text.
- Free-text compatibility should be explicit and covered by tests.
- Missing required fields produce `Malformed` or `Incomplete`, not silent success.
- A classifier should not call external tools.
- A classifier should include enough error text for blocked state or diagnostics.
- A classifier should not weaken a role's required evidence to make a turn look successful.

## Retry policy

Each role should define retry behavior:

```haskell
data RetryPolicy =
  RetryPolicy
    { maxMalformedRetries :: Int
    , maxIncompleteRetries :: Int
    , retryBackoff :: BackoffPolicy
    , retryPrompt :: RetryReason -> Text
    }
```

The workflow should distinguish:

- malformed output retry.
- incomplete work retry.
- transient app-server failure retry.
- blocked output.
- policy failure.

Retry counters should come from event history, not mutable runtime memory.

## Blocking

An agent-blocked result is a workflow fact only after it is converted to a typed observation and accepted as an event.

Blocked events should include:

- role name.
- active turn id.
- human-readable reason.
- evidence or missing prerequisite when available.
- whether retry is expected to help.

Blocked state should stop mutation until repair, retry, or human intervention is explicit.

## Side effects by agents

Some agents mutate the target worktree during their turn. The framework cannot fully type-check those mutations before they happen, but it can control how they are accepted.

Rules:

- The role must declare expected side-effect scope.
- The workflow must validate the result before committing success.
- The event should record the relevant durable facts, such as branch, PR number, commit, or artifact path.
- Review or validation turns should not be treated as proof of correctness without explicit evidence.
- A role that is supposed to be read-only should run under a read-only sandbox when possible.

## Human review boundary

Agent output should not bypass human or policy gates for irreversible operations.

For example:

- Merge requires a merge capability and pre-merge gate.
- Closing an issue requires the workflow to have reached the issue-close phase.
- Publishing review findings requires normalized review evidence.
- Creating child workflows requires parent fanout permission.

The workflow can automate these gates, but the event log should show exactly why the gate passed.

## App-server adapter

The Codex app-server adapter should own:

- JSON-RPC request construction.
- Thread start.
- Turn start.
- Turn read.
- Turn interrupt.
- System-error interpretation.
- Thread id and turn id parsing.

The workflow spec should see only typed effects, typed observations, and typed turn handles.

## Tests

Each agent role should have:

- Input rendering tests.
- Output schema snapshot tests where practical.
- Classifier tests for complete, incomplete, blocked, malformed, and role-specific outputs.
- Retry counter tests.
- Active-turn replay tests.
- System-error recovery tests.
