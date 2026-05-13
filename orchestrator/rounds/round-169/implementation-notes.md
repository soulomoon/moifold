### Changes Made
- `src/CodexWatcher/DaemonLoop/Types.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `CommitSha` and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId (..)`. No declarations, exports, constructors, deriving clauses, or function bodies changed.

### Tests
- No test files changed; this round is an import-owner migration only.
- `rg "CodexWatcher.Core.Ids" src/CodexWatcher/DaemonLoop/Types.hs`: exit 1, no matches.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. Final output included `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: passed.

### Notes
The selected module now imports the same ID types from their direct owner modules. Public compatibility facades, package descriptors, tests, roadmap files, and orchestrator state were left unchanged.
