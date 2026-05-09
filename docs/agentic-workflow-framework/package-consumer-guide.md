# Package Consumer Guide

This guide shows how to consume the local workflow package candidates without
depending on moifold product code. It is source-backed by the buildable example
in [`examples/workflow-package-consumer`](../../examples/workflow-package-consumer).

Run the example with:

```sh
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
```

The example owns its own `cabal.project`, references the three package
candidates by local path, and is not part of the root package set.

## Preferred imports

Use `agent-workflow-core` for generic workflow contracts and pure planning:

- `CodexWatcher.Workflow.Spec`
- `CodexWatcher.Workflow.DSL`
- `CodexWatcher.Workflow.Codec`
- `CodexWatcher.Workflow.EventLog.Core`
- `CodexWatcher.Workflow.Execution.Core`
- `CodexWatcher.Workflow.Permission.Core`
- `CodexWatcher.Workflow.Transaction.Core`

Use `agent-workflow-codex` for typed Codex app-server protocol and adapter
values:

- `CodexWatcher.AppServerProtocol`
- `CodexWatcher.Workflow.Agent`
- `CodexWatcher.Workflow.Agent.Ids`
- `CodexWatcher.Workflow.Agent.Types`
- `CodexWatcher.Workflow.Agent.Codex.Protocol`
- `CodexWatcher.Workflow.Agent.Codex.Client`
- `CodexWatcher.Workflow.Agent.Codex.Interpreter`
- `CodexWatcher.Workflow.Agent.Codex.Transport`
- `CodexWatcher.Workflow.Observation.Agent`

Use `agent-workflow-github` for typed GitHub identifiers, pure remote parsers,
and pure command specs:

- `CodexWatcher.Workflow.GitHub.Ids`
- `CodexWatcher.Workflow.GitHub.Remote`
- `CodexWatcher.Workflow.GitHub.Command`

## Consumer boundary

Reusable package consumers provide their own workflow state, accepted event
schema, observation classifiers, prompt policy, runtime ownership, filesystem
writes, command execution, healthcheck, repair, compatibility files, and
release decisions.

The packages provide typed contracts and deterministic values that a product
can inspect, dry-run, validate, or interpret. They do not replace the product's
event log, lifecycle policy, app-server process supervision, GitHub command
execution policy, or compatibility promises.

## Local project pattern

A consumer project can keep the workflow packages independent from the root
moifold project by using local package paths:

```cabal
packages:
  .
  ../../agent-workflow-core
  ../../agent-workflow-codex
  ../../agent-workflow-github
```

Depend on the package candidates directly, for example:

```cabal
build-depends:
  agent-workflow-core >=0.1 && <0.2,
  agent-workflow-codex >=0.1 && <0.2,
  agent-workflow-github >=0.1 && <0.2
```

Do not import moifold compatibility facades when writing package-consumer
examples. Prefer the exposed package modules listed above.
