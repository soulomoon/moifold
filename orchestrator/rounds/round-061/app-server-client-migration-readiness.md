# AppServerClient Migration Readiness Evidence

Round: `round-061`
Surface: `CodexWatcher.AppServerClient`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-002`

## Scope

This round is evidence-only. It does not migrate imports, narrow or remove the
facade, add deprecation pragmas, change Cabal exposed modules, change app-server
startup/session behavior, change request rendering or action ordering, change
request-id progression, or approve cleanup.

## Refreshed Import Inventory

Command:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
```

Refreshed result: 28 selected-facade import files/import statements.

Files:

- `test/CliSpec.hs`
- `test/Main.hs`
- `test/AppServerSpec.hs`
- `src/CodexWatcher/DaemonLoop/Types.hs`
- `src/CodexWatcher/RunnerGuard.hs`
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`
- `src/CodexWatcher/Workflow/DocsMigration.hs`
- `src/CodexWatcher/Failure.hs`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/AutomaticLoop/Runner.hs`
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
- `src/CodexWatcher/Cli/Command/Service.hs`
- `src/CodexWatcher/Healthcheck/Types.hs`
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
- `src/CodexWatcher/Cli/Command/Observe.hs`
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
- `src/CodexWatcher/Cli/Types.hs`
- `src/CodexWatcher/Cli/Parser/Common.hs`
- `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`
- `src/CodexWatcher/Turn/Classifier/Common.hs`
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- `src/CodexWatcher/DaemonLoop.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`

Count command:

```sh
rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | wc -l
```

Output: `28`

## Broader Reference Scan

Command:

```sh
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test app
```

Classification summary:

- Observed selected-facade usage: the 28 import files listed above.
- Replacement module exposure: `agent-workflow-codex/agent-workflow-codex.cabal`
  exposes `CodexWatcher.Workflow.Agent.Codex.Client`,
  `CodexWatcher.Workflow.Agent.Codex.Protocol`, and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Current facade exposure: `moifold.cabal` exposes
  `CodexWatcher.AppServerClient`.
- Replacement guidance and policy evidence: docs under
  `docs/agentic-workflow-framework/` and `agent-workflow-codex/README.md`
  describe the adapter modules and keep `CodexWatcher.AppServerClient` as a
  moifold-owned compatibility facade.
- Non-user test assertions: `test/Main.hs` asserts package-boundary and
  compatibility-wrapper shape, including that the standalone Codex package
  excludes `CodexWatcher.AppServerClient` and that the main library does not
  own app-server transport.
- Standalone/example package usage: no selected-facade import was found under
  `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, or
  `examples`; `examples/workflow-package-consumer/app/Main.hs` imports
  `CodexWatcher.Workflow.Agent.Codex.Protocol` directly.
- Downstream/operator sources outside this checkout: unavailable in this
  worktree. This is not removal or deprecation approval.

Package exposure command:

```sh
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal
```

Output summary:

- `moifold.cabal:33`: `CodexWatcher.AppServerClient`
- `agent-workflow-codex/agent-workflow-codex.cabal:50`:
  `CodexWatcher.Workflow.Agent.Codex.Client`
- `agent-workflow-codex/agent-workflow-codex.cabal:52`:
  `CodexWatcher.Workflow.Agent.Codex.Protocol`
- `agent-workflow-codex/agent-workflow-codex.cabal:53`:
  `CodexWatcher.Workflow.Agent.Codex.Transport`

## Replacement Implementation Shape

- `src/CodexWatcher/AppServerClient.hs` remains a compatibility module that
  reexports `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` owns
  `AppServerTurn`, `AppServerIncoming`, `AppServerClientFailure`,
  `JsonRpcError`, response decoding/matching, thread and turn result parsing,
  thread-read materialization fallback markers, `latestTurnById`,
  `threadSystemError`, and failure formatting.
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  owns `AppServerEndpoint`, `AppServerClientOptions`, websocket connection and
  request sending, initialize/initialized session sequencing, response
  timeouts, thread-read fallback send behavior, `startThreadWithEndpoint`,
  `startThreadWithInterpreter`, and `appServerInterpreterFromEndpoint`.
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs`
  owns typed adapter request mapping from agent thread/turn plans to
  `AppServerRequest` values.

## Caller Ownership Grouping

Client/parser ownership: these files consume parsed turn/failure shapes,
response parsers, fallback helpers, or failure formatting and would need
`CodexWatcher.Workflow.Agent.Codex.Client` in a later import migration.

- `test/Main.hs`: `AppServerTurn` classifier fixtures and adapter lifecycle
  assertions.
