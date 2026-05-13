### Changes Made
- `src/CodexWatcher/Domain/PrReview/Loop.hs`: replaced the `CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids (ThreadId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`. No function bodies, exports, error text, tests, package descriptors, roadmap files, or controller state were changed.

### Tests
- No test files changed; this round is an import-owner migration only.
- `cabal build all`: PASS.
- `cabal test watcher-core-test`: PASS, `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: PASS.
- `! rg -n 'import CodexWatcher\.Core\.Ids' src/CodexWatcher/Domain/PrReview/Loop.hs`: PASS, no compatibility-facade import remains in the selected file.
- `rg -n 'import CodexWatcher\.Workflow\.Agent\.Ids \(ThreadId\)' src/CodexWatcher/Domain/PrReview/Loop.hs`: PASS, found `27:import CodexWatcher.Workflow.Agent.Ids (ThreadId)`.
- `rg -n 'import CodexWatcher\.Workflow\.GitHub\.Ids \(CommitSha, PrNumber \(\.\.\)\)' src/CodexWatcher/Domain/PrReview/Loop.hs`: PASS, found `28:import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber (..))`.
- `rg -n 'import CodexWatcher\.Core\.Ids' src app test`: PASS as inventory evidence; remaining out-of-scope users include `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview.hs`, `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, and test/support modules.
- `rg -n '^ *CodexWatcher\.Core\.Ids$' moifold.cabal`: PASS, compatibility facade remains exposed at line 46.
- `rg -n '^ *CodexWatcher\.Workflow\.Agent\.Ids$' agent-workflow-codex/agent-workflow-codex.cabal`: PASS, owner module remains exposed at line 54.
- `rg -n '^ *CodexWatcher\.Workflow\.GitHub\.Ids$' agent-workflow-github/agent-workflow-github.cabal`: PASS, owner module remains exposed at line 48.

### Notes
`git diff --cached --check` was not run because nothing was staged. The worktree had pre-existing orchestrator state/round artifact changes before this implementation; this round only added `implementation-notes.md` and changed the selected production import.
