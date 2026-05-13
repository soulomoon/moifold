### Changes Made
- `src/CodexWatcher/Runtime/Compatibility.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`/`TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`/`CommitSha`/`IssueNumber`/`PrNumber`/`RepoName`/`ReviewThreadId`.
- No runtime compatibility behavior changed: the diff is import-only, and `CompatibilityWrite`, `writeCompatibility`, `compatibilityStateWrites`, JSON fields, file names, write paths, and helper functions are unchanged.

### Tests
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. The run compiled and executed `RuntimeSpec`, `RuntimeCompatibilityFixtureSpec`, and `HealthcheckSpec`; the output included runtime compatibility fixture checks for current fixture JSON shapes, planner/planning state split, daemon-state and block-state interactions, repair rewrite order, `writeCompatibilityFiles` separation, healthcheck reader/non-reader contracts, runtime-owner mapping, issue-snapshot writer/non-reader contracts, and runtime state behavior.
- `git diff --check`: passed.
- Selected-file no-`Core.Ids` scan: `rg -n "import CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs` returned no matches.
- Selected-file direct-owner scan: `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" src/CodexWatcher/Runtime/Compatibility.hs` found `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Broad remaining `Core.Ids` import scan: remaining production users are `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, and `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`. Remaining test/test-support users are `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/TestSupport/Workflow.hs`, and `test/RuntimeCompatibilityFixtureSpec.hs`. No docs, Cabal/package descriptor, standalone package-candidate, or public-facade-module import matches appeared in the requested broad scan.

### Notes
No split blocker was found. `src/CodexWatcher/Core/Ids.hs` is a re-export facade for `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`, so the selected file can safely import the direct owners without widening scope.
