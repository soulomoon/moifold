### Goal
Move the daemon-audit assertions in `test/Main.hs` off the exact mixed
`CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility
facade import and onto the direct owner module
`CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.

This round is import-convergence only. It must preserve the existing daemon
audit assertions, failure messages, event schemas, fixtures, public facade
availability, Cabal exposure, and the shared invariants in
`orchestrator/project-contract.md`.

### Approach
Use the direct audit owner for the existing local audit accessor and
recommendation references in `test/Main.hs`. Do not change production code,
other test files, public facade modules, package descriptors, docs, runtime
compatibility files, event JSON shapes, or facade policy tests.

The expected mapping is mechanical:

- `WorkflowEventLog.workflowAuditCommittedEventLabel` ->
  `WorkflowAudit.workflowAuditCommittedEventLabel`
- `WorkflowEventLog.workflowAuditPreCommitReports` ->
  `WorkflowAudit.workflowAuditPreCommitReports`
- `WorkflowEventLog.workflowAuditPostCommitReports` ->
  `WorkflowAudit.workflowAuditPostCommitReports`
- `WorkflowEventLog.workflowAuditNextDaemonRecommendation` ->
  `WorkflowAudit.workflowAuditNextDaemonRecommendation`
- `WorkflowEventLog.workflowAuditPriorStateLabel` ->
  `WorkflowAudit.workflowAuditPriorStateLabel`
- `WorkflowEventLog.workflowAuditObservationLabel` ->
  `WorkflowAudit.workflowAuditObservationLabel`
- `WorkflowEventLog.workflowAuditFinalStateLabel` ->
  `WorkflowAudit.workflowAuditFinalStateLabel`
- `WorkflowEventLog.workflowAuditFailureClassification` ->
  `WorkflowAudit.workflowAuditFailureClassification`
- `WorkflowEventLog.WorkflowDaemonContinue` ->
  `WorkflowAudit.WorkflowDaemonContinue`

No worker fan-out is justified: the write scope is one file, the replacements
are sequential, and splitting ownership would add coordination risk without
parallel value. Do not write `worker-plan.json`.

### Steps
1. Confirm the working tree before editing and do not touch unrelated
   controller state or unowned edits:
   `git status --short`.
2. Run precondition scans in the round worktree:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/Main.hs`.
   The expected starting shape is one exact import and only daemon-audit
   accessor/recommendation use sites near the observed daemon audit tests.
3. Confirm the direct owner module exports the required names before changing
   the test:
   `rg -n "WorkflowNextDaemonRecommendation|WorkflowDaemonContinue|WorkflowTickAudit|workflowAudit" agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`.
4. Edit `test/Main.hs` only:
   replace `import CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog`
   with `import CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
5. In `test/Main.hs` only, replace the local daemon-audit
   `WorkflowEventLog.` references from the precondition scan with the mapped
   `WorkflowAudit.` references. Preserve assertion names, assertion grouping,
   test helper definitions, and all expected values.
6. Re-run the selected-file scan:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/Main.hs`.
   It should return no matches.
7. Run a broad out-of-scope inventory scan and record the remaining exact
   facade imports without editing them:
   `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" src app test docs moifold.cabal *.cabal`.
   Expected remaining matches should be the out-of-scope test-side facade or
   policy users, such as `test/FacadeImportPolicySpec.hs`,
   `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, and
   `test/WorkflowExecutionSpec.hs`. `test/Main.hs` should no longer appear.

### Verification
Run the baseline checks required by the active verification bundle because this
round changes test code:

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if anything is staged

Also include focused evidence for this slice:

- Selected-file absence scan:
  `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/Main.hs`
  should have no matches.
- Broad remaining-facade inventory:
  `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" src app test docs moifold.cabal *.cabal`
  should list only out-of-scope remaining exact EventLog facade imports and
  should not list `test/Main.hs`.
- Test reachability note: `test/Main.hs` is the `watcher-core-test` aggregate;
  the daemon audit helpers named in this slice remain invoked from `main`
  (`observedDaemonTickDryRunDoesNotMutate`,
  `observedDaemonTickExecuteAppendsWritesAndRunsEffects`,
  `observedDaemonTickAuditSeparatesPreAndPostReports`, and
  `observedDaemonTickExecuteCommandFailureDoesNotAppendEvent`). If a practical
  focused REPL/typecheck command is available locally, use it before the full
  aggregate, but do not substitute it for `cabal test watcher-core-test`.