- `test/AppServerSpec.hs`: decode/match helpers, JSON-RPC error types,
  thread/turn parsers, latest-turn selection, materialization fallback markers,
  system-error detection, and `startThreadWithInterpreter`.
- `src/CodexWatcher/DaemonLoop/Types.hs`: `AppServerClientFailure` and
  `AppServerTurn`.
- `src/CodexWatcher/RunnerGuard.hs`: `AppServerTurn`, parse/read helpers,
  latest-turn selection, materialization-pending marker, system-error
  detection, and failure formatting.
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`: parse thread/turn start
  results and failure formatting.
- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`: `AppServerTurn`
  classifier input.
- `src/CodexWatcher/Workflow/DocsMigration.hs`: `AppServerTurn` classifier
  input.
- `src/CodexWatcher/Failure.hs`: `AppServerClientFailure` and `JsonRpcError`
  classification.
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`: failure formatting after
  typed thread startup.
- `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`: `AppServerTurn`
  classifier input.
- `src/CodexWatcher/Turn/Classifier/Common.hs`: `AppServerTurn` completion
  classification.
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`: `AppServerTurn`
  classifier input.
- `src/CodexWatcher/DaemonLoop.hs`: app-server failure formatting.
- `src/CodexWatcher/Healthcheck.hs`: `parseThreadReadTurns` and failure
  formatting.
- `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`: `AppServerTurn`
  classifier input.
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: `AppServerTurn` in planning
  system-error observation flow.

Transport/session ownership: these files consume endpoint/session/request
sending helpers and would need `CodexWatcher.Workflow.Agent.Codex.Transport` in
a later import migration.

- `test/CliSpec.hs`: constructs `AppServerEndpoint` in CLI parser assertions.
- `test/AppServerSpec.hs`: `appServerRequestSession` and
  `startThreadWithInterpreter`.
- `test/Main.hs`: constructs `AppServerEndpoint` in dry-run/guard assertions.
- `src/CodexWatcher/RunnerGuard.hs`: `AppServerEndpoint`,
  `defaultAppServerClientOptions`, `sendOneAppServerRequest`, and
  `startThreadWithEndpoint`.
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`: `AppServerEndpoint`
  product handoff plumbing.
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`:
  `AppServerClientOptions`, default options, and request sending.
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`:
  `AppServerEndpoint` child-launch plumbing.
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`: `AppServerEndpoint`,
  `startThreadWithEndpoint`, default options, and failure formatting in child
  launch preparation.
- `src/CodexWatcher/AutomaticLoop/Runner.hs`:
  `appServerInterpreterFromEndpoint`, default options, and `AppServerEndpoint`.
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: `AppServerEndpoint`,
  `startThreadWithEndpoint`, default options, and failure formatting for PR
  review watcher launch.
- `src/CodexWatcher/Cli/Command/Service.hs`: `AppServerEndpoint`.
- `src/CodexWatcher/Healthcheck/Types.hs`: optional `AppServerEndpoint`.
- `src/CodexWatcher/Cli/Command/Observe.hs`: `appServerInterpreterFromEndpoint`
  and default options.
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: `AppServerEndpoint`.
- `src/CodexWatcher/Cli/Types.hs`: CLI records carrying `AppServerEndpoint`.
- `src/CodexWatcher/Cli/Parser/Common.hs`: required/optional endpoint parser.
- `src/CodexWatcher/Healthcheck.hs`: `sendOneAppServerRequest` and default
  options for thread inspection.

Protocol/request ownership: current selected-facade callers also use request
builders from `CodexWatcher.AppServerProtocol` or typed request mapping from
`CodexWatcher.Workflow.Agent.Codex.Protocol` in these places. A later migration
must preserve those existing imports and must not change request rendering.

- `test/AppServerSpec.hs`: JSON-RPC request shape assertions for initialize,
  initialized, thread/start, turn/start, thread/read, and interrupt.
- `test/Main.hs`: direct `CodexWatcher.AppServerProtocol` import plus
  `CodexWatcher.Workflow.Agent.Codex.Protocol qualified as
  WorkflowAgentCodexProtocol` for typed adapter parity.
- `src/CodexWatcher/RunnerGuard.hs`: sends `turnStartRequest` and
  `threadReadRequest`.
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`: sends thread/start,
  turn/start, and thread/read requests.
- `src/CodexWatcher/Healthcheck.hs`: sends `threadReadRequest`.
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`: builds typed thread
  plans from `ThreadStartOptions` through `WorkflowAgentCodex`.

Product-policy ownership: these moifold modules may continue to consume the
facade until a later selected round authorizes production import migration.

