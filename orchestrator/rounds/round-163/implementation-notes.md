### Changes Made
- `src/CodexWatcher/Domain/PrReview/Protocol.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)`.

### Tests
- No test files changed; this round is an import-only migration with behavior covered by the existing build and `watcher-core-test` suite.
- `cabal build all`: PASS.
- `cabal test watcher-core-test`: PASS. Cabal reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: PASS.

### Notes
Source diff review: `src/CodexWatcher/Domain/PrReview/Protocol.hs` changed only the import block. `WorkerSession`, `ReviewerSession`, `WorkerOutcome`, `ReviewerOutcome`, turn-start/wait/emit helpers, protocol runners, and event construction were not changed.

Focused import scans:

```text
$ rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs
<no matches>

$ rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids|CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Domain/PrReview/Protocol.hs
33:import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)
34:import CodexWatcher.Workflow.GitHub.Ids (CommitSha, ReviewThreadId)
```

Remaining `CodexWatcher.Core.Ids` import users after this round:

```text
test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids
src/CodexWatcher/EffectInterpreter.hs:20:import CodexWatcher.Core.Ids
test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids
src/CodexWatcher/RunnerGuard.hs:49:import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/DaemonLoop/Types.hs:32:import CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))
test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids
test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))
test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids
test/Main.hs:67:import CodexWatcher.Core.Ids
src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids
test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids
test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids
test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids
test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/PrReview/LaunchCli.hs:31:import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
src/CodexWatcher/Effects.hs:22:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)
src/CodexWatcher/Domain/PrReview/Loop.hs:23:import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)
src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids
src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs:17:import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)
src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))
src/CodexWatcher/EventLogRepair.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))
src/CodexWatcher/Domain/IssueImplement/Watcher.hs:19:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
src/CodexWatcher/Domain/IssuePlanning/Fanout.hs:33:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))
src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Workflow/Moifold/PrReview.hs:17:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)
src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs:96:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids
```

Package exposure scan:

```text
$ rg -n "CodexWatcher\\.Core\\.Ids|CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal
agent-workflow-github/agent-workflow-github.cabal:48:    CodexWatcher.Workflow.GitHub.Ids
agent-workflow-codex/agent-workflow-codex.cabal:54:    CodexWatcher.Workflow.Agent.Ids
moifold.cabal:46:    CodexWatcher.Core.Ids
```

No files were staged.
