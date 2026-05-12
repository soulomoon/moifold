### Changes Made
- `test/WorkflowExecutionSpec.hs`: replaced the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility facade import with `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
- `test/WorkflowExecutionSpec.hs`: remapped only local audit accessor and daemon recommendation references from `WorkflowEventLog.` to `WorkflowAudit.`, including `WorkflowDaemonRetry` and `WorkflowDaemonStop`; left `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` imports/use sites unchanged.

### Tests
- `test/WorkflowExecutionSpec.hs`: existing daemon audit and workflow transaction assertions now exercise the same behavior through the direct audit owner import.
- Precondition scan: `rg -n 'CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test/WorkflowExecutionSpec.hs` showed the exact facade import plus only local audit accessor/recommendation uses before editing.
- Direct owner export scan: `rg -n 'module CodexWatcher\.Workflow\.Audit|WorkflowNextDaemonRecommendation|WorkflowTickAudit|WorkflowDaemonRetry|WorkflowDaemonStop|workflowAuditPreCommitReports|workflowAuditPostCommitReports|workflowAuditCommittedEventLabel|workflowAuditNextDaemonRecommendation' agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` confirmed `WorkflowNextDaemonRecommendation(..)` and `WorkflowTickAudit(..)` exports with the needed constructors/accessors.
- Diff review: `git diff -- test/WorkflowExecutionSpec.hs` showed only the import replacement and mapped qualifier changes.
- Selected-file absence scan: `rg -n 'CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test/WorkflowExecutionSpec.hs` returned no matches.
- Selected-file owner import scan: `rg -n '^import CodexWatcher\.Workflow\.(Audit|EventLog\.)' test/WorkflowExecutionSpec.hs` showed `Workflow.Audit` plus unchanged `EventLog.Commit.Core` and `EventLog.File.Core` imports.
- Broad facade/stale-use scan: `rg -n '^import CodexWatcher\.Workflow\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\.' test src app agent-workflow-* -g '*.hs'` reported only out-of-scope facade users in `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and `test/WorkflowIndexedSpec.hs`; no `test/WorkflowExecutionSpec.hs` entries remained.
- `cabal build watcher-core-test`: passed.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged changes were involved.

### Notes
No production files, package descriptors, docs, policy files, runtime compatibility files, event schemas, fixtures, aggregate wiring, transaction behavior, or daemon audit behavior were changed. Existing controller edits to `orchestrator/state.json` were left untouched.