- Daemon and lifecycle policy: `src/CodexWatcher/DaemonLoop.hs`,
  `src/CodexWatcher/DaemonLoop/Types.hs`,
  `src/CodexWatcher/AutomaticLoop/Runner.hs`,
  `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`,
  `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`, and
  `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`.
- CLI and operator flows: `src/CodexWatcher/Cli/Types.hs`,
  `src/CodexWatcher/Cli/Parser/Common.hs`,
  `src/CodexWatcher/Cli/Command/AppServerProbe.hs`,
  `src/CodexWatcher/Cli/Command/Observe.hs`,
  `src/CodexWatcher/Cli/Command/IssueFanout.hs`,
  `src/CodexWatcher/Cli/Command/RunnerGuard.hs`, and
  `src/CodexWatcher/Cli/Command/Service.hs`.
- Healthcheck and runner guard: `src/CodexWatcher/Healthcheck.hs`,
  `src/CodexWatcher/Healthcheck/Types.hs`, and
  `src/CodexWatcher/RunnerGuard.hs`.
- Domain classifiers and workflow policy:
  `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`,
  `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`,
  `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`,
  `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`,
  `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`,
  `src/CodexWatcher/Turn/Classifier/Common.hs`,
  `src/CodexWatcher/Workflow/DocsMigration.hs`, and
  `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`.
- Test evidence: `test/AppServerSpec.hs`, `test/CliSpec.hs`, and
  `test/Main.hs`.

## Behavior Coverage Readback

`test/AppServerSpec.hs` covers the current app-server protocol/client behavior:

- JSON-RPC request shape for `initialize` and `initialized`.
- `thread/start`, `turn/start`, `thread/read`, and `turn/interrupt` request
  field behavior.
- initialize/session behavior through `appServerRequestSession`.
- response matching, notification skipping, mismatched response ids, JSON-RPC
  errors, unsupported JSON-RPC versions, and decode failures.
- thread-read parsing, nested thread-read parsing, latest-turn selection,
  structured-output extraction, and system-error status detection.
- materialization fallback from `thread/read includeTurns=true` to
  `includeTurns=false` plus synthetic pending marker readback.
- `parseTurnStartTurnId`, `parseThreadStartThreadId`, malformed result
  rejection, and `startThreadWithInterpreter`.

`test/Main.hs` registers the AppServerSpec properties and adds package-boundary
and typed-adapter coverage:

- `workflowMoifoldCabalLibraryDoesNotReexportAdapters` asserts that the moifold
  main library does not reexport adapter modules or own app-server transport,
  while the compatibility facade imports the client and transport modules.
- `workflowAgentCodexStartRequestsMatchCompiledEffects` asserts typed
  `agentTurnStartRequest` parity with compiled app-server effects and
  request-id progression.
- `workflowAgentCodexStartsThreadsThroughTypedAdapter` asserts typed
  thread/start rendering, parsing, and interpreter-backed startup.
- `workflowAgentCodexParsesTurnLifecycle` asserts typed turn/start,
  thread/read, missing-turn, and system-error parsing behavior.
- `prop_effectInterpreterTwoTurnStartsUseMonotonicRequestIds` protects
  app-server request-id progression for consecutive turn starts.
- `prop_actionExecutorDryRunPreservesActionOrder` protects dry-run action
  ordering and non-executing dry-run reports.
- Workflow metadata tests protect legacy action order, request-id progression,
  action partition ordering, and dry-run parity with legacy reports.

## Readiness and Blockers

Evidence-supported readiness:

- Replacement modules are exposed from `agent-workflow-codex`.
- The moifold compatibility facade still exists and still reexports the client
  and transport modules.
- Current tests cover app-server request shape, client parsing, transport
  session behavior, typed adapter parity, dry-run ordering, and request-id
  progression.
- No selected-facade imports were found in standalone workflow package
  candidates or examples in this checkout.

Remaining blockers before any production migration or cleanup approval:

- Each of the 28 selected-facade imports still needs a focused import rewrite in
  a later selected round, with per-caller replacement modules chosen from the
  ownership grouping above.
- After rewrites, focused behavior parity must be read back around app-server
  startup/session behavior, request rendering, action ordering, request-id
  progression, healthcheck, runner guard, CLI probe, fanout/launch paths, and
  turn classifiers.
- Public/downstream/operator evidence outside this checkout remains
  unavailable; absence here is not removal approval.
- Facade narrowing, deprecation pragmas, Cabal exposure changes, and removal
  remain blocked on a later policy/removal round and reviewer approval.

Conclusion: migration readiness is partially established for replacement-module
exposure and local behavior coverage, but production import migration and any
facade cleanup remain blocked and unapproved.
