### Goal

Stabilize the `agent-workflow-codex` adapter API surface so typed agent roles, turn references, app-server protocol/client/transport helpers, and classifier-facing observation helpers are explicit, tested, and kept free of moifold issue/PR lifecycle policy.

### Approach

Treat `agent-workflow-codex` as the owner of Codex app-server JSON-RPC shapes, request rendering, response parsing, typed agent role metadata, typed `TurnRef` lifecycle helpers, transport/session helpers, and generic classified-agent observation plumbing. Keep the main library as the owner of concrete moifold issue planning, issue implementation, PR-review lifecycle policy, runtime defaults, effect interpretation, filesystem/process behavior, daemon ownership, healthcheck, repair, and GitHub command policy.

The likely production changes should be additive API clarification and small wrapper/helper tightening, not a broad module move. Preserve the existing `CodexWatcher.AppServerClient` compatibility facade unless inspection proves a tested removal path, which this round is not selected to do. If inspection shows the current API is already shaped correctly, prefer focused tests and boundary-scan hardening over churn.

### Steps

1. Inspect `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Types.hs`, `Workflow/Agent.hs`, `Workflow/Agent/Ids.hs`, `Workflow/Agent/Codex.hs`, `Workflow/Agent/Codex/Protocol.hs`, `Workflow/Agent/Codex/Client.hs`, `Workflow/Agent/Codex/Transport.hs`, `Workflow/Agent/Codex/Interpreter.hs`, `Workflow/Observation/Agent.hs`, and `agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs` for unstable or duplicated public API seams around role ids, retry metadata, side-effect metadata, `TurnRef`, request construction, response parsing, materialization fallback, and transport sessions.
2. Inspect the current main-library compatibility and integration callers, especially `src/CodexWatcher/AppServerClient.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`, `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`, and `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`, to identify adapter calls that should go through the typed Codex adapter surface without moving moifold lifecycle policy into `agent-workflow-codex`.
3. Keep or tighten the public exported module list for `library agent-workflow-codex` in `moifold.cabal`. The adapter may depend on `aeson`, `base`, `bytestring`, `text`, `websockets`, and `moifold:agent-workflow-core`; do not add main-library, GitHub, daemon/runtime, filesystem/process, CLI, healthcheck, repair, or moifold domain dependencies.
4. Add or refine focused adapter tests in `test/AppServerSpec.hs` and/or `test/Main.hs` for every touched surface. Required coverage for touched areas includes typed thread/turn start request parity, `TurnRef` read/interrupt request rendering, nested thread-read and latest-turn parsing, malformed turn/thread start responses, JSON-RPC error/id mismatch handling, materialization fallback marking, system-error detection, retry/side-effect metadata, and observation/classification mapping.
5. If classifier-facing role APIs are touched, strengthen tests around complete, incomplete, blocked, malformed, problems, and clean outputs without weakening structured-output requirements or classifier evidence. Existing checks in `prop_turnClassifierPrefersStructuredOutputs`, `prop_turnClassifierBlocksMissingOutputs`, `workflowPrReviewAgentRolesClassifyOutputs`, `workflowAgentObservationKernelMatchesPrReviewClassifiers`, and `workflowPlanObservationLawHoldsForPrReviewAgentObservation` are the anchors to extend.
6. Harden the recursive `workflowCodexCabalSublibraryKeepsPackageBoundary` scan so `agent-workflow-codex` rejects imports or source mentions of moifold issue/PR lifecycle modules and ownership tokens such as `CodexWatcher.Domain.`, `CodexWatcher.StateMachine`, `CodexWatcher.Daemon`, `CodexWatcher.DaemonLoop`, `CodexWatcher.ChildDaemon`, `CodexWatcher.Healthcheck`, `CodexWatcher.EventLog`, `CodexWatcher.EventLogRepair`, `CodexWatcher.Effects`, `CodexWatcher.Runtime.`, `CodexWatcher.Workflow.Moifold.`, GitHub adapter/policy modules, concrete `WatcherEvent`, concrete `SomeWatcherState`, and compatibility/runtime-owner files.
7. Confirm the compatibility facade `src/CodexWatcher/AppServerClient.hs` remains thin and only reexports the Codex client/transport modules, and that existing callers continue to build through that facade or the typed adapter modules as appropriate.
8. Record implementation notes explaining whether production API code changed or the stabilization was test/source-scan hardening only, and list the exact adapter surfaces and boundary imports reviewed.

### Verification

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any files are staged during the round

Because `watcher-core-test` is a custom QuickCheck-style executable, focused validation is by direct review of the named assertions rather than matcher-filtered invocations. Review should inspect the app-server properties in `test/AppServerSpec.hs`, the workflow agent/Codex/classifier assertions in `test/Main.hs`, `moifold.cabal`, `src/CodexWatcher/AppServerClient.hs`, and the recursive boundary scan to confirm app-server protocol and transport ownership live in `agent-workflow-codex` while concrete moifold issue/PR lifecycle policy remains in the main library.
