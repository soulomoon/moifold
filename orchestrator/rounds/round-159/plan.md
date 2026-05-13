### Goal
Migrate only `src/CodexWatcher/Cli/Command/RunnerGuard.hs` away from the combined `CodexWatcher.Core.Ids` compatibility facade by importing its existing identifiers from their direct owner modules, while preserving runner-guard command rendering and repair-thread reporting behavior.

Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-159-runner-guard-command-core-ids-split-import-migration`.

### Approach
Keep this as a serial one-file production import migration. Worker fan-out is not justified because the selected ownership surface is a single module with one import-list change and no separable integration boundary.

Replace the current `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` import with:

- `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`
- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`

Do not change any function bodies, CLI rendering, repair-thread behavior, tests, package descriptors, facade modules, public exports, docs, roadmap status, or compatibility policy. `unRepoName`, `unThreadId`, and `unTurnId` should remain available through the imported constructors/accessors from the direct owner modules.

### Steps
1. Edit `src/CodexWatcher/Cli/Command/RunnerGuard.hs` only.
2. Remove the `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..))` import.
3. Add `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.
4. Add `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`.
5. Leave all existing uses of `RepoName`, `unRepoName`, `ThreadId`, `unThreadId`, `TurnId`, and `unTurnId` unchanged.
6. Confirm no accidental edits occurred outside `src/CodexWatcher/Cli/Command/RunnerGuard.hs` and the expected round implementation artifact.
7. Do not create `worker-plan.json`.

### Verification
Run the active roadmap baseline checks for a production-code import migration:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

Record focused import-convergence evidence:

1. `rg -n '^import[[:space:]]+CodexWatcher\.Core\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs` should produce no matches.
2. `rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids' src/CodexWatcher/Cli/Command/RunnerGuard.hs` should show the new direct owner imports.
3. Run a current remaining-facade scan over `src`, `app`, `test`, package descriptors, docs, and standalone package candidates, and record that this round removes only the selected `RunnerGuard.hs` command-module facade import while broader `CodexWatcher.Core.Ids` compatibility surfaces remain available for later reviewed gates.

Reviewer boundary checks:

1. Confirm behavior-facing code is unchanged except for imports.
2. Confirm `CodexWatcher.Core.Ids` remains exposed and unmodified.
3. Confirm the round does not claim deprecation, Cabal exposure removal, facade deletion, milestone completion, terminal completion, release approval, or public compatibility removal.
