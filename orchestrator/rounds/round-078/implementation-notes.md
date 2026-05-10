### Changes Made
- Starting import scan:
  - `CodexWatcher.Core.Ids` imports: 65
  - Direct owner imports: 12
- Final import scan:
  - `CodexWatcher.Core.Ids` imports: 35
  - Direct owner imports: 42
- Agent-id-only callers now import `CodexWatcher.Workflow.Agent.Ids`:
  - `src/CodexWatcher/AutomaticLoop/Runner.hs`: `ThreadId`
  - `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`: `RequestId`, `ThreadId`, `nextRequestId`
  - `src/CodexWatcher/Cli/Command/AppServerProbe.hs`: `RequestId`, `unThreadId`, `unTurnId`
  - `src/CodexWatcher/Core/Thread.hs`: `ThreadId`, `TurnId`
  - `src/CodexWatcher/DaemonLoop.hs`: `ThreadId`
  - `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`: `ThreadId`, `TurnId`
  - `src/CodexWatcher/DaemonLoop/TurnStart.hs`: `RequestId`, `ThreadId`, `TurnId`
  - `src/CodexWatcher/Runtime/Defaults.hs`: `ThreadId`
  - `src/CodexWatcher/Workflow/DocsMigration.hs`: `ThreadId`, `TurnId`
  - `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`: `ThreadId`, `TurnId`
  - `test/AppServerSpec.hs`: `RequestId`, `ThreadId`, `TurnId`
- GitHub-id-only callers now import `CodexWatcher.Workflow.GitHub.Ids`:
  - `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`: `IssueNumber`
  - `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`: `PrNumber`
  - `src/CodexWatcher/Cli/Command/Service.hs`: `RepoName`
  - `src/CodexWatcher/Daemon.hs`: `CommitSha`
  - `src/CodexWatcher/Domain/IssueImplement/Types.hs`: `BranchName`, `IssueNumber`, `RepoName`
  - `src/CodexWatcher/Domain/IssuePlanning/Graph/Canonical.hs`: `IssueNumber`
  - `src/CodexWatcher/Domain/IssuePlanning/Scope.hs`: `IssueNumber`
  - `src/CodexWatcher/Domain/IssuePlanning/Types.hs`: `IssueNumber`, `RepoName`
  - `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`: `CommitSha`, `ReviewThreadId`
  - `src/CodexWatcher/Domain/PrReview/Types.hs`: `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, `ReviewThreadId`
  - `src/CodexWatcher/GhGit.hs`: `BranchName`, `IssueNumber`, `PrNumber`, `RepoName`
  - `src/CodexWatcher/IssueText.hs`: `IssueNumber`
  - `src/CodexWatcher/Runtime/Command/Render.hs`: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`
  - `src/CodexWatcher/Runtime/Command/Types.hs`: `BranchName`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`
  - `src/CodexWatcher/TurnOutput.hs`: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`
  - `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`: `CommitSha`
  - `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability.hs`: `CommitSha`
  - `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`: `CommitSha`
  - `test/GhGitSpec.hs`: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `ReviewThreadId`

### Tests
- `test/AppServerSpec.hs`: import-only migration to `CodexWatcher.Workflow.Agent.Ids`; existing properties still cover request ids, thread ids, turn ids, parser behavior, and request-id/session behavior.
- `test/GhGitSpec.hs`: import-only migration to `CodexWatcher.Workflow.GitHub.Ids`; existing tests still cover branch names, commit shas, issue numbers, PR numbers, and review thread ids.
- Validation commands:
  - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`: passed; final count 35.
  - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`: passed; final count 42.
  - `cabal test watcher-core-test`: passed on final tree.
  - `cabal build all`: passed on final tree.
  - `git diff --check`: passed.

### Notes
Remaining `CodexWatcher.Core.Ids` callers are intentionally left on the combined facade.

Legitimate mixed agent/GitHub callers:
- `src/CodexWatcher/DaemonLoop/Types.hs`
- `src/CodexWatcher/Core/State.hs`
- `src/CodexWatcher/Effects.hs`
- `src/CodexWatcher/StateMachine.hs`
- `src/CodexWatcher/Domain/PrReview/Protocol.hs`
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- `src/CodexWatcher/Domain/PrReview/Loop.hs`
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
- `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
- `src/CodexWatcher/Domain/PrReview/Watcher.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
- `src/CodexWatcher/Cli/Parser/Observe.hs`
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `src/CodexWatcher/Cli/RuntimeConfig.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview.hs`
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`

Deferred or out-of-scope facade users:
- `app/Main.hs`: GitHub-id-only by usage, but direct import failed `cabal build all` because the executable cannot see hidden package `agent-workflow-github` without a package descriptor change, which is out of scope. Left on `CodexWatcher.Core.Ids`.
- `src/CodexWatcher/Workflow/Execution.hs`: selected boundary explicitly defers this module.
- `src/CodexWatcher/EventLogRepair.hs`, `src/CodexWatcher/GoldenReplay.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/EventLog/Replay.hs`: event-log, repair, golden, or schema-adjacent surfaces are out of scope.
- `src/CodexWatcher/Runtime/Compatibility.hs`: runtime compatibility surface is out of scope.
- `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/Cli/Command/RunnerGuard.hs`: healthcheck/guard surfaces are out of scope for this round.
- `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`: broad compatibility users deferred for a later focused split or keep/defer decision.

Tests still compiling through the facade:
- `test/RuntimeSpec.hs`
- `test/CliSpec.hs`
- `test/Main.hs`

Out-of-scope surfaces confirmed untouched:
- No diff to `src/CodexWatcher/Core/Ids.hs`, `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs`, or `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`.
- No package descriptor, docs, README, deprecation, Cabal exposure, public API, facade removal, runtime compatibility-file, healthcheck, repair, parser/renderer implementation, command-output implementation, event-schema, `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Permission`, `CodexWatcher.Workflow.Types`, or `CodexWatcher.Workflow.Execution` changes.
- `orchestrator/state.json` was not edited.
