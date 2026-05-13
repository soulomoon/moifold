### Changes Made
- `test/AutomaticLoopRunnerSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `RepoName (..)` and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId (..), unThreadId`.

### Tests
- `test/AutomaticLoopRunnerSpec.hs`: existing automatic-loop execute, dry-run, retry-classification, request-id, thread-id, and endpoint-backed app-server assertions are unchanged.

### Notes
`CodexWatcher.Core.Ids` remains available and exposed. This round is preferred-import convergence only; it is not deprecation, Cabal exposure removal, facade removal, or public compatibility removal approval.
