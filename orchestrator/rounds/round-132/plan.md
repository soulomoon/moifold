### Goal

Move only `test/WorkflowExecutionSpec.hs` off the exact
`CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility
facade import for daemon audit accessors and daemon recommendation constructors,
using the direct owner module `CodexWatcher.Workflow.Audit`.

This round does not change production code, other tests, event schemas,
fixtures, package descriptors, docs, public facades, permission imports,
runtime compatibility files, or milestone/terminal status.

### Approach

Keep the change as a qualifier-only import convergence slice in one file:

- Replace
  `import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`
  with `import CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
- Keep the existing direct owner imports
  `CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit`
  and
  `CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore`
  unchanged.
- Map these current `WorkflowEventLog.` audit names to `WorkflowAudit.`:
  `workflowAuditPreCommitReports`,
  `workflowAuditPostCommitReports`,
  `workflowAuditCommittedEventLabel`,
  `workflowAuditFailureClassification`,
  `workflowAuditNextDaemonRecommendation`,
  `workflowAuditPriorStateLabel`,
  `workflowAuditObservationLabel`, and
  `workflowAuditFinalStateLabel`.
- Map `WorkflowEventLog.WorkflowDaemonRetry` and
  `WorkflowEventLog.WorkflowDaemonStop` to `WorkflowAudit.WorkflowDaemonRetry`
  and `WorkflowAudit.WorkflowDaemonStop`.

The direct owner export check is:
`agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` exports
`WorkflowNextDaemonRecommendation(..)` and `WorkflowTickAudit(..)`, which cover
the constructors and record field accessors needed by this file.

No worker fan-out is justified because the selected scope is one test file and
the implementation has one non-overlapping ownership surface.

### Steps

1. Confirm the precondition in `test/WorkflowExecutionSpec.hs`:
   `rg -n 'CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test/WorkflowExecutionSpec.hs`
   should show the exact facade import and only local audit accessor or
   `WorkflowDaemonRetry` / `WorkflowDaemonStop` recommendation uses.
2. Confirm direct owner availability:
   `rg -n 'module CodexWatcher\.Workflow\.Audit|WorkflowNextDaemonRecommendation|WorkflowTickAudit|WorkflowDaemonRetry|WorkflowDaemonStop|workflowAuditPreCommitReports|workflowAuditPostCommitReports|workflowAuditCommittedEventLabel|workflowAuditNextDaemonRecommendation' agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`.
3. Edit only `test/WorkflowExecutionSpec.hs`:
   replace the exact EventLog facade import with
   `import CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
4. In `test/WorkflowExecutionSpec.hs`, replace only the mapped
   `WorkflowEventLog.` audit accessor and recommendation constructor references
   with `WorkflowAudit.`. Preserve assertion names, helper definitions,
   expected values, aggregate wiring, event labels, transaction behavior, and
   daemon audit behavior.
5. Do not change the `WorkflowEventLogCommit` or `WorkflowEventLogFileCore`
   imports or use sites.
6. Do not touch `test/FacadeImportPolicySpec.hs`,
   `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`,
   `test/Main.hs`, `test/WorkflowDocsMigrationSpec.hs`, production/app files,
   package descriptors, docs, policy files, permission modules, runtime
   compatibility files, schemas, or fixtures.
7. After editing, review the selected-file diff:
   `git diff -- test/WorkflowExecutionSpec.hs`.

### Verification

Run these checks after implementation:

1. Selected-file absence scan:
   `rg -n 'CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test/WorkflowExecutionSpec.hs`
   should return no matches.
2. Selected-file owner import scan:
   `rg -n '^import CodexWatcher\.Workflow\.(Audit|EventLog\.)' test/WorkflowExecutionSpec.hs`
   should show `CodexWatcher.Workflow.Audit qualified as WorkflowAudit` plus
   the unchanged `EventLog.Commit.Core` and `EventLog.File.Core` direct owner
   imports.
3. Broad exact facade scan:
   `rg -n '^import CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test src app agent-workflow-* -g '*.hs'`.
   The result should have no `test/WorkflowExecutionSpec.hs` entries and should
   show only remaining out-of-scope EventLog facade users such as
   `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and
   `test/WorkflowIndexedSpec.hs`.
4. Practical selected-module compile probe:
   `cabal build watcher-core-test`. The current custom test runner does not
   expose a per-module selector, so this is the narrow practical compile probe
   for `WorkflowExecutionSpec`.
5. Full test gate:
   `cabal test watcher-core-test`.
6. Full build gate:
   `cabal build all`.
7. Whitespace/conflict checks:
   `git diff --check`.
8. If staging is involved, also run:
   `git diff --cached --check`.

### Worker Fan-Out

No worker fan-out. The round owns one file, the edits are mechanical
qualifier/import replacements, and splitting would add coordination overhead
without independent ownership boundaries.
