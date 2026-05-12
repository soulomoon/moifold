### Goal
Migrate only `test/WorkflowIndexedSpec.hs` from the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade import to the direct `CodexWatcher.Workflow.Audit` owner module for its current audit accessor and daemon recommendation uses.

This round belongs to roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-012-eventlog-permission-bridge-split-readiness`, extracted item `round-133-workflow-indexed-audit-eventlog-direct-owner-import-convergence`. It follows `orchestrator/project-contract.md`; it does not authorize facade deprecation/removal, Cabal exposure changes, event schema changes, runtime compatibility changes, milestone completion, or terminal completion.

### Approach
Keep the edit mechanical and behavior-preserving:

- Add `import CodexWatcher.Workflow.Audit qualified as WorkflowAudit` to `test/WorkflowIndexedSpec.hs`.
- Remove only the exact `import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` line from that file.
- Replace the current local `WorkflowEventLog.` audit references with `WorkflowAudit.` references.
- Preserve the existing direct owner imports `WorkflowEventLogCommit` and `WorkflowEventLogFileCore`.
- Do not touch production/app files, other tests, package descriptors, docs, public compatibility facades, permission modules, fixtures, schemas, or runtime compatibility files.

Precondition scan already identifies the selected-file facade uses:

- Exact facade import at `test/WorkflowIndexedSpec.hs:84`.
- Audit accessors only: `workflowAuditCommittedEventLabel`, `workflowAuditPriorStateLabel`, `workflowAuditFinalStateLabel`, `workflowAuditPreCommitReports`, `workflowAuditPostCommitReports`, and `workflowAuditNextDaemonRecommendation`.
- Audit recommendation constructor: `WorkflowDaemonStop`.
- No other `WorkflowEventLog.` recommendation constructors appear in `test/WorkflowIndexedSpec.hs` from the precondition scan.

Direct owner export check:

- `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` exports `WorkflowNextDaemonRecommendation(..)` and `WorkflowTickAudit(..)`, so the accessor selectors and `WorkflowDaemonStop` are directly available through a qualified `WorkflowAudit` import.

### Steps
1. Re-run the precondition scan before editing:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/WorkflowIndexedSpec.hs`
2. Confirm direct owner exports before editing:
   `rg -n "module CodexWatcher\\.Workflow\\.Audit|WorkflowNextDaemonRecommendation|WorkflowTickAudit|WorkflowDaemonStop" agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`
3. Edit only `test/WorkflowIndexedSpec.hs`:
   - Replace the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import with `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
   - Replace each selected-file `WorkflowEventLog.workflowAudit...` accessor with `WorkflowAudit.workflowAudit...`.
   - Replace `WorkflowEventLog.WorkflowDaemonStop` with `WorkflowAudit.WorkflowDaemonStop`.
   - Leave `CodexWatcher.Workflow.EventLog.Commit.Core qualified as WorkflowEventLogCommit` and `CodexWatcher.Workflow.EventLog.File.Core qualified as WorkflowEventLogFileCore` unchanged.
4. Run a selected-file absence scan:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/WorkflowIndexedSpec.hs`
   Expected result: no matches.
5. Run a broad exact EventLog facade/stale-use scan:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog( qualified as WorkflowEventLog)?|WorkflowEventLog\\." src app test docs *.cabal agent-workflow-* -g'*.hs' -g'*.md' -g'*.cabal'`
   Expected result: remaining exact facade users are out of scope, especially `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and the public/exposure or docs references; no `WorkflowIndexedSpec.hs` exact facade import or `WorkflowEventLog.` use remains. Direct owner/core imports such as `WorkflowEventLogCommit`, `WorkflowEventLogFileCore`, and `Workflow.EventLog.Core` are not blockers for this round.
6. Inspect the final diff and confirm only `test/WorkflowIndexedSpec.hs` changed for implementation; ignore the controller-written `orchestrator/state.json` changes and keep them untouched.

### Verification
Run the focused and baseline checks from the round selection and active verification bundle:

1. Practical selected-file compile probe:
   `cabal build watcher-core-test`
   This test suite includes `WorkflowIndexedSpec` as a module, so this catches import/export mistakes in the selected file. There is no separate narrow test-suite target for `WorkflowIndexedSpec` in `moifold.cabal`.
2. Full test baseline:
   `cabal test watcher-core-test`
3. Full build baseline:
   `cabal build all`
4. Whitespace/diff checks:
   `git diff --check`
   `git diff --cached --check` only if staging is involved.
5. Record scan evidence in implementation notes:
   - selected-file absence scan shows no `WorkflowIndexedSpec.hs` exact facade import or `WorkflowEventLog.` use;
   - broad exact EventLog facade/stale-use scan shows remaining out-of-scope tests and compatibility/public references, with no stale selected-file use.

No worker fan-out is planned. The implementation ownership is a single file, `test/WorkflowIndexedSpec.hs`, and splitting this work would add coordination without non-overlapping implementation boundaries.
