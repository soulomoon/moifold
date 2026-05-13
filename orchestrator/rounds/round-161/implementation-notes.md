### Changes Made
- `src/CodexWatcher/Domain/PrReview/Watcher.hs`: replaced the `CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids (TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))`. No export list, data declaration, pattern match, function body, event constructor, or missing-thread error text was changed.
- `orchestrator/rounds/round-161/implementation-notes.md`: recorded the round-161 implementation and verification evidence.

### Tests
- No test files were changed.
- `cabal build all`: PASS, exit 0. Built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold`, and executable `moifold`; `CodexWatcher.Domain.PrReview.Watcher` compiled successfully.
- `cabal test watcher-core-test`: PASS, exit 0. Result ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: PASS, exit 0, no output.
- `git diff --cached --check`: PASS, exit 0, no output. No staging was performed.
- `rg -n "CodexWatcher.Core.Ids" src/CodexWatcher/Domain/PrReview/Watcher.hs`: expected no matches, exit 1, no output.
- `rg -n "CodexWatcher.Workflow.(GitHub|Agent).Ids" src/CodexWatcher/Domain/PrReview/Watcher.hs`: PASS, exit 0:

```text
40:import CodexWatcher.Workflow.Agent.Ids (TurnId)
41:import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId (..))
```

- `rg -n "CodexWatcher.Core.Ids" src app test -g '*.hs'`: PASS, exit 0. Remaining matches are outside round-161 scope and were intentionally left untouched:

```text
test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids
test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids
src/CodexWatcher/EffectInterpreter.hs:20:import CodexWatcher.Core.Ids
test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids
src/CodexWatcher/DaemonLoop/Types.hs:32:import CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))
test/Main.hs:67:import CodexWatcher.Core.Ids
test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))
test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids
src/CodexWatcher/EventLogRepair.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))
test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids
test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))
test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids
test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids
src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/RunnerGuard.hs:49:import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
src/CodexWatcher/Core/Ids.hs:1:module CodexWatcher.Core.Ids
src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/Domain/PrReview/Protocol.hs:30:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)
src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids
src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids
src/CodexWatcher/Workflow/Moifold/PrReview.hs:17:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)
src/CodexWatcher/Domain/PrReview/LaunchCli.hs:31:import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs:96:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/Domain/PrReview/Loop.hs:23:import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)
src/CodexWatcher/Effects.hs:22:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)
src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs:17:import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)
src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids
src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))
src/CodexWatcher/Domain/IssueImplement/Watcher.hs:19:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/Domain/IssuePlanning/Watcher.hs:19:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)
src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
src/CodexWatcher/Domain/IssuePlanning/Fanout.hs:33:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))
```

### Notes
Only the selected import in `src/CodexWatcher/Domain/PrReview/Watcher.hs` was migrated. Public compatibility facades, package descriptors, tests, roadmap files, controller state, and all other `CodexWatcher.Core.Ids` users were left untouched. No review, merge, commit, or staging was performed.
