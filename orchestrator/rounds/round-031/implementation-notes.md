### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs`: added `WorkflowObservedDaemonTickFailure` and `workflowObservedDaemonTickFailure`, a generic projection from `WorkflowObservedTransactionFailure` that carries only transaction stage, reason, replay/planned/final-state evidence, committed events, compiled effects, reports, and audit.
- `src/CodexWatcher/Daemon.hs`: routed the public moifold `DaemonObservedTransactionFailure` wrapper through the new generic daemon failure projection while keeping compatibility/domain fields and concrete daemon ownership in moifold.
- `test/Main.hs`: strengthened daemon core projection assertions for moifold and DocsMigration success ticks, added retryable and committed failure projection coverage, and expanded recursive `agent-workflow-core` boundary scans for daemon/runtime ownership imports and tokens.

### Tests
- `test/Main.hs`: `workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults` now checks pre/post report partitioning through the audit for both moifold and DocsMigration daemon result wrappers.
- `test/Main.hs`: `workflowDaemonCoreProjectsObservedFailureBoundary` verifies the generic daemon failure projection preserves failure stage, committed-event boundary, final state, reports, audit failure classification, and retry/stop recommendation.
- `test/Main.hs`: `workflowCoreCabalSublibraryKeepsPackageBoundary` now rejects concrete daemon ownership imports and tokens such as `ChildDaemon`, healthcheck, repair, PID/lock/runtime-owner strings, concrete daemon result wrappers, concrete event/state types, filesystem/process APIs, and unapproved core dependencies.

### Notes
This round added a generic failure projection. Production concrete ownership stayed in moifold: `DaemonOptions`, compatibility writes, event-log files, concrete `WatcherEvent`/`SomeWatcherState` wrappers, runtime/process/filesystem behavior, child-daemon lifecycle, healthcheck, and repair remain outside `agent-workflow-core`.

Validation results:
- `cabal test watcher-core-test`: PASS.
- `cabal build all`: PASS.
- `git diff --check`: PASS.
- `git diff --cached --check`: not run because no files were staged.
