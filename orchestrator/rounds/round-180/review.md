### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. Built and ran `watcher-core-test` with GHC 9.12.2; final result was `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`. The run included CLI-adjacent behavior evidence such as app-server probe, observe, PR review, issue fanout, automatic loop, runtime compatibility, and workflow specs.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: skipped. `git diff --cached --name-only` returned no staged files.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/Cli/Types.hs || true`
  Result: pass. No matches; `src/CodexWatcher/Cli/Types.hs` no longer imports or references `CodexWatcher.Core.Ids`.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids|BranchName|ThreadId|TurnId|CommitSha|IssueNumber|PrNumber|RepoName|ReviewThreadId" src/CodexWatcher/Cli/Types.hs`
  Result: pass. The file imports `CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` at line 22 and `CodexWatcher.Workflow.GitHub.Ids` at line 23 with `CommitSha`, `IssueNumber`, `PrNumber`, `ReviewThreadId`, and `RepoName` on lines 24-28. `BranchName` is absent because the file does not use it.

- Command: `rg -n "import CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* 2>/dev/null || true`
  Result: pass for scope classification. Remaining production imports are `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`. Remaining test/test-support imports are `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowAgentSpec.hs`, `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowIndexedSpec.hs`, and `test/CliSpec.hs`. No `import CodexWatcher.Core.Ids` matches appeared under `docs`, `*.cabal`, or `agent-workflow-*`. The public facade `src/CodexWatcher/Core/Ids.hs` remains present and was not edited.

- Command: `rg -n "CodexWatcher\\.Cli\\.Types" test/CliSpec.hs test/ObserveCommandSpec.hs test/AutomaticLoopRunnerSpec.hs test/AppServerProbeSpec.hs test/RuntimeCompatibilityFixtureSpec.hs test/Workflow*.hs test/TestSupport/Workflow.hs test/Main.hs`
  Result: pass for focused evidence discovery. Consumers include `test/CliSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/ObserveCommandSpec.hs`, `test/WorkflowIndexedSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowDocsMigrationSpec.hs`, `test/Main.hs`, `test/AppServerProbeSpec.hs`, `test/AutomaticLoopRunnerSpec.hs`, and `test/WorkflowAgentSpec.hs`. The suite uses a custom direct runner rather than a reliable focused selector, so focused behavior evidence is the full `watcher-core-test` run plus the import-only diff and these inspected consumers.

- Command: `git diff -- src/CodexWatcher/Cli/Types.hs`
  Result: pass. The implementation diff in `src/CodexWatcher/Cli/Types.hs` is import-only: the `CodexWatcher.Core.Ids` import was replaced with direct owner imports, with no exports, data declarations, record fields, derived instances, `CliDomain`, parser/rendering, option, dry-run, fanout, child-arg, test, Cabal, docs, runtime compatibility, or public facade changes.

### Plan Compliance
- Confirm current `Types.hs` id users: met. The file uses `ThreadId`, `TurnId`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`; `BranchName` is not used.
- Replace only the `CodexWatcher.Core.Ids` import with direct owner imports: met. The direct imports are from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Make no other implementation edits in `Types.hs`: met. The source diff is import-only.
- Do not edit parser or command modules: met. No parser or command module appears in the implementation diff; `src/CodexWatcher/Cli/Command/IssueFanout.hs` remains an out-of-scope production `Core.Ids` user.
- Avoid speculative package dependency changes: met. No package descriptor changed and `cabal build all` passed.
- Preserve compatibility boundaries: met. This round does not deprecate or remove `CodexWatcher.Core.Ids`, does not alter Cabal exposure, docs, runtime compatibility files, event schemas, command rendering, or public facade availability, and does not claim milestone completion or terminal completion.

### Decision
**APPROVED**

### Evidence
The reviewed implementation satisfies `round-180-cli-types-core-ids-split-import-migration`: `src/CodexWatcher/Cli/Types.hs` no longer imports `CodexWatcher.Core.Ids`, uses direct id-owner imports for the actual ids in the file, and does not import unused `BranchName`. The implementation diff is import-only in the selected source file.

`git diff --name-only` also shows a pre-existing `orchestrator/state.json` control-plane activation diff for `round-180`; this review did not edit `state.json`, and that control-plane diff is not part of the implementation surface being approved here.

Baseline validation passed with `cabal build all`, `cabal test watcher-core-test`, and `git diff --check`. There were no staged changes, so cached diff checking was correctly skipped. Remaining `CodexWatcher.Core.Ids` imports are recorded as remaining scope only and separated between production users, tests/test support, docs/Cabal/package candidates, and the public facade. This approval is limited to the round-180 import-only migration and does not approve public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
