### Changes Made
- `test/WorkflowIndexedSpec.hs`: replaced the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import with `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
- `test/WorkflowIndexedSpec.hs`: rewired only local audit accessor references and `WorkflowDaemonStop` from `WorkflowEventLog.` to `WorkflowAudit.`; preserved `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` imports and use sites.

### Tests
- `test/WorkflowIndexedSpec.hs`: existing indexed workflow assertions now compile against the direct audit owner module while preserving audit labels, report lists, daemon recommendation checks, aggregate wiring, and event behavior.

### Notes
Precondition scan:

- Ran `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/WorkflowIndexedSpec.hs`.
- Before editing, it found the exact facade import at line 84, audit accessor uses for `workflowAuditCommittedEventLabel`, `workflowAuditPriorStateLabel`, `workflowAuditFinalStateLabel`, `workflowAuditPreCommitReports`, `workflowAuditPostCommitReports`, `workflowAuditNextDaemonRecommendation`, and one `WorkflowEventLog.WorkflowDaemonStop`.

Direct owner export scan:

- Ran `rg -n "module CodexWatcher\\.Workflow\\.Audit|WorkflowNextDaemonRecommendation|WorkflowTickAudit|WorkflowDaemonStop" agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`.
- Confirmed `CodexWatcher.Workflow.Audit` exports `WorkflowNextDaemonRecommendation (..)`, `WorkflowTickAudit (..)`, the audit selectors, and `WorkflowDaemonStop`.

Diff/scan evidence:

- Ran `git diff -- test/WorkflowIndexedSpec.hs`; diff is limited to the import swap and local `WorkflowEventLog.workflowAudit...` / `WorkflowEventLog.WorkflowDaemonStop` replacements.
- Ran selected-file absence scan `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/WorkflowIndexedSpec.hs`; no matches.
- Ran broad exact EventLog facade/stale-use scan `rg -n "CodexWatcher\\.Workflow\\.EventLog( qualified as WorkflowEventLog)?|WorkflowEventLog\\." src app test docs *.cabal agent-workflow-* -g'*.hs' -g'*.md' -g'*.cabal'`.
- Broad scan still reports out-of-scope public/exposure/core/doc references and expected remaining facade users in `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`; `test/WorkflowIndexedSpec.hs` now only appears for the preserved `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` direct owner imports.

Verification:

- `cabal build watcher-core-test`: passed.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because no files are staged.

No production files, package descriptors, docs, public compatibility facades, event schemas, runtime compatibility files, or out-of-scope tests were edited. Existing controller-owned `orchestrator/state.json` changes were left untouched.
