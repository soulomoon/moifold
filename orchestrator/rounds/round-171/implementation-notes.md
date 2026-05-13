### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`. Function bodies, event construction, observations, summaries, and behavior were left unchanged.

### Tests
- No test files changed; this round is an import-only production migration.

### Notes
- `CodexWatcher.Core.Ids` remains available and exposed; this round does not deprecate, remove, or edit the facade.
- Existing `orchestrator/state.json` changes were present before implementation and were not edited by this role.

Verification commands:
- `git diff -- src/CodexWatcher/Workflow/Moifold/PrReview.hs` -> PASS; diff contains only the `CodexWatcher.Core.Ids` import removal and the two direct owner imports.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Workflow/Moifold/PrReview.hs` -> PASS; no matches, command exited 1 as expected for no matches.
- `cabal build all` -> PASS; built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold` library, and `moifold` executable with GHC 9.12.2.
- `cabal test watcher-core-test` -> PASS; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check` -> PASS; no whitespace errors.
