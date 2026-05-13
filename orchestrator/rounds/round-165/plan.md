### Goal
Migrate `src/CodexWatcher/Domain/PrReview/Loop.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing the exact ID types from their owner modules, while preserving the existing PR-review loop behavior and leaving public compatibility surfaces exposed.

### Approach
Make a single production edit in `src/CodexWatcher/Domain/PrReview/Loop.hs`: replace `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` with `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))` and `CodexWatcher.Workflow.Agent.Ids (ThreadId)`.

Do not change function bodies, type signatures beyond import resolution, review-target loading, review-thread observation, pre-merge gate handling, mergeability waiting, PR number rendering, or any existing error text. Do not edit other `Core.Ids` users, package descriptors, tests, docs, roadmap state, or compatibility facade modules. This is a sequential one-file import migration, so worker fan-out is not justified and no `worker-plan.json` should be created.

### Steps
1. Open `src/CodexWatcher/Domain/PrReview/Loop.hs` and locate the existing `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` import.
2. Replace that single import with:
   - `CodexWatcher.Workflow.Agent.Ids (ThreadId)`
   - `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`
3. Leave all function bodies and all other imports unchanged unless formatting requires only import ordering adjustment.
4. Confirm `Loop.hs` still contains the same PR-review loop code paths for review-target loading, review-thread observation, pre-merge gate handling, mergeability waiting, and PR number rendering.
5. Do not stage or edit roadmap/controller state unless the controller explicitly assigns that later.

### Verification
Run the baseline checks from the active roadmap verification contract:

```sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If staging is involved, also run:

```sh
git diff --cached --check
```

Run focused import scans proving the selected file no longer imports the compatibility facade and now imports the owner modules:

```sh
! rg -n 'import CodexWatcher\.Core\.Ids' src/CodexWatcher/Domain/PrReview/Loop.hs
rg -n 'import CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId\)' src/CodexWatcher/Domain/PrReview/Loop.hs
rg -n 'import CodexWatcher\.Workflow\.GitHub\.Ids \(CommitSha, PrNumber \(\.\.\)\)' src/CodexWatcher/Domain/PrReview/Loop.hs
```

Record the remaining `Core.Ids` users as follow-up evidence without changing them:

```sh
rg -n 'import CodexWatcher\.Core\.Ids' src app test
```

Prove package exposure remains unchanged for the compatibility facade and owner modules:

```sh
rg -n '^ *CodexWatcher\.Core\.Ids$' moifold.cabal
rg -n '^ *CodexWatcher\.Workflow\.Agent\.Ids$' agent-workflow-codex/agent-workflow-codex.cabal
rg -n '^ *CodexWatcher\.Workflow\.GitHub\.Ids$' agent-workflow-github/agent-workflow-github.cabal
```
