### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite passed: `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass. No whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass. No staged changes were present and no whitespace errors were reported.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowIndexedSpec.hs`
  Result: pass. No matches; `test/WorkflowIndexedSpec.hs` no longer imports the compatibility facade.

- Command: `rg -n "CodexWatcher.Workflow.Agent.Ids|CodexWatcher.Workflow.GitHub.Ids" test/WorkflowIndexedSpec.hs`
  Result: pass. Direct imports are present:
  - `79:import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))`
  - `89:import CodexWatcher.Workflow.GitHub.Ids`

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. `test/WorkflowIndexedSpec.hs` is absent. Remaining matches are out-of-scope categories for this round:
  - Cabal/public facade exposure: `moifold.cabal`
  - Public facade module: `src/CodexWatcher/Core/Ids.hs`
  - Policy/aggregator coverage: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`
  - Runtime/CLI tests: `test/RuntimeSpec.hs`, `test/CliSpec.hs`
  - Runtime compatibility fixture coverage: `test/RuntimeCompatibilityFixtureSpec.hs`
  - Docs/public compatibility policy: files under `docs/agentic-workflow-framework/`

- Command: `git diff -- test/WorkflowIndexedSpec.hs`
  Result: pass. The selected-file diff is import-only: one `CodexWatcher.Core.Ids` import was removed and direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` were added.

- Command: `git diff -- orchestrator/state.json`
  Result: pass for review context. The state diff records active round `round-191`, stage `review`, roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-002`, and the selected item metadata. It does not change implementation behavior.

### Plan Compliance
- Edit `test/WorkflowIndexedSpec.hs` only in the import section: met. The selected-file diff only changes imports.
- Remove `import CodexWatcher.Core.Ids`: met. The selected-file scan has no matches.
- Add direct `CodexWatcher.Workflow.Agent.Ids` import for `RequestId`, `ThreadId`, and `TurnId`: met. The import is present on line 79.
- Add direct `CodexWatcher.Workflow.GitHub.Ids` import for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId`: met. The import is present starting on line 89.
- Leave test bodies, fixture literals, `workflowIndexedTests`, assertion text, PASS labels, indexed projection checks, event/replay checks, and daemon/runtime command expectations unchanged: met. The diff is import-only, and `watcher-core-test` passed.
- Do not migrate runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal exposure, public facade removal, runtime compatibility files, fixture data, milestone completion, or roadmap/state behavior as implementation: met. Broad scan classifies remaining users as out-of-scope, and no behavior-bearing file outside `test/WorkflowIndexedSpec.hs` was changed by the implementation diff.
- Record remaining facade imports elsewhere as out-of-scope users: met. Remaining users are listed in the broad scan evidence above.

### Decision
**APPROVED**

### Evidence
The active round state and selection agree on roadmap id `2026-05-11-00-highest-value-cleanup`, revision `rev-002`, milestone `milestone-004-core-ids-test-and-fixture-import-burndown`, direction `direction-011h-core-ids-workflow-test-imports`, and extracted item `direction-011h-workflow-indexed-spec-core-ids-import`.

The selected migration is exactly scoped to `test/WorkflowIndexedSpec.hs` imports. The file no longer imports `CodexWatcher.Core.Ids`, now imports the direct Agent and GitHub id owner modules, and has no test body changes. Baseline build, baseline test suite, whitespace checks, selected-file scans, direct-import scan, broad remaining-user classification, and diff inspection all passed.

Remaining `CodexWatcher.Core.Ids` users are intentionally out of this round: runtime/CLI tests, policy/aggregator coverage, runtime compatibility fixture coverage, public facade/Cabal exposure, docs/public compatibility policy, and the facade module itself. No 011h workflow spec remains on the facade after this round.
