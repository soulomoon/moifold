### Changes Made
- `test/RuntimeSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`.
- `orchestrator/rounds/round-193/implementation-notes.md`: recorded this round's implementation and verification evidence.

### Tests
- `test/RuntimeSpec.hs`: unchanged runtime command rendering, default-option, process, GitHub/Git command, PASS-label, and export-list assertions compile and run under direct id-owner imports.
- `watcher-core-test`: full suite passed after the import migration.

### Notes
- `rg -n "CodexWatcher\\.Core\\.Ids" test/RuntimeSpec.hs`: passed by finding no matches; `rg` exited 1 because the selected file no longer imports the facade.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/RuntimeSpec.hs`: passed; found direct imports at `test/RuntimeSpec.hs:30` and `test/RuntimeSpec.hs:31`.
- `git diff -- test/RuntimeSpec.hs`: passed; diff is import-only in `test/RuntimeSpec.hs`.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal`: passed as remaining-user evidence. Remaining out-of-scope users are `moifold.cabal`, `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, docs references, and the public facade module `src/CodexWatcher/Core/Ids.hs`.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed.
- No commands were skipped or failed.
- `orchestrator/state.json` was already modified in the worktree before this implementation and was not edited by this round.
