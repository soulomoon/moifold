### Changes Made
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import for `BranchName`, `CommitSha`, `PrNumber`, `ThreadId`, and `TurnId` with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` and `CodexWatcher.Workflow.Agent.Ids`.
- `orchestrator/rounds/round-174/implementation-notes.md`: recorded the scoped implementation and verification results for round 174.

### Tests
- No test files changed; this round is an import-only migration.
- `git diff -- src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: shows only the requested import replacement.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`: no matches.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; 1 of 1 test suites passed.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because there are no staged changes.

### Notes
Remaining `CodexWatcher.Core.Ids` users from `rg -n "CodexWatcher\\.Core\\.Ids" src app test moifold.cabal` are intentionally out of scope for this slice:

- `moifold.cabal:46`
- `src/CodexWatcher/Core/Ids.hs:1`
- `src/CodexWatcher/EffectInterpreter.hs:20`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs:29`
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs:38`
- `src/CodexWatcher/GoldenReplay.hs:22`
- `src/CodexWatcher/EventLog/Types.hs:17`
- `src/CodexWatcher/EventLog/Replay.hs:17`
- `src/CodexWatcher/Healthcheck.hs:32`
- `src/CodexWatcher/StateMachine.hs:25`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs:44`
- `src/CodexWatcher/Runtime/Compatibility.hs:14`
- `src/CodexWatcher/Cli/Parser/Common.hs:41`
- `src/CodexWatcher/Cli/Types.hs:22`
- `test/RuntimeCompatibilityFixtureSpec.hs:11`
- `test/WorkflowExecutionSpec.hs:65`
- `test/WorkflowEventLogSpec.hs:65`
- `test/RuntimeSpec.hs:30`
- `test/CliSpec.hs:14`
- `test/FacadeImportPolicySpec.hs:11`
- `test/WorkflowAgentSpec.hs:66`
- `test/TestSupport/Workflow.hs:98`
- `test/Main.hs:67`
- `test/WorkflowIndexedSpec.hs:66`

The public `CodexWatcher.Core.Ids` facade remains exposed, and no indexed state/effect/event/observation types, projections, transition helpers, constructors, deriving clauses, function bodies, tests, Cabal files, docs, fixtures, runtime compatibility files, roadmap files, selection, or plan files were changed.
