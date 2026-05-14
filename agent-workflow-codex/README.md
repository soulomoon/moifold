# agent-workflow-codex

`agent-workflow-codex` is the reusable Codex app-server adapter package
candidate. It owns typed request construction, app-server response parsing,
websocket transport helpers, typed agent plans, turn references, retry
metadata, role metadata, and the bridge from classified app-server turns into
workflow observations.

The package is not moifold's prompt system, app-server process supervisor, issue
or PR lifecycle engine, compatibility policy, structured-output migration
policy, healthcheck, repair surface, or publication decision. Those remain
moifold-owned product responsibilities.

This is a local external-package candidate in this repository. The README is
documentation for the implemented package surface, not a package upload or
public stability claim.

## Architecture

The public modules are grouped by ownership:

- `CodexWatcher.AppServerProtocol`: deterministic JSON-RPC request
  construction for initialize, thread start, thread naming, thread read, turn
  start, turn interrupt, and collaboration mode data.
- `CodexWatcher.Workflow.Agent.Ids`: typed request, thread, and turn
  identifiers plus request-id progression.
- `CodexWatcher.Workflow.Agent.Types`: typed role identifiers, thread and turn
  plans, turn starts, turn references, retry metadata, and side-effect-scope
  metadata. Concrete product role marker types remain product-owned.
- `CodexWatcher.Workflow.Agent`: deterministic role classification over
  app-server turns and retry-reason classification for reusable agent adapters.
- `CodexWatcher.Workflow.Agent.Codex.Protocol`: mapping typed agent thread and
  turn plans into app-server protocol requests.
- `CodexWatcher.Workflow.Agent.Codex.Client`: app-server response parsing,
  turn records, thread and turn ids, system-error status, thread-read
  materialization fallback, and client failure formatting.
- `CodexWatcher.Workflow.Agent.Codex.Interpreter`: the minimal request-sending
  interpreter record used by adapter helpers.
- `CodexWatcher.Workflow.Agent.Codex.Transport`: websocket endpoint, options,
  session, timeout, initialized-request, fallback, and endpoint-backed
  interpreter helpers.
- `CodexWatcher.Workflow.Agent.Codex`: parse, start, read, interrupt, and
  cached-interpreter helpers that compose protocol, client, interpreter, and
  transport surfaces.
- `CodexWatcher.Workflow.Observation.Agent`: the observation bridge from raw
  app-server turns to classified agent output, workflow observations, and
  planned transitions.

## Guarantees

The Codex adapter keeps request construction deterministic, gives thread and
turn ids typed boundaries, carries role and retry metadata explicitly,
classifies app-server turns before they become workflow observations, parses
responses into typed results or failures, owns websocket transport helpers, and
keeps observation planning explicit.

It does not decide when an app-server process is started, which prompt a role
uses, which structured output schema is accepted, whether a turn result becomes
durable event truth, how issue or PR lifecycle state advances, when
compatibility facades are removed, or whether a package crosses an external
release gate.

## Evidence

- [Agent turn contract](../docs/agentic-workflow-framework/agent-turn-contract.md)
- [Implemented API freeze](../docs/agentic-workflow-framework/implemented-api-freeze.md)
- [Compatibility and deprecation policy](../docs/agentic-workflow-framework/compatibility-deprecation-policy.md)
- [Package extraction readiness](../docs/agentic-workflow-framework/package-extraction-readiness.md)
- [Package validation](../docs/agentic-workflow-framework/package-validation.md)
- [Package consumer guide](../docs/agentic-workflow-framework/package-consumer-guide.md)
- [Package candidate changelog](../docs/agentic-workflow-framework/changelog.md)
- [Package candidate release notes](../docs/agentic-workflow-framework/release-notes.md)
- [Buildable consumer example](../examples/workflow-package-consumer)
