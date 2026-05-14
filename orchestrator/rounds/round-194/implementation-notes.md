### Changes Made
- `test/RuntimeCompatibilityFixtureSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `TurnId`, and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName`.

### Tests
- `test/RuntimeCompatibilityFixtureSpec.hs`: existing runtime compatibility fixture coverage remains unchanged; this round only changes where the ID constructors are imported from.

Verification:
- `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeCompatibilityFixtureSpec.hs`
  - Passed with no matches, exit 1.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RuntimeCompatibilityFixtureSpec.hs`
  - Passed, showing `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))`.
- `git diff -- test/RuntimeCompatibilityFixtureSpec.hs`
  - Passed inspection; the selected-file diff is import-only.
- `cabal test watcher-core-test`
  - Passed; `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`
  - Passed with no output.
- `cabal build all`
  - Passed; built the `moifold` executable after the test target had already built the libraries.
- `rg -n "CodexWatcher\\.Core\\.Ids" test src app bench exe orchestrator -g'*.hs' -g'*.md' -g'*.cabal'`
  - Failed because `bench` and `exe` directories do not exist in this worktree.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal orchestrator/rounds/round-194 orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`
  - Passed as a broad remaining-user scan. Remaining live code/test/package matches are `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `src/CodexWatcher/Core/Ids.hs`, and `moifold.cabal`; roadmap and round-plan docs also mention the facade. No `test/RuntimeCompatibilityFixtureSpec.hs` match remains.

### Notes
No fixture JSON, fixture paths, runtime compatibility writes, repair behavior, healthcheck reader boundary assertions, daemon-state assertions, planning graph assertions, PASS labels, helpers, export list, `test/Main.hs`, roadmap files, or `orchestrator/state.json` were edited by this implementation.
