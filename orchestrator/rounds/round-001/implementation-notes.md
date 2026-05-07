### Changes Made
- `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`: added `WorkflowCheckedActionFailureOf`, `executeWorkflowCheckedActionsOf`, and `workflowCheckedActionFailureReports` so core owns the generic left-to-right checked-action traversal and failure report projection without importing moifold concrete modules.
- `src/CodexWatcher/Workflow/Execution.hs`: replaced the local checked-action recursion with a thin adapter over the core traversal while keeping `WorkflowActionFailure`, concrete hard-failure classification, `CommandReport` extraction, and facade report projection behavior in the moifold facade.
- `test/Main.hs`: added focused core traversal coverage, strengthened the moifold checked-action facade regression, and extended the core package-boundary assertion to reject concrete executor/runtime/failure/report/action dependencies while avoiding false positives for existing generic `WorkflowPlannedActionOf` identifiers.

### Tests
- `test/Main.hs`: `workflowExecutionCoreCheckedActionsStopsOnFirstFailure` verifies left-to-right execution, first-failure short-circuiting, prior-report ordering, failed-report capture, reason capture, and success-report ordering using simple core-only values.
- `test/Main.hs`: `workflowExecutionCheckedActionsStopsOnHardFailure` now also verifies the facade failure is the failing `GitPush`, has no prior reports, projects the failed report through `workflowActionFailureReports`, keeps a non-ok `CommandReport`, and does not execute the following `CreateIssue`.
- `test/Main.hs`: `workflowCoreCabalSublibraryKeepsPackageBoundary` now rejects core references to `CodexWatcher.ActionExecutor`, `CodexWatcher.Runtime.Command`, `CodexWatcher.Failure`, `ActionExecutionReport`, `CommandReport`, and concrete `PlannedAction`.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.

### Notes
No roadmap, review, merge, event fixture, event codec, daemon result type, dry-run rendering, or action-ordering files were changed. No blockers.
