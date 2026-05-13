### Changes Made
- `src/CodexWatcher/Cli/RuntimeConfig.hs`: replaced the combined `CodexWatcher.Core.Ids (IssueNumber, RepoName, RequestId (..))` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)` and `CodexWatcher.Workflow.Agent.Ids (RequestId (..))`. Function bodies and all existing default runtime config, planner scope, planner instruction, `effectRuntimeRepo`, and `effectRuntimeNextRequestId = RequestId 1` behavior were left unchanged.

### Tests
- No tests were edited; this round is an import-only production migration.
- `cabal build all`: passed. Built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, `moifold` library, and `moifold` executable with GHC 9.12.2. The edited module compiled as `CodexWatcher.Cli.RuntimeConfig`.
- `cabal test watcher-core-test`: passed. Final result: `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: passed with no output.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/RuntimeConfig.hs`: no matches; command exited 1 as expected for absence.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Cli/RuntimeConfig.hs`: passed and reported:
  - `14:import CodexWatcher.Workflow.Agent.Ids (RequestId (..))`
  - `15:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)`
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test *.cabal`: passed and reported the remaining facade users intentionally left out of scope:
  - `moifold.cabal:46:    CodexWatcher.Core.Ids`
  - `src/CodexWatcher/EventLogRepair.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), PrNumber (..), TurnId (..))`
  - `src/CodexWatcher/EffectInterpreter.hs:20:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/RunnerGuard.hs:49:import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`
  - `test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/DaemonLoop/Types.hs:32:import CodexWatcher.Core.Ids (CommitSha, PrNumber, ThreadId, TurnId (..))`
  - `test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids`
  - `test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids`
  - `test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))`
  - `test/Main.hs:67:import CodexWatcher.Core.Ids`
  - `test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/PrReview/Protocol.hs:30:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId, ThreadId, TurnId)`
  - `test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/PrReview/LaunchCli.hs:31:import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))`
  - `src/CodexWatcher/Domain/PrReview/Watcher.hs:21:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), TurnId)`
  - `test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/PrReview/Loop.hs:23:import CodexWatcher.Core.Ids (CommitSha, PrNumber (..), ThreadId)`
  - `test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs:19:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId, TurnId)`
  - `src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)`
  - `test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Effects.hs:22:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, RepoName, ReviewThreadId, ThreadId)`
  - `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs:33:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), ThreadId (..))`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)`
  - `src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs:17:import CodexWatcher.Core.Ids (CommitSha (..), PrNumber, ThreadId)`
  - `src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))`
  - `src/CodexWatcher/Domain/IssueImplement/Watcher.hs:19:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)`
  - `src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Core/Ids.hs:1:module CodexWatcher.Core.Ids`
  - `src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))`
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))`
  - `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs:96:import CodexWatcher.Core.Ids (BranchName, CommitSha, PrNumber, ThreadId, TurnId)`
  - `src/CodexWatcher/Workflow/Moifold/PrReview.hs:17:import CodexWatcher.Core.Ids (CommitSha, ReviewThreadId (..), ThreadId, TurnId)`

### Notes
Roadmap lineage: `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-011-core-ids-import-convergence`, extracted item `round-160-runtime-config-core-ids-split-import-migration`.

Scope stayed limited to the selected production file plus this implementation artifact. I did not edit tests, package descriptors, facade modules, public exports, docs, roadmap status, or `orchestrator/state.json`. This round does not claim deprecation, Cabal exposure removal, facade deletion, milestone completion, terminal completion, release approval, or public compatibility removal.
