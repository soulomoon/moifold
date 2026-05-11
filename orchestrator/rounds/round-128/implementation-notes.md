### Changes Made
- `src/CodexWatcher/Daemon.hs`: removed the exact `CodexWatcher.Workflow.EventLog` compatibility facade import from daemon audit helper usage.
- `src/CodexWatcher/Daemon.hs`: changed daemon observed audit type spellings and helper calls to the existing direct owner import `CodexWatcher.Workflow.Audit qualified as WorkflowAudit`, including the explicit `FailureClassification` audit failure parameter.
- `src/CodexWatcher/Daemon.hs`: kept direct `CodexWatcher.Workflow.EventLog.Commit.Core` ownership unchanged and did not change event labels, event JSON fields, replay behavior, append order, compatibility writes, transaction hooks, failure formatting, public exports, package descriptors, docs, tests, facade modules, or runtime compatibility files.

### Tests
- `printf '%s\n' 'observedDaemonTickDryRunDoesNotMutate' 'observedDaemonTickExecuteAppendsWritesAndRunsEffects' 'observedDaemonTickAuditSeparatesPreAndPostReports' 'observedDaemonTickExecuteCommandFailureDoesNotAppendEvent' ':quit' | cabal repl watcher-core-test`: passed; all four focused daemon probes returned `True`.
- `printf '%s\n' 'workflowExecutionTests' ':quit' | cabal repl watcher-core-test`: passed; aggregate returned `True`.
- `printf '%s\n' 'workflowIndexedTests' ':quit' | cabal repl watcher-core-test`: passed; aggregate returned `True`.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged diff was present.
- `rg -n '^import CodexWatcher\.Workflow\.EventLog($|[[:space:]]+qualified|[[:space:]]*\()' src/CodexWatcher/Daemon.hs`: no matches, as expected.
- `rg -n '^import CodexWatcher\.Workflow\.(Audit|EventLog\.)' src/CodexWatcher/Daemon.hs`: showed `CodexWatcher.Workflow.Audit qualified as WorkflowAudit` and `CodexWatcher.Workflow.EventLog.Commit.Core`.
- `rg -n 'WorkflowEventLog\.' src/CodexWatcher/Daemon.hs`: no matches, as expected.
- `rg -n '^import CodexWatcher\.Workflow\.EventLog($|[[:space:]]+qualified|[[:space:]]*\()' src app test`: no `src/CodexWatcher/Daemon.hs` match; remaining exact facade imports were in out-of-scope test and test-support files.
- `rg -n 'CodexWatcher\.Workflow\.EventLog' src app test docs *.cabal agent-workflow-*`: `src/CodexWatcher/Daemon.hs` appeared only for direct `CodexWatcher.Workflow.EventLog.Commit.Core`; remaining exact facade references were public exposure/facade, tests/test support, docs/policy, and Cabal exposure.
- Diff guards (`git diff -- src/CodexWatcher/Daemon.hs`, `git diff --unified=0 -- src/CodexWatcher/Daemon.hs`, and the requested filtered diff): passed; diff is limited to the facade import removal, direct audit type spelling, and `WorkflowAudit` helper qualifiers.

### Notes
No commands failed or were blocked. No files outside the owned write scope were intentionally changed.
