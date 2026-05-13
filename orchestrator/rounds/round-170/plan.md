### Goal
Migrate `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` away from the `CodexWatcher.Core.Ids` compatibility facade by importing the existing identifier types from their direct owner modules, without changing issue-implementation watcher behavior.

### Approach
This is a single-file production import-convergence slice under roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`. Keep the change limited to imports in `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`: GitHub-owned identifiers come from `CodexWatcher.Workflow.GitHub.Ids`, and agent-owned identifiers come from `CodexWatcher.Workflow.Agent.Ids`.

Do not alter observation constructors, state-machine transitions, event construction, error text, exports, package descriptors, public compatibility facades, or any runtime compatibility surface. `CodexWatcher.Core.Ids` must remain available and exposed; this round only removes this module's direct dependency on that facade.

### Steps
1. Open `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` and confirm the only `CodexWatcher.Core.Ids` import lists `BranchName`, `CommitSha`, `PrNumber`, `ThreadId`, and `TurnId`.
2. Replace that import with `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, PrNumber)` and `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`.
3. Leave all declarations and function bodies unchanged, including every `IssueImplementObservation` constructor, `issueImplementObserve` branch, `WatcherEvent` constructor, `EffectPlan`, and `StateMachine` decision.
4. Search the edited file for `CodexWatcher.Core.Ids` and confirm there is no remaining import from the compatibility facade in this file.
5. Review the diff and confirm the only production code change is the import-owner migration in `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`.

### Verification
Run the focused and baseline checks for this production import migration:

1. `rg "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
   - Expected: no matches.
2. `cabal build all`
   - Expected: succeeds, proving the direct owner imports are available across the package set.
3. `cabal test watcher-core-test`
   - Expected: succeeds, preserving issue-implementation watcher behavior and shared contracts.
4. `git diff --check`
   - Expected: succeeds.

If staging is performed later by another role, also run `git diff --cached --check` before commit or merge.
