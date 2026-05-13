### Goal
Migrate only `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the existing ID types from their direct owner modules, without changing PR-review launch behavior, runtime writes, command rendering, output text, or public compatibility surface availability.

### Approach
Keep this as a one-file, behavior-preserving import convergence slice. Replace the current combined `CodexWatcher.Core.Ids` import with two direct owner imports:

- `CodexWatcher.Workflow.GitHub.Ids` for `BranchName (..)`, `PrNumber (..)`, and `RepoName (..)`.
- `CodexWatcher.Workflow.Agent.Ids` for `RequestId (..)` and `ThreadId (..)`.

Do not change constructors, record fields, helper logic, JSON keys, event construction, thread startup request IDs, runtime-owner handling, compatibility writes, printed messages, package descriptors, tests, docs, or the `CodexWatcher.Core.Ids` facade itself. Public compatibility facades remain exposed under the project contract and active roadmap verification gates.

### Steps
1. Open `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` and locate the existing `CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))` import.
2. Remove only that `CodexWatcher.Core.Ids` import from `LaunchCli.hs`.
3. Add `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), PrNumber (..), RepoName (..))` to provide the PR-review repo, branch, and PR-number identifiers used by the launch plan, config rendering, slug rendering, and handoff messages.
4. Add `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..))` to provide the request and thread identifiers used by launch-plan fields, initial watcher state, app-server thread startup, and `withPrReviewThreadIds`.
5. Leave every expression and type signature in `LaunchCli.hs` unchanged unless the compiler requires import ordering or formatting only.
6. Confirm no other production, test, documentation, package descriptor, roadmap, state, or compatibility file is edited for this round.

### Verification
Run focused and baseline checks appropriate for a production `Core.Ids` import migration:

1. `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs` should return no matches.
2. `rg -n "CodexWatcher\\.Workflow\\.(GitHub|Agent)\\.Ids" src/CodexWatcher/Domain/PrReview/LaunchCli.hs` should show the two direct owner imports.
3. `cabal build all`
4. `cabal test watcher-core-test`
5. `git diff --check`

The reviewer should also inspect the diff and confirm it is import-only in `LaunchCli.hs`, with no behavior, JSON, event, command-rendering, runtime compatibility, public facade, or Cabal exposure changes.

### Worker Fan-Out
Worker fan-out is not justified. This round has a single owned production file, no independent implementation slices, and `max_parallel_rounds: 1`; no `worker-plan.json` should be created.
