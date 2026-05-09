# workflow-package-consumer

This is a local consumer example for the `agent-workflow-core`,
`agent-workflow-codex`, and `agent-workflow-github` package candidates. It is
not a publication claim, release approval, or public stability guarantee.

Run it from the repository root with:

```sh
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
```

The example has its own `cabal.project` and is intentionally not listed in the
root project. It depends on the three workflow packages through local package
paths and does not depend on `moifold`.

## What it demonstrates

- `agent-workflow-core`: a tiny `WorkflowSpec`, observation planning with
  `workflowPlanObservation`, and pure plan construction with `WorkflowM` and
  `advance`.
- `agent-workflow-codex`: typed thread and turn plans translated into
  deterministic app-server protocol request values.
- `agent-workflow-github`: typed repository, PR, and branch identifiers used to
  construct pure `gh` and `git` command specs.

## What it leaves to products

The example does not start an app-server, execute commands, define prompt
policy, own event schemas, write files, run healthcheck or repair, manage
compatibility files, or decide package release readiness. Those responsibilities
belong to a concrete product such as moifold.
