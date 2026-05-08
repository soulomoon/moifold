### Goal

Prove and, only where the current code justifies it, tighten the ownership-neutral daemon tick/result boundary in `agent-workflow-core` while leaving concrete child-daemon lifecycle, runtime ownership, filesystem writes, process execution, healthcheck, repair, and concrete moifold event/state policy in the main moifold library.

### Approach

Treat the existing `CodexWatcher.Workflow.Daemon.Core` module as the candidate generic boundary. It already contains ownership-neutral success tick projections used by both moifold daemon ticks and `DocsMigration`; the round should not broaden into `ChildDaemon`, daemon-loop supervision, PID/lock handling, runtime-owner files, healthcheck, repair, or concrete `WatcherEvent`/`SomeWatcherState` ownership.

The bounded implementation path is:

- Keep core types parameterized by `WorkflowSpec`, compiled effect plan, action report, and failure classification types.
- If inspection confirms the remaining duplicated surface is the moifold-specific `DaemonObservedTransactionFailure` projection, add a small generic daemon failure projection in `Workflow.Daemon.Core` from `WorkflowObservedTransactionFailure`; otherwise leave production core shape unchanged and strengthen tests/source scans around the existing result projection.
- Keep moifold and `DocsMigration` wrappers as compatibility-facing domain types; they may project to/from the generic core surface, but must continue to own compatibility writes, event-log files, concrete event constructors, concrete state snapshots, and interpreter/runtime behavior.
- Strengthen recursive boundary scans so `agent-workflow-core` cannot import or mention the forbidden daemon/runtime ownership modules and concrete lifecycle tokens named by the selection and project contract.

### Steps

1. Inspect `agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs`, `src/CodexWatcher/Daemon.hs`, and `src/CodexWatcher/Workflow/DocsMigration.hs` to identify the exact duplicated daemon result/failure projection that is generic across moifold and DocsMigration.
2. If the only justified extraction is success-result projection, keep production code unchanged and add focused tests that exercise both `workflowDaemonTickResult` and `workflowObservedDaemonTickResult` with moifold and DocsMigration paths.
3. If the duplicated failure projection is justified, add a small `WorkflowObservedDaemonTickFailure` type and projection helper to `Workflow.Daemon.Core` from `WorkflowObservedTransactionFailure`, carrying only generic replay/planned/final-state/committed-events/compiled-effects/report/audit/failure-stage fields. Do not include daemon options, compatibility writes, file paths, PID/lock/runtime-owner data, process execution, concrete events, or concrete state wrappers.
4. Wire moifold failure conversion in `src/CodexWatcher/Daemon.hs` through the generic failure projection while keeping `DaemonObservedTransactionFailure` as the public compatibility/domain result shape.
5. Add or tighten `watcher-core-test` assertions in `test/Main.hs` proving the core daemon surface projects moifold and DocsMigration success ticks identically, preserves pre/post report partitioning through the audit, and, if a failure projection was added, preserves failure stage, committed-event boundary, retry/stop audit recommendation, and classification without importing concrete daemon ownership into core.
6. Extend the existing recursive package-boundary scan in `test/Main.hs` so `agent-workflow-core` rejects imports or identifier tokens for `ChildDaemon`, healthcheck, repair, PID/pid-file/lock/runtime-owner ownership, filesystem/process execution, `WatcherEvent`, `SomeWatcherState`, `DaemonOptions`, `DaemonTickResult`, `DaemonObservedTickResult`, concrete moifold lifecycle policy, and concrete event/state ownership.
7. Confirm `moifold.cabal` still exposes only the generic core daemon module from `agent-workflow-core`, keeps the approved core dependency set, and does not add runtime, filesystem, process, Aeson, Codex adapter, GitHub adapter, or main-library dependencies to core.
8. Record implementation notes explaining whether this round added a failure projection or intentionally left the production core surface unchanged, with the source-scan evidence for concrete ownership staying in moifold.

### Verification

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any files are staged during the round

The focused review checks should include the updated `workflowCoreCabalSublibraryKeepsPackageBoundary` source scan, the daemon core projection assertions, and a direct inspection that `agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs` imports only generic workflow core modules.
