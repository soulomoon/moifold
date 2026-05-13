### Changes Made
- `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `IssueNumber`, and `RepoName`, and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`.

### Tests
- No test files changed; this round is an import-only production migration with behavior unchanged.

### Verification
- `git diff -- src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`: showed only the planned import replacement in `Fanout.hs`.
- `rg -n "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`: exited 1 with no output, meaning the selected file has no remaining `CodexWatcher.Core.Ids` import/reference.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; final output reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: passed with no output.

### Notes
No behavior, tests, Cabal files, roadmap files, or orchestrator state were changed.
