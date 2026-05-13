### Goal
Move `src/CodexWatcher/Cli/RuntimeConfig.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade and onto the direct owner ID modules for the types it already uses, without changing runtime behavior.

### Approach
Keep this as a sequential one-file import migration. Replace the current `CodexWatcher.Core.Ids (IssueNumber, RepoName, RequestId (..))` import with direct imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..))`.

Do not change function bodies, exported functions, default runtime configuration, planner-scope behavior, thread instruction construction, or `effectRuntimeNextRequestId = RequestId 1`. Do not edit tests, Cabal files, public compatibility facades, runtime compatibility files, docs, roadmap state, or any broader `Core.Ids` users. Shared invariants remain governed by `orchestrator/project-contract.md`, especially package-boundary ownership and the rule that import convergence is not deprecation or removal approval.

Worker fan-out is not justified: the selected work is a single production module with one import replacement and no independent ownership boundary.

### Steps
1. In `src/CodexWatcher/Cli/RuntimeConfig.hs`, replace the single `CodexWatcher.Core.Ids (IssueNumber, RepoName, RequestId (..))` import with direct owner imports:
   - `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)`
   - `CodexWatcher.Workflow.Agent.Ids (RequestId (..))`
2. Preserve the rest of `RuntimeConfig.hs` byte-for-byte where practical, including `defaultEffectRuntimeConfig`, `defaultEffectRuntimeConfigWithPlannerScope`, `plannerTurnInputForScope` usage, `issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues`, `effectRuntimeRepo = repo`, and `effectRuntimeNextRequestId = RequestId 1`.
3. Do not follow adjacent `CodexWatcher.Core.Ids` imports in other modules during this round. If the build reveals an unexpected package-boundary or visibility issue, record that as implementation evidence instead of widening the scope.
4. Record in the implementation notes that this round preserves the public `CodexWatcher.Core.Ids` facade and only removes this one production importer from it.

### Verification
Run the roadmap baseline for a production-code import migration:

1. `cabal build all`
2. `cabal test watcher-core-test`
3. `git diff --check`

Also run focused import evidence:

1. `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/RuntimeConfig.hs` should return no matches.
2. `rg -n "CodexWatcher\\.Core\\.Ids" src app test *.cabal` should be captured in the implementation notes to show remaining facade users and confirm they were left intentionally out of scope.
