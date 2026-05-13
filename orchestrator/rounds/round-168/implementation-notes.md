### Changes Made
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `PrNumber`, and `RepoName`, and `CodexWatcher.Workflow.Agent.Ids` for `RequestId` and `ThreadId`.
- `orchestrator/rounds/round-168/implementation-notes.md`: recorded the implementation and verification evidence for round 168.

### Tests
- No test files changed. Existing PR-review launch behavior remains covered by `watcher-core-test`, including `PrReviewLaunchCliSpec`.

### Notes
- Scope stayed import-only in `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`; no behavior, JSON, event, command rendering, runtime compatibility, public facade, Cabal, roadmap, or state changes were made.
- Verification commands:
  - `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: passed with no matches, exit code 1.
  - `rg -n "CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: passed, showing `CodexWatcher.Workflow.Agent.Ids` at line 23 and `CodexWatcher.Workflow.GitHub.Ids` at line 39.
  - `cabal build all`: passed.
  - `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
  - `git diff --check`: passed with no output.
