### Goal
Extract the reusable checked-action traversal and failure accumulation shape from the moifold execution facade into `agent-workflow-core`, while preserving the existing moifold-facing `ActionExecutor`, `ActionExecutionReport`, `CommandReport`, failure classifiers, daemon result shapes, event JSON schemas, golden logs, dry-run output, and action ordering.

### Approach
`agent-workflow-core` should own only a generic traversal contract: run actions in list order, stop at the first classified failure, preserve prior successful reports in original order, preserve the failed report, and return all reports on success. The core API must be parameterized over action, report, and failure-reason types and must not import moifold lifecycle, runtime, command, Codex, GitHub, Aeson, or concrete executor modules.

The moifold library should keep the compatibility surface in `src/CodexWatcher/Workflow/Execution.hs`: `WorkflowActionFailure`, `executeWorkflowCheckedActions`, `workflowActionFailureReports`, and the concrete failure classifier remain there. That facade should delegate to the new core traversal and map the generic failure back into the existing `WorkflowActionFailure` record so callers in `src/CodexWatcher/Daemon.hs` continue to see the same `DaemonActionFailed` and `DaemonActionResultInvalid` behavior.

This round is sequential. The core extraction, facade adapter, daemon behavior, and focused tests all touch the same compatibility path, and the roadmap marks `item-001-checked-action-failure-core` as parallel safe: no.

### Steps
1. In `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`, add and export a generic checked-action failure type, for example `WorkflowCheckedActionFailureOf action report reason`, with fields for failed action, failed report, prior reports, and failure reason.
2. In the same core module, add and export `executeWorkflowCheckedActionsOf` with this shape: it accepts an action runner `(action -> m report)`, a classifier `(action -> report -> Maybe reason)`, and `[action]`, then returns `m (Either (WorkflowCheckedActionFailureOf action report reason) [report])`.
3. Also add a core helper equivalent to the moifold report projection, for example `workflowCheckedActionFailureReports`, returning prior reports followed by the failed report. Keep the traversal strictly left-to-right and do not partition, sort, batch, or skip actions.
4. In `src/CodexWatcher/Workflow/Execution.hs`, keep `WorkflowActionFailure` and all existing exported moifold names. Replace the local recursive implementation of `executeWorkflowCheckedActions` with a thin adapter over `executeWorkflowCheckedActionsOf`, using `executePlannedAction executor ExecuteActions . workflowPlannedAction` as the runner and the existing hard-failure classifier as the concrete classifier.
5. Keep `CommandReport`, `FailureClassification`, `HardFailure`, `classifyExternalFailureText`, and `commandReportFromExecution` in the moifold facade. Do not move `ActionExecutor`, `ActionExecutionReport`, `PlannedAction`, `WorkflowPlannedAction`, `CommandReport`, or daemon failure conversion into `agent-workflow-core`.
6. Leave `src/CodexWatcher/Daemon.hs` behavior-compatible. `runDaemonTickWithEvents` and `executeMoifoldWorkflowActions` should continue to call `executeWorkflowCheckedActions`, and `daemonFailureFromWorkflowActionFailure` should continue to map command failures to `DaemonActionFailed` with the original `CommandReport`.
7. Do not change dry-run paths. `dryRunWorkflowCompiledEffectPlan`, observed transaction dry-runs, `dryRunWorkflowAction`, and CLI dry-run output must remain byte-for-byte compatible unless an existing test fixture proves an intended change, which this roadmap item does not authorize.
8. Extend focused tests in `test/Main.hs`:
   - Add a core-level test, e.g. `workflowExecutionCoreCheckedActionsStopsOnFirstFailure`, using simple test action/report values to prove left-to-right execution, first-failure short-circuiting, prior-report ordering, failed-report capture, and success-report ordering without moifold types.
   - Keep or extend `workflowExecutionCheckedActionsStopsOnHardFailure` to prove the moifold facade still stops after the failing `GitPush`, still does not execute the following `CreateIssue`, still reports a non-ok `CommandReport`, and still classifies the failure as `PolicyViolation`.
   - Keep `observedDaemonTickExecuteCommandFailureDoesNotAppendEvent` passing to prove daemon result shape, no event append on pre-commit action failure, and unchanged transaction failure stage.
9. Extend the existing package-boundary assertion in `workflowCoreCabalSublibraryKeepsPackageBoundary` so `agent-workflow-core` source rejects accidental concrete imports or type mentions for `CodexWatcher.ActionExecutor`, `CodexWatcher.Runtime.Command`, `CodexWatcher.Failure`, `ActionExecutionReport`, `CommandReport`, and `PlannedAction`. `CodexWatcher.Workflow.Execution.Core` is already exposed by `moifold.cabal`, so avoid a Cabal edit unless a new module is actually introduced.
10. Before review, inspect the diff for unintended contract changes: no event codec changes, no golden fixture edits, no daemon result type changes, no dry-run rendering changes, and no changed action ordering in compiled, partitioned, or executed action lists.

### Verification
Run the exact baseline commands from `orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001/verification.md`:

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check`

Focused task checks:

- `cabal test watcher-core-test` must include the new core checked-action traversal test and the existing moifold facade, observed daemon failure, workflow metadata ordering, and dry-run parity tests.
- `rg -n "executeWorkflowCheckedActionsOf|WorkflowCheckedActionFailure|workflowCheckedActionFailureReports" agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs src/CodexWatcher/Workflow/Execution.hs test/Main.hs` should show the core definition/export, the moifold facade adapter, and focused test coverage.
- `rg -n "CodexWatcher.ActionExecutor|CodexWatcher.Runtime.Command|CodexWatcher.Failure|ActionExecutionReport|CommandReport|PlannedAction" agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs` should have no matches.
- `rg -n "executeWorkflowCheckedActions|daemonFailureFromWorkflowActionFailure|DaemonActionFailed|observedDaemonTickExecuteCommandFailureDoesNotAppendEvent" src/CodexWatcher/Workflow/Execution.hs src/CodexWatcher/Daemon.hs test/Main.hs` should show the compatibility path still runs through the moifold facade and daemon failure mapper.
