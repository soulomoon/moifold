### Changes Made
- `src/CodexWatcher/EventLogRepair.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber` and `PrNumber`, and `CodexWatcher.Workflow.Agent.Ids` for `TurnId`. No function bodies, exports, event constructors, replay validation, error text, tests, package descriptors, roadmap files, or controller state were changed.

### Tests
- No tests were added or modified. This round is an import-only migration with behavior covered by the existing build and `watcher-core-test` suite.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not run because nothing was staged.

### Notes
Focused import scans from the plan:

```text
$ rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EventLogRepair.hs
<no matches; exit 1>

$ rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(IssueNumber \\(\\.\\.\\), PrNumber \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs
20:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))

$ rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids \\(TurnId \\(\\.\\.\\)\\)" src/CodexWatcher/EventLogRepair.hs
19:import CodexWatcher.Workflow.Agent.Ids (TurnId (..))
```

Remaining `CodexWatcher.Core.Ids` users, recorded without expanding scope:

```text
moifold.cabal:46:    CodexWatcher.Core.Ids
test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids
test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids
test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids
test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))
test/Main.hs:67:import CodexWatcher.Core.Ids
test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids
test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids
src/CodexWatcher/EffectInterpreter.hs:20:import CodexWatcher.Core.Ids
test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids
src/CodexWatcher/DaemonLoop/Types.hs:32:import CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))
test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids
test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))
src/CodexWatcher/RunnerGuard.hs:49:import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids
src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Effects.hs:22:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)
src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/Domain/PrReview/LaunchCli.hs:31:import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs:17:import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)
src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids
src/CodexWatcher/Domain/IssueImplement/Watcher.hs:19:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/Core/Ids.hs:1:module CodexWatcher.Core.Ids
src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))
src/CodexWatcher/Domain/PrReview/Loop.hs:23:import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)
src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs:96:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)
src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids
src/CodexWatcher/Workflow/Moifold/PrReview.hs:17:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)
src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/IssuePlanning/Fanout.hs:33:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))
src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
```

Package exposure scans:

```text
$ rg -n "CodexWatcher\\.Core\\.Ids" moifold.cabal
46:    CodexWatcher.Core.Ids

$ rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" agent-workflow-github/agent-workflow-github.cabal
48:    CodexWatcher.Workflow.GitHub.Ids

$ rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" agent-workflow-codex/agent-workflow-codex.cabal
54:    CodexWatcher.Workflow.Agent.Ids
```

Manual diff review: the production diff is import-only in `src/CodexWatcher/EventLogRepair.hs`; no event schema, golden fixture, runtime compatibility file, public facade, or Cabal exposure changed.
