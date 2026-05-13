### Changes Made
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: replaced the combined `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`. Function bodies and all existing `unRepoName`, `unThreadId`, and `unTurnId` uses were left unchanged.

### Tests
- No tests were edited; this round is an import-only production migration.
- `cabal build all`: passed. Built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold` library, and `moifold` executable with GHC 9.12.2.
- `cabal test watcher-core-test`: passed. Final result: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: passed with no output.
- `rg -n '^import[[:space:]]+CodexWatcher\.Core\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`: no matches; command exited 1 as expected for absence.
- `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs`: passed and reported:
  - `34:import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`
  - `35:import CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`
- `rg -n 'CodexWatcher\.Core\.Ids' src app test docs *.cabal agent-workflow-*/*.cabal agent-workflow-*/src || true`: current remaining-facade scan recorded broader compatibility usage outside this selected file, including `moifold.cabal`, `src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/RunnerGuard.hs`, multiple domain/runtime/workflow modules, tests, and compatibility policy docs. `src/CodexWatcher/Cli/Command/RunnerGuard.hs` is no longer listed.

### Notes
Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-159-runner-guard-command-core-ids-split-import-migration`.

Scope stayed limited to the selected production file plus this implementation artifact. I did not edit tests, package descriptors, facade modules, public exports, docs, roadmap status, or `orchestrator/state.json`. This round does not claim deprecation, Cabal exposure removal, facade deletion, milestone completion, terminal completion, release approval, or public compatibility removal.
