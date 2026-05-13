### Goal
Migrate `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing its existing ID types from their direct owner modules, while preserving issue-planning fanout behavior and compatibility writes.

### Approach
Keep this as a one-file import migration. `BranchName`, `IssueNumber`, and `RepoName` should come from `CodexWatcher.Workflow.GitHub.Ids`; `ThreadId` should come from `CodexWatcher.Workflow.Agent.Ids`. Do not change constructors, field accessors, data flow, launch planning, rendered commands, JSON config shape, state-directory rendering, compatibility writes, or any public compatibility facade exposure.

This round should not attempt broader `Core.Ids` convergence, package descriptor cleanup, facade deletion, deprecation, docs edits, test restructuring, runtime compatibility cleanup, or roadmap/state changes.

### Steps
1. Open `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` and replace the current `CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))` import with two direct owner imports:
   - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), RepoName (..))`
   - `CodexWatcher.Workflow.Agent.Ids (ThreadId (..))`
2. Leave all type uses, constructors, record fields, parser logic, slug rendering, config JSON rendering, workdir command rendering, and compatibility-write construction unchanged.
3. Confirm the file no longer imports `CodexWatcher.Core.Ids`.
4. Inspect the resulting diff and verify it is limited to the import lines in `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`.

### Verification
Run focused checks for this import-only production change:

1. `git diff -- src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
2. `rg -n "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
3. `cabal build all`
4. `cabal test watcher-core-test`
5. `git diff --check`

Record in implementation notes whether the `rg` command returns no matches for the selected file, and record any remaining validation limits if the full baseline commands cannot be completed.
