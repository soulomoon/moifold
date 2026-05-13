### Changes Made
- `src/CodexWatcher/Cli/Types.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports:
  - `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
  - `CodexWatcher.Workflow.GitHub.Ids (CommitSha, IssueNumber, PrNumber, RepoName, ReviewThreadId)`
- No `BranchName` import was added because `src/CodexWatcher/Cli/Types.hs` does not use `BranchName` at current head.
- The source diff is import-only. No exports, data declarations, record fields, derived instances, `CliDomain`, parser/rendering/option/dry-run/fanout/child-arg code, tests, Cabal, docs, runtime compatibility files, `Cli/Command/IssueFanout.hs`, or orchestrator control files were edited.

### Tests
- No test files changed.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. This compiled and ran the named CLI-related consumers, including `test/CliSpec.hs`, `test/ObserveCommandSpec.hs`, `test/AutomaticLoopRunnerSpec.hs`, `test/AppServerProbeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, and workflow specs importing `CodexWatcher.Cli.Types`.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because `git diff --cached --name-only` returned no staged files.
- Selected-file Core.Ids absence scan:
  - Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Types.hs`
  - Result: no matches.
- Selected-file direct owner import scans:
  - Command: `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/Cli/Types.hs`
  - Result: `22:import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)`
  - Command: `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Cli/Types.hs`
  - Result: `23:import CodexWatcher.Workflow.GitHub.Ids`
- Focused CLI behavior evidence:
  - Inspected `test/Main.hs` and the named CLI-related specs. The test runner is a direct `quickCheckResult` / `IO Bool` sequence rather than a Tasty/Hspec selector tree, so no easy reliable focused selector was discovered.
  - Behavior evidence is the full `watcher-core-test` run plus the import-only diff and the inspected named specs.

### Notes
Broad remaining-user scan command:

`rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`

Remaining production users:
- `src/CodexWatcher/Runtime/Compatibility.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/EventLog/Types.hs`
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`

Remaining tests/test support users:
- `test/FacadeImportPolicySpec.hs`
- `test/WorkflowEventLogSpec.hs`
- `test/RuntimeSpec.hs`
- `test/CliSpec.hs`
- `test/Main.hs`
- `test/WorkflowIndexedSpec.hs`
- `test/WorkflowAgentSpec.hs`
- `test/WorkflowExecutionSpec.hs`
- `test/RuntimeCompatibilityFixtureSpec.hs`
- `test/TestSupport/Workflow.hs`

Docs/Cabal/package-candidate imports:
- No `import CodexWatcher.Core.Ids` matches under `docs`, `*.cabal`, or `agent-workflow-*`.

Public facade:
- `src/CodexWatcher/Core/Ids.hs` remains the public compatibility facade and reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. This round did not deprecate, remove, or alter the facade.

Out-of-scope confirmation:
- `src/CodexWatcher/Cli/Command/IssueFanout.hs` remains an unresolved production CLI `CodexWatcher.Core.Ids` user and was not edited in this round.
