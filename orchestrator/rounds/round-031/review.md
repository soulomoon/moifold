### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported all targets up to date.
- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite passed, including the daemon core projection checks and the strengthened workflow-core package-boundary scan.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.
- Command: `rg -n "CodexWatcher\\.(Daemon|DaemonLoop|ChildDaemon|Healthcheck|EventLogRepair|RunnerGuard|WatcherRuntimeStatus|Supervisor)|Data\\.Aeson|System\\.(Directory|FilePath|Process)|WatcherEvent|SomeWatcherState|DaemonOptions|DaemonTickResult|DaemonObservedTickResult|DaemonObservedTransactionFailure|runtime-owner|pid-file|pidFile|\\.lock|readFile|writeFile|createDirectory|\\bIO\\b|\\bFilePath\\b" agent-workflow-core/src`
  Result: pass. Matches were limited to the generic daemon core identifiers `WorkflowDaemonTickResult`, `WorkflowObservedDaemonTickResult`, and related helper names; no concrete moifold daemon/runtime ownership imports, concrete state/event types, filesystem/process APIs, PID/lock/runtime-owner text, `IO`, or `FilePath` were found in core.
- Command: `sed -n '/^library agent-workflow-core/,/^library /p' moifold.cabal | sed -n '1,180p'`
  Result: pass. `agent-workflow-core` still exposes `CodexWatcher.Workflow.Daemon.Core` and depends only on `base`, `bytestring`, and `text`.

### Plan Compliance
- Inspect candidate daemon boundary modules: met. The integrated diff touches `agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs`, `src/CodexWatcher/Daemon.hs`, and `test/Main.hs`; `DocsMigration` is exercised through existing wrapper helpers rather than moved.
- Add justified generic failure projection: met. `WorkflowObservedDaemonTickFailure` and `workflowObservedDaemonTickFailure` project only generic transaction failure fields: stage, reason, replay/planned/final-state evidence, committed events, compiled effects, reports, and audit.
- Keep moifold compatibility/domain result shape: met. `DaemonObservedTransactionFailure` remains in `src/CodexWatcher/Daemon.hs`; the moifold wrapper now reads from the generic projection but continues to own the public compatibility/domain fields.
- Do not move concrete daemon ownership into core: met. `ChildDaemon`, healthcheck, repair, PID/lock/runtime-owner handling, process execution, filesystem writes, compatibility writes, concrete `WatcherEvent`, `SomeWatcherState`, and daemon options remain outside `agent-workflow-core`.
- Add focused success projection tests for moifold and DocsMigration: met. `workflowDaemonCoreProjectsMoifoldAndDocsMigrationResults` now verifies pre/post report partitioning through the audit for both paths.
- Add focused failure projection tests: met. `workflowDaemonCoreProjectsObservedFailureBoundary` verifies failure stage, committed-event boundary, final state, report partitioning, failure classification, and retry/stop recommendation.
- Strengthen recursive source scans: met. `workflowCoreCabalSublibraryKeepsPackageBoundary` now rejects additional concrete daemon ownership imports/tokens and concrete ownership text across `agent-workflow-core/src`.
- Confirm cabal package boundary: met. Manual inspection and the test scan confirm `agent-workflow-core` keeps the approved dependency set and exposes only the generic core daemon module.

### Decision
**APPROVED**

### Evidence
The core projection remains ownership-neutral: `CodexWatcher.Workflow.Daemon.Core` imports only `Workflow.Audit`, `Workflow.Spec`, and `Workflow.Transaction.Core`, and the new failure type is parameterized over `spec`, `compiled`, `report`, and `failure`.

Concrete ownership remains in moifold. `src/CodexWatcher/Daemon.hs` still owns `DaemonObservedTransactionFailure`, `DaemonOptions`, compatibility writes, concrete daemon wrappers, event-log behavior, runtime/filesystem/process behavior, and conversion from the generic projection back into the moifold result shape.

Recursive boundary enforcement was strengthened and passed under `watcher-core-test`; the direct review scan also found no forbidden concrete ownership imports or runtime/filesystem tokens in `agent-workflow-core/src`.
