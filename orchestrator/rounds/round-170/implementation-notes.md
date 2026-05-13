### Changes Made
- `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`.

### Tests
- No tests were changed; this round is an import-owner migration only.

### Verification
- `rg "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
  - Result: exit 1, no matches.
- `cabal build all`
  - Result: exit 0, succeeded.
- `cabal test watcher-core-test`
  - Result: exit 0, `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`
  - Result: exit 0, succeeded.

### Notes
- No behavior, declarations, event constructors, state-machine decisions, package descriptors, roadmap files, or orchestrator state were changed.
