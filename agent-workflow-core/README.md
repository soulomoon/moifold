# agent-workflow-core

`agent-workflow-core` is the reusable workflow-kernel package candidate for
typed agentic control planes. Its thesis is:

```text
State -> Event -> Decision -> EffectPlan -> Interpreter
```

The package exposes generic contracts for workflow specs, replay, event codecs,
effect plans, permission checks, transaction ordering, audit records, daemon
projections, and reusable failure classification. It deliberately does not own
moifold's concrete issue or PR lifecycle, event JSON schema, compatibility
files, runtime ownership, healthcheck, repair, prompt policy, or publication
decisions.

This is a local external-package candidate in this repository. The README is
documentation for the implemented package surface, not a package upload or
public stability claim.

## Architecture

The public modules are grouped by ownership:

- `CodexWatcher.Workflow.Spec`: the unindexed workflow contract, planned
  transitions, observation planning, replay hooks, permission hooks, terminal
  checks, and labels.
- `CodexWatcher.Workflow.Indexed.Spec`: the current indexed compatibility
  surface and bridge to the unindexed spec; it is not a richer indexed redesign.
- `CodexWatcher.Workflow.DSL`: the pure `WorkflowM` and `Transition` authoring
  layer for building inspectable effect plans without `liftIO`.
- `CodexWatcher.Workflow.Codec`: generic codec contracts, event type labels,
  schema labels, metadata labels, decode errors, round-trip checks, and encoded
  type-label checks without owning a concrete Aeson schema.
- `CodexWatcher.Workflow.EventLog.Core`: pure replay helpers, fixture
  contracts, transition failures, replay failures, and detailed replay
  summaries.
- `CodexWatcher.Workflow.EventLog.File.Core`: generic line-numbered nonblank
  event-log decoding; concrete files remain workflow-owned.
- `CodexWatcher.Workflow.EventLog.Commit.Core`: the event commit abstraction
  that encodes once and appends through a caller-supplied committer.
- `CodexWatcher.Workflow.Execution.Core`: effect metadata, compiled plans,
  dry-run traversal, execution traversal, commit-order partitioning, and
  checked action execution.
- `CodexWatcher.Workflow.Permission.Core`: reusable permission policies,
  per-effect permission reports, validation errors, and formatted denials.
- `CodexWatcher.Workflow.Transaction.Core`: observed and prepared transaction
  runners with replay, observation, validation, pre-commit actions, one event
  commit, post-commit replay, callbacks, and stage-aware failures.
- `CodexWatcher.Workflow.Audit`: operator-facing audit values for dry-run,
  success, and failure outcomes.
- `CodexWatcher.Workflow.Daemon.Core`: daemon tick projections over transaction
  results and failures, not a daemon loop or process owner.
- `CodexWatcher.Workflow.Failure`: reusable failure classes and text-based
  retry classification.

## Guarantees

The core package keeps replay pure, keeps observations explicit, keeps effects
as inspectable data before interpretation, validates permissions before
transaction execution, commits events through a clear boundary, reports
transaction failures by stage, and provides audit and daemon projection values
for operator-facing workflows.

Concrete event schemas, old-log compatibility, compatibility snapshots,
filesystem writes, process execution, daemon leases, app-server transport,
GitHub commands, healthcheck, repair, and lifecycle policy are outside this
package. A concrete product such as moifold supplies those policies through its
own workflow spec, codecs, interpreters, and runtime.

## Evidence

- [Workflow spec](../docs/agentic-workflow-framework/workflow-spec.md)
- [Event log and transactions](../docs/agentic-workflow-framework/event-log-and-transactions.md)
- [Monad DSL](../docs/agentic-workflow-framework/monad-dsl.md)
- [Implemented API freeze](../docs/agentic-workflow-framework/implemented-api-freeze.md)
- [Package extraction readiness](../docs/agentic-workflow-framework/package-extraction-readiness.md)
- [Package validation](../docs/agentic-workflow-framework/package-validation.md)
- [Package consumer guide](../docs/agentic-workflow-framework/package-consumer-guide.md)
- [Package candidate changelog](../docs/agentic-workflow-framework/changelog.md)
- [Package candidate release notes](../docs/agentic-workflow-framework/release-notes.md)
- [Buildable consumer example](../examples/workflow-package-consumer)
