### Checks Run
- Command: `rg -n "WorkflowEventLog\." test/WorkflowEventLogSpec.hs`
  Result: pass. Remaining facade-qualified uses are only `WorkflowEventLog.initializeMoifoldWorkflow` and `WorkflowEventLog.applyMoifoldWorkflowEvent`.

- Command: `rg -n "^import CodexWatcher\.Workflow\.EventLog(\s|$| qualified|\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github *.cabal docs 2>/dev/null`
  Result: pass. Remaining exact facade imports are `test/FacadeImportPolicySpec.hs:21` and `test/WorkflowEventLogSpec.hs:85`.

- Command: `git diff --name-only -- ':(exclude)orchestrator/state.json' ':(exclude)orchestrator/rounds/round-134/**'`
  Result: pass. Output is only `test/WorkflowEventLogSpec.hs`, confirming no production, app, package descriptor, docs, policy, runtime compatibility, or other test files changed in the implementation diff.

- Command: `git diff -- test/FacadeImportPolicySpec.hs`
  Result: pass. No diff; `test/FacadeImportPolicySpec.hs` is untouched.

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged diff exists and no staged whitespace errors were reported.

- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

### Plan Compliance
- Add direct owner imports for reusable core and audit helpers: met. `test/WorkflowEventLogSpec.hs` imports `CodexWatcher.Workflow.EventLog.Core qualified as WorkflowEventLogCore` and `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
- Move reusable EventLog core calls off the compatibility facade: met. Replay, fixture contract, transition, and failure-formatting calls now use `WorkflowEventLogCore`.
- Move workflow audit calls off the compatibility facade: met. Audit construction and accessors now use `WorkflowAudit`, including `WorkflowAudit.workflowFailureAudit @MoifoldSpec failureIsRetryable`.
- Keep `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` only for intentional Moifold bridge-wrapper calls: met. The selected-file scan shows only `initializeMoifoldWorkflow` and `applyMoifoldWorkflowEvent`.
- Keep `test/FacadeImportPolicySpec.hs` untouched: met. No diff.
- Avoid production/app/package/docs/policy/runtime compatibility/other test changes: met. Excluding controller-owned state metadata and round artifacts, the only changed project file is `test/WorkflowEventLogSpec.hs`.
- Avoid public facade availability/removal/deprecation claims: met. The implementation changes imports in one behavior test and does not change facade exports, package exposure, docs, policy, or public wording.
- Preserve active roadmap lineage: met. Selection and state identify roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, direction `direction-012-eventlog-permission-bridge-split-readiness`, extracted item `round-134-workflow-eventlog-spec-core-audit-direct-owner-split`.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected round scope. `test/WorkflowEventLogSpec.hs` now uses direct owner modules for reusable EventLog core and workflow audit assertions, while the remaining `WorkflowEventLog` facade-qualified uses are the two intentional Moifold bridge-wrapper parity calls. The broad exact facade import scan still finds only the policy test and the intentional bridge-wrapper test import. `test/FacadeImportPolicySpec.hs` has no diff.

The only non-round-artifact implementation diff is `test/WorkflowEventLogSpec.hs`. `orchestrator/state.json` is modified in this worktree as active-round controller metadata, but this review did not edit it and does not rely on it as implementation scope. No public facade deprecation, removal, Cabal exposure change, docs change, runtime compatibility change, event schema change, or fixture shape change is present.

Required verification passed: `rg` focused scan, broad facade import scan, `git diff --check`, `git diff --cached --check`, `cabal test watcher-core-test`, and `cabal build all`.
