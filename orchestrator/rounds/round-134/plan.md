### Goal

Migrate `test/WorkflowEventLogSpec.hs` so reusable EventLog core assertions and workflow audit assertions use their direct owner modules, while the remaining Moifold bridge-wrapper parity checks continue to call `CodexWatcher.Workflow.EventLog` explicitly. This round only changes the selected test file and does not change production modules, facade exports, package exposure, event schemas, fixtures, or policy/docs.

### Approach

Keep the round sequential and single-owner. The implementation target is one file, `test/WorkflowEventLogSpec.hs`, so worker fan-out is not justified and no `worker-plan.json` should be created.

Add direct qualified imports for:

- `CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore`
- `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`

Retain `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` only for intentional bridge-wrapper checks that currently live on the compatibility facade:

- `WorkflowEventLog.initializeMoifoldWorkflow`
- `WorkflowEventLog.applyMoifoldWorkflowEvent`

Map current facade-qualified reusable EventLog core use sites to `WorkflowEventLogCore`:

- `EventLogFixtureContract`
- `fixtureExpectedStateLabel`
- `fixtureExpectedEventCount`
- `replayWorkflowEventLogDetailed`
- `validateEventLogFixtureContract`
- `initializeWorkflowEvent`
- `applyWorkflowEvent`
- `workflowTransitionEventLabel`
- `workflowTransitionPriorStateLabel`
- `workflowTransitionReason`
- `formatWorkflowTransitionFailure`

Map current facade-qualified audit use sites to `WorkflowAudit`:

- `workflowFailureAudit`
- `workflowAuditPriorStateLabel`
- `workflowAuditObservationLabel`
- `workflowAuditFailureClassification`
- `workflowAuditNextDaemonRecommendation`
- `WorkflowDaemonRetry`

Because the direct audit helper has the reusable signature, call `WorkflowAudit.workflowFailureAudit @MoifoldSpec failureIsRetryable ...` instead of the facade wrapper’s `WorkflowEventLog.workflowFailureAudit @MoifoldSpec ...`. `failureIsRetryable` is already imported from `CodexWatcher.Failure` through the existing module import.

### Steps

1. Precondition scan the selected file:
   - Run `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`.
   - Confirm the existing facade-qualified use sites match the selected scope and are limited to replay/fixture/transition core helpers, audit helpers, and the two Moifold bridge wrappers.
2. Precondition scan direct owner exports:
   - Inspect `agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs` and confirm it exports the EventLog core symbols listed above.
   - Inspect `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs` and confirm it exports the audit symbols listed above, including `WorkflowNextDaemonRecommendation (..)`.
   - Inspect `src/CodexWatcher/Workflow/EventLog.hs` only to confirm the Moifold bridge wrappers still live on the facade for this round.
3. Edit only `test/WorkflowEventLogSpec.hs`:
   - Add the two direct owner qualified imports.
   - Replace generic core `WorkflowEventLog.` qualifiers with `WorkflowEventLogCore.` according to the mapping above.
   - Replace audit `WorkflowEventLog.` qualifiers with `WorkflowAudit.` according to the mapping above.
   - Update the audit construction to pass `failureIsRetryable` explicitly to the direct owner helper.
   - Leave `WorkflowEventLog.initializeMoifoldWorkflow` and `WorkflowEventLog.applyMoifoldWorkflowEvent` facade-qualified so the test continues to exercise current bridge-wrapper compatibility behavior.
4. Do not edit:
   - `test/FacadeImportPolicySpec.hs`
   - production `src` or `app` files
   - other tests or support files
   - package descriptors or Cabal exposure
   - event schemas, fixtures, docs, policy, runtime compatibility files, or `orchestrator/state.json`
5. After editing, scan `test/WorkflowEventLogSpec.hs` again and confirm every remaining `WorkflowEventLog.` use is one of:
   - `WorkflowEventLog.initializeMoifoldWorkflow`
   - `WorkflowEventLog.applyMoifoldWorkflowEvent`
6. Run the broad exact facade import scan:
   - `rg -n "^import CodexWatcher\\.Workflow\\.EventLog(\\s|$| qualified|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github *.cabal docs 2>/dev/null`
   - Expected remaining exact imports are `test/WorkflowEventLogSpec.hs` for the intentional bridge wrappers and `test/FacadeImportPolicySpec.hs` for facade policy coverage.

### Verification

Run the selected-file and repository checks:

- `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`
  - Expected: only `initializeMoifoldWorkflow` and `applyMoifoldWorkflowEvent` remain facade-qualified.
- `rg -n "^import CodexWatcher\\.Workflow\\.EventLog(\\s|$| qualified|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github *.cabal docs 2>/dev/null`
  - Expected: exact facade imports remain only in `test/WorkflowEventLogSpec.hs` and `test/FacadeImportPolicySpec.hs`; the `WorkflowEventLogSpec` import remains intentionally for bridge-wrapper checks.
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any changes are staged

The implementation should not claim facade deprecation/removal, package-boundary completion, milestone completion, terminal completion, release approval, or public compatibility removal.
