### Changes Made
- `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`: replaced the combined `CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)` compatibility-facade import with direct owner imports:
  - `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
  - `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`
- No function bodies, export list entries, data declarations, planning-graph validation logic, issue-number rendering, `selectIssueImplementationStarts` behavior, or error text were changed.
- No tests, package descriptors, compatibility facades, roadmap status files, or controller state were intentionally edited.

### Tests
- `cabal build all`: PASS. Built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold` library, and `moifold` executable successfully.
- `cabal test watcher-core-test`: PASS. Final result: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.` Log: `dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/test/moifold-0.1.0.0-watcher-core-test.log`.
- `git diff --check`: PASS, no output.
- `git diff --cached --check`: PASS, no output. No staged changes were involved, but the cached check was run.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`: PASS, no matches. `rg` exited 1 because the target string is absent.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`: PASS:
  - `32:import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
  - `33:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))`
- `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs moifold.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github examples`: PASS. The scan did not list `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`; remaining users intentionally left untouched by this round:
  - `test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/EffectInterpreter.hs:20:import CodexWatcher.Core.Ids`
  - `test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/RunnerGuard.hs:49:import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`
  - `test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids`
  - `test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))`
  - `src/CodexWatcher/DaemonLoop/Types.hs:32:import CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))`
  - `test/Main.hs:67:import CodexWatcher.Core.Ids`
  - `test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids`
  - `test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids`
  - `test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids`
  - `test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/PrReview/Protocol.hs:30:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)`
  - `test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Effects.hs:22:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)`
  - `src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)`
  - `src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/PrReview/LaunchCli.hs:31:import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))`
  - `src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs:17:import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)`
  - `src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/EventLogRepair.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))`
  - `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs:33:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))`
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))`
  - `src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Domain/IssueImplement/Watcher.hs:19:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)`
  - `src/CodexWatcher/Domain/PrReview/Loop.hs:23:import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)`
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))`
  - `src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Workflow/Moifold/PrReview.hs:17:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)`
  - `src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs:96:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)`

### Notes
The implementation diff for `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` is import-only. The broader worktree already showed controller/round artifact changes before implementation (`orchestrator/state.json` modified and `orchestrator/rounds/round-162/` untracked); this round only adds `implementation-notes.md` under the round artifact directory and changes the scoped production file.
