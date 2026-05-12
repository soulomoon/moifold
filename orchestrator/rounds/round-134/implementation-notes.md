### Changes Made
- `test/WorkflowEventLogSpec.hs`: added direct qualified owner imports for `CodexWatcher.Workflow.EventLog.Core` as `WorkflowEventLogCore` and `CodexWatcher.Workflow.Audit` as `WorkflowAudit`.
- `test/WorkflowEventLogSpec.hs`: moved reusable EventLog core calls, fixture contract fields, replay helpers, transition helpers, and failure formatting from `WorkflowEventLog.*` to `WorkflowEventLogCore.*`.
- `test/WorkflowEventLogSpec.hs`: moved workflow audit construction and accessors from `WorkflowEventLog.*` to `WorkflowAudit.*`, using `WorkflowAudit.workflowFailureAudit @MoifoldSpec failureIsRetryable ...`.
- `test/WorkflowEventLogSpec.hs`: kept the compatibility facade qualified as `WorkflowEventLog` only for the intentional bridge-wrapper parity calls to `initializeMoifoldWorkflow` and `applyMoifoldWorkflowEvent`.

### Tests
- `rg -n "WorkflowEventLog\\." test/WorkflowEventLogSpec.hs`: passed; remaining facade-qualified uses are only `WorkflowEventLog.initializeMoifoldWorkflow` and `WorkflowEventLog.applyMoifoldWorkflowEvent`.
- `rg -n "^import CodexWatcher\\.Workflow\\.EventLog(\\s|$| qualified|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github *.cabal docs 2>/dev/null`: passed; exact facade imports remain only in `test/WorkflowEventLogSpec.hs` and `test/FacadeImportPolicySpec.hs`.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not run because no changes are staged.

### Notes
No production modules, package descriptors, docs, policy files, support files, `test/FacadeImportPolicySpec.hs`, or `orchestrator/state.json` were edited by this implementation.
