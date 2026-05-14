# Agentic Workflow Framework

Status: implemented local package-candidate contract, with migration background.

This directory captures the implemented local workflow-framework package
candidates consumed by moifold and the remaining migration background for
publishing them safely.

The framework thesis is:

```text
Agent work should be written as a typed protocol, not as prompts plus shell scripts.
```

The current moifold implementation now consumes the reusable framework shape as
standalone local package candidates:

- `agent-workflow-core`: typed workflow kernel, replay, effect plans,
  permissions, transactions, audit, and daemon projections.
- `agent-workflow-codex`: Codex app-server protocol, typed agent adapters,
  transport, and agent observation helpers.
- `agent-workflow-github`: typed GitHub ids, remote parsers/classifiers, and
  pure command specs.

Moifold remains the concrete product that owns issue planning, issue
implementation, PR review, merge readiness, compatibility files, daemon
ownership, healthcheck, repair, prompts, and runtime policy.

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

Implemented contract:

- [implemented-api-freeze.md](implemented-api-freeze.md): frozen local package
  API surface for `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github`, plus the moifold-owned policy boundary.
- [package-extraction-readiness.md](package-extraction-readiness.md):
  source-backed readiness report for the local package split, dependency
  ownership, compatibility facades, validation commands, and remaining
  blockers before any external package publication decision.
- [package-identity-versioning-contract.md](package-identity-versioning-contract.md):
  package-name, initial-version, module-namespace, semantic-versioning, and
  compatibility contract for future external package candidates.
- [release-metadata-policy.md](release-metadata-policy.md): source-backed
  license, maintainer, category, synopsis, description, source-repository,
  changelog, release-note, and metadata truth policy for future external
  package candidates.
- [package-validation.md](package-validation.md): local `cabal check` and
  source-distribution validation commands, artifact paths, and no-upload
  boundary for the external package candidates.
- [package-consumer-guide.md](package-consumer-guide.md): source-backed local
  consumer example and preferred package-facing imports for the three workflow
  package candidates.
- [changelog.md](changelog.md): package-candidate changelog material for the
  local `0.1.0.0` workflow package candidates, without package-publication
  approval.
- [release-notes.md](release-notes.md): release-note material for a future
  release-gate review, including package scope, compatibility status,
  validation evidence, and remaining moifold-owned policy.
- [release-candidate-bundle.md](release-candidate-bundle.md): package-by-package
  evidence bundle for the terminal publication gate, without package upload or
  publish/hold choice.
- [publication-gate-decision.md](publication-gate-decision.md): terminal
  publication-gate decision holding the package candidates in candidate state.
- [compatibility-deprecation-policy.md](compatibility-deprecation-policy.md):
  preferred-import guidance, compatibility facade status, and deprecation and
  removal gates for future external package candidates.
- [workflow-spec.md](workflow-spec.md): current `WorkflowSpec`,
  `IndexedWorkflowSpec`, existentials, bridges, laws, and deferred richer
  design ideas.
- [event-log-and-transactions.md](event-log-and-transactions.md): current codec,
  replay, commit, execution metadata, transaction, audit, and daemon projection
  contracts.
- [agent-turn-contract.md](agent-turn-contract.md): current typed agent plans,
  Codex app-server protocol/client/interpreter/transport boundary, retries, and
  agent observation helpers.
- [monad-dsl.md](monad-dsl.md): implemented pure `WorkflowM` and `Transition`
  authoring layer.

Migration background:

- [extraction-plan.md](extraction-plan.md): earlier package-boundary plan,
  migration phases, acceptance criteria, risks, and historical design context.

## Design constraints

- Preserve the current `State -> Event -> Decision -> EffectPlan -> Interpreter` model.
- Keep the event log as durable truth.
- Treat agent output as an observation that must be classified before it becomes accepted workflow state.
- Make effects first-class data so dry-run can render intended mutation.
- Check effects against domain and phase permissions before execution.
- Keep runtime IO behind interpreters and transport adapters.
- Avoid abstracting so far that moifold-specific GitHub assumptions become hidden framework assumptions.

## Non-goals

- Do not treat the standalone local package split as package publication.
- Do not build a generic prompt runner.
- Do not expose `liftIO` in the workflow DSL.
- Do not replace typed states with configurable YAML.
- Do not hide GitHub, Codex, or filesystem behavior behind vague "tool" blobs.
- Do not move moifold issue/PR lifecycle, healthcheck, repair, runtime
  ownership, or compatibility-file policy into reusable framework packages.

## Implemented Layering

The implemented local package-candidate layering is:

```text
agent-workflow-core
  typed workflow kernel, event replay, effect plans, permissions, transactions, audit, daemon projections

agent-workflow-codex
  Codex app-server thread/turn protocol, structured output classification, turn lifecycle helpers, websocket transport

agent-workflow-github
  typed GitHub ids, remote parsers/classifiers, pure GitHub/git command specs

moifold
  issue planning, issue implementation, PR review, merge readiness, compatibility files, daemon/runtime ownership, healthcheck, repair, runbooks
```

The current freeze is about that implemented local package Interface. External
package publication and compatibility facade removal are separate decisions.
