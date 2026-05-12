### Changes Made
- `test/Main.hs`: replaced the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` import with `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`.
- `test/Main.hs`: moved only the daemon-audit accessor/recommendation references from `WorkflowEventLog.` to the direct owner `WorkflowAudit.` names. Assertions, expected values, helper definitions, event schemas, fixtures, facade availability, Cabal exposure, docs/policy, runtime files, and other tests were left unchanged.

### Tests
- `test/Main.hs`: existing daemon audit checks remain reachable through the `watcher-core-test` aggregate: `observedDaemonTickDryRunDoesNotMutate`, `observedDaemonTickExecuteAppendsWritesAndRunsEffects`, `observedDaemonTickAuditSeparatesPreAndPostReports`, and `observedDaemonTickExecuteCommandFailureDoesNotAppendEvent`.
- Precondition scan before editing:
  - Command: `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/Main.hs`
  - Result: one exact import at line 72 and daemon-audit `WorkflowEventLog.` accessor/recommendation uses at lines 3777, 3779, 3780, 3781, 3814, 3852-3859, and 3904.
- Direct owner export scan before editing:
  - Command: `rg -n "WorkflowNextDaemonRecommendation|WorkflowDaemonContinue|WorkflowTickAudit|workflowAudit" agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`
  - Result: confirmed `WorkflowNextDaemonRecommendation (..)`, `WorkflowDaemonContinue`, `WorkflowTickAudit (..)`, and the required `workflowAudit...` accessors are exported/defined in `CodexWatcher.Workflow.Audit`.
- Focused practical compile probe:
  - Command: `cabal build watcher-core-test`
  - Result: passed; `test/Main.hs` compiled and `watcher-core-test` linked.
- Baseline aggregate:
  - Command: `cabal test watcher-core-test`
  - Result: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- Baseline build:
  - Command: `cabal build all`
  - Result: passed; executable `moifold` linked.
- Whitespace/diff checks:
  - Command: `git diff --check`
  - Result: passed.
  - Command: `git diff --cached --check`
  - Result: passed; no staged changes were present, but the check was run.
- Selected-file absence scan after editing:
  - Command: `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog|WorkflowEventLog\\." test/Main.hs`
  - Result: no matches.
- Broad exact EventLog facade scan after editing:
  - Command: `rg -n "CodexWatcher\\.Workflow\\.EventLog qualified as WorkflowEventLog" src app test docs moifold.cabal *.cabal`
  - Result: remaining out-of-scope matches only:
    - `test/FacadeImportPolicySpec.hs:21`
    - `test/WorkflowEventLogSpec.hs:84`
    - `test/WorkflowIndexedSpec.hs:84`
    - `test/WorkflowExecutionSpec.hs:84`
  - `test/Main.hs` no longer appears.

### Notes
No production code, package descriptors, docs, runtime compatibility files, fixture files, facade modules, or controller state were edited. Existing modified `orchestrator/state.json` was present before this implementer pass and was left untouched.
