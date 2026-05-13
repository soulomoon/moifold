### Changes Made
- `src/CodexWatcher/Effects.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId` and `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, and `ReviewThreadId`.

### Tests
- No tests changed; this round is an import-only migration and preserves all constructors, function bodies, exported names, deriving behavior, action classification, and mutation detection.
- `git diff -- src/CodexWatcher/Effects.hs`: passed; diff shows only the planned import replacement.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Effects.hs`: passed; no matches.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; `1 of 1 test suites (1 of 1 test cases) passed`.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; nothing was staged.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test moifold.cabal agent-workflow-*/*.cabal`: completed; remaining users are expected outside this slice:
  - `moifold.cabal`
  - `test/WorkflowExecutionSpec.hs`
  - `test/FacadeImportPolicySpec.hs`
  - `src/CodexWatcher/EffectInterpreter.hs`
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/TestSupport/Workflow.hs`
  - `test/RuntimeSpec.hs`
  - `test/CliSpec.hs`
  - `test/WorkflowIndexedSpec.hs`
  - `test/Main.hs`
  - `test/RuntimeCompatibilityFixtureSpec.hs`
  - `src/CodexWatcher/EventLog/Types.hs`
  - `src/CodexWatcher/Healthcheck.hs`
  - `src/CodexWatcher/EventLog/Replay.hs`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  - `src/CodexWatcher/Runtime/Compatibility.hs`
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs`
  - `src/CodexWatcher/StateMachine.hs`
  - `src/CodexWatcher/Cli/Types.hs`
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  - `src/CodexWatcher/GoldenReplay.hs`
  - `src/CodexWatcher/Core/Ids.hs`
  - `src/CodexWatcher/Cli/Parser/Common.hs`
  - `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`

### Notes
This is only the `round-173-effects-core-ids-split-import-migration` slice. Remaining `CodexWatcher.Core.Ids` users and the public facade exposure are intentionally unchanged; this round does not imply facade deprecation, Cabal exposure removal, runtime compatibility cleanup, public compatibility removal, or milestone completion.
