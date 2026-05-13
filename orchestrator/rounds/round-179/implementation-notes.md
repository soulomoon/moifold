### Changes Made
- `src/CodexWatcher/Cli/Parser/Common.hs`: replaced the `CodexWatcher.Core.Ids` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`/`TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for `IssueNumber`/`RepoName`/`ReviewThreadId`.
- No parser exports, helper bodies, option/help/metavar/default/error text, CLI types, issue fanout code, tests, Cabal files, docs, runtime compatibility files, roadmap files, `selection.md`, or `plan.md` were edited by this implementation.

### Tests
- No tests were added or edited. This round is an import-only migration.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed. Log: `dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/test/moifold-0.1.0.0-watcher-core-test.log`.
- `git diff --check`: passed.
- `git diff --cached --check`: skipped because `git diff --cached --quiet` showed no staged changes.
- Focused CLI parser evidence: `test/CliSpec.hs` contains parser coverage for `parseCliCommand`, including repo parsing, thread id parsing, planner thread parsing, scope issue parsing, healthcheck, and run-loop parser results. No reliable focused selector was discoverable because `watcher-core-test` uses a custom `test/Main.hs` runner; behavior evidence is the full `cabal test watcher-core-test` run plus the import-only diff.

### Notes
- Local diff review: `git diff --numstat -- src/CodexWatcher/Cli/Parser/Common.hs` reported `2	7	src/CodexWatcher/Cli/Parser/Common.hs`, and the source diff only removes the old `CodexWatcher.Core.Ids` import and adds the two direct owner imports.
- Selected-file `Core.Ids` scan: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs` returned no matches.
- Selected-file direct owner scans:
  - `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs` returned `50:import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`.
  - `rg -n "CodexWatcher\\.Workflow\\.GitHub\\.Ids" src/CodexWatcher/Cli/Parser/Common.hs` returned `51:import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), RepoName (..), ReviewThreadId (..))`.
- Broad remaining-user scan command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`.
- Remaining production users:
  - `src/CodexWatcher/EventLog/Types.hs`
  - `src/CodexWatcher/Runtime/Compatibility.hs`
  - `src/CodexWatcher/Healthcheck.hs`
  - `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
  - `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
  - `src/CodexWatcher/Cli/Command/IssueFanout.hs`
  - `src/CodexWatcher/Cli/Types.hs`
- Remaining tests/fixtures users:
  - `test/WorkflowExecutionSpec.hs`
  - `test/FacadeImportPolicySpec.hs`
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/RuntimeSpec.hs`
  - `test/TestSupport/Workflow.hs`
  - `test/RuntimeCompatibilityFixtureSpec.hs`
  - `test/WorkflowIndexedSpec.hs`
  - `test/Main.hs`
  - `test/CliSpec.hs`
- Remaining docs/Cabal/package-candidate users: none reported by the broad scan.
- Public facade module remains intentionally untouched: `src/CodexWatcher/Core/Ids.hs` still re-exports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Existing unrelated worktree state observed and preserved: `orchestrator/state.json` was already modified, and the round artifact directory already contained `selection.md` and `plan.md`.
