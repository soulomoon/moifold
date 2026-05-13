### Changes Made
- `src/CodexWatcher/EffectInterpreter.hs`: replaced the `CodexWatcher.Core.Ids` import for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `RequestId`, `ThreadId`, and `nextRequestId` with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.

### Tests
- No test files changed; this round is an import-only migration.
- `git diff -- src/CodexWatcher/EffectInterpreter.hs`: passed; diff only replaces the `CodexWatcher.Core.Ids` import with direct owner imports.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/EffectInterpreter.hs`: passed; no matches.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged changes were present.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal`: remaining users recorded below.

### Notes
Remaining `CodexWatcher.Core.Ids` users are expected outside this single import-convergence slice:

```text
moifold.cabal:46:    CodexWatcher.Core.Ids
test/FacadeImportPolicySpec.hs:11:import CodexWatcher.Core.Ids
test/WorkflowEventLogSpec.hs:65:import CodexWatcher.Core.Ids
test/RuntimeSpec.hs:30:import CodexWatcher.Core.Ids
test/CliSpec.hs:14:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), ThreadId (..))
src/CodexWatcher/Runtime/Compatibility.hs:14:import CodexWatcher.Core.Ids
test/Main.hs:67:import CodexWatcher.Core.Ids
test/WorkflowIndexedSpec.hs:66:import CodexWatcher.Core.Ids
test/WorkflowAgentSpec.hs:66:import CodexWatcher.Core.Ids
test/WorkflowExecutionSpec.hs:65:import CodexWatcher.Core.Ids
test/RuntimeCompatibilityFixtureSpec.hs:11:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..))
test/TestSupport/Workflow.hs:98:import CodexWatcher.Core.Ids
src/CodexWatcher/GoldenReplay.hs:22:import CodexWatcher.Core.Ids
src/CodexWatcher/Core/Ids.hs:1:module CodexWatcher.Core.Ids
src/CodexWatcher/StateMachine.hs:25:import CodexWatcher.Core.Ids (BranchName (..), CommitSha, IssueNumber (..), PrNumber (..), ReviewThreadId, ThreadId)
src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29:import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
src/CodexWatcher/Healthcheck.hs:32:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..), TurnId (..))
src/CodexWatcher/EventLog/Types.hs:17:import CodexWatcher.Core.Ids
src/CodexWatcher/EventLog/Replay.hs:17:import CodexWatcher.Core.Ids (IssueNumber (..), ThreadId (..), TurnId (..))
src/CodexWatcher/Domain/IssueImplement/Loop.hs:38:import CodexWatcher.Core.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RequestId, ThreadId (..))
docs/agentic-workflow-framework/release-notes.md:98:- `CodexWatcher.Core.Ids` remains a moifold convenience facade over agent and
docs/agentic-workflow-framework/compatibility-deprecation-policy.md:60:  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
docs/agentic-workflow-framework/compatibility-deprecation-policy.md:86:| `agent-workflow-github` | Prefer `CodexWatcher.Workflow.GitHub.Ids`, `CodexWatcher.Workflow.GitHub.Remote`, and `CodexWatcher.Workflow.GitHub.Command`. | `CodexWatcher.Core.Ids` is a moifold convenience facade over agent ids and GitHub ids, not the preferred public import for standalone reusable package consumers. | New reusable GitHub-adapter code should import GitHub modules directly. Existing moifold code may keep using `CodexWatcher.Core.Ids` where the combined id facade is useful. |
docs/agentic-workflow-framework/compatibility-deprecation-policy.md:100:| `CodexWatcher.Core.Ids` | Main-library module reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; round 056 still finds 65 selected-facade imports. | Reusable agent code should import `CodexWatcher.Workflow.Agent.Ids`; reusable GitHub code should import `CodexWatcher.Workflow.GitHub.Ids`. | Existing moifold code may continue using the combined convenience facade. | `defer` | No deprecation or removal until combined-facade users have split-import evidence, behavior checks, and reviewer approval. |
docs/agentic-workflow-framework/release-candidate-bundle.md:70:| Compatibility facade scan | Passed | `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `Workflow.EventLog`, `Workflow.Execution`, and `Workflow.Permission` remain available as moifold-facing compatibility surfaces. |
src/CodexWatcher/Cli/Command/IssueFanout.hs:44:import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
src/CodexWatcher/Cli/Parser/Common.hs:41:import CodexWatcher.Core.Ids
src/CodexWatcher/Cli/Types.hs:22:import CodexWatcher.Core.Ids
```

No function bodies, type definitions, exports, constructors, tests, Cabal files, docs, fixtures, runtime compatibility files, roadmap files, selection, plan, or public `CodexWatcher.Core.Ids` facade were changed.
