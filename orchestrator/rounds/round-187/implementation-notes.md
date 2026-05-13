### Changes Made
- `test/TestSupport/Workflow.hs`: replaced the compatibility facade import `CodexWatcher.Core.Ids` with direct owner imports:
  - `CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId, TurnId (..))`
  - `CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName, ReviewThreadId (..))`
- `orchestrator/rounds/round-187/implementation-notes.md`: recorded round evidence.

Exact diff summary:
- `test/TestSupport/Workflow.hs`: import-only change; one facade import removed, two direct-owner imports added.
- No exports, helper definitions, fixture values, assertion labels/text, fake executor behavior, workflow specs, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal files, roadmap files, or state files were edited by this implementation.

### Tests
- `test/TestSupport/Workflow.hs`: no test logic changed; `cabal test watcher-core-test` compiled `TestSupport.Workflow` and downstream workflow specs through the existing aggregate.

Verification commands/results:
- `cabal build all`: passed with GHC 9.12.2; built `agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, and `moifold` library/executable.
- `cabal test watcher-core-test`: passed. Output ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- `git diff --check`: passed with no output.
- `rg -n "CodexWatcher\\.Core\\.Ids" test/TestSupport/Workflow.hs`: no matches, as expected after migration.
- `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/TestSupport/Workflow.hs`: passed; found the direct owner imports on lines 98 and 99.
- Broad scan: `rg -n "CodexWatcher\\.Core\\.Ids" test src app moifold.cabal docs agent-workflow-codex agent-workflow-github -g '*.hs' -g '*.md' -g '*.cabal'` completed and found no production users beyond the public facade module.

Focused workflow test-support behavior evidence:
- The `watcher-core-test` build compiled `TestSupport.Workflow` and downstream workflow specs after the import migration.
- A focused rerun of the built test executable exited 0 and captured existing workflow PASS labels in `/tmp/round187-watcher-core-test.out`, including:
  - `PASS workflow execution facade preserves dry-run reports`
  - `PASS workflow Codex adapter renders typed thread start request`
  - `PASS workflow Codex adapter parses turn start`
  - `PASS workflow Codex adapter renders typed thread read request`
  - `PASS indexed issue-planning projection starts planner turn with compatibility labels and request id`
  - `PASS indexed issue-planning daemon execute starts planner turn before append`
  - `PASS workflow event codec round-trips issue_planning_initialized`

Broad remaining `CodexWatcher.Core.Ids` classification:
- Tests/fixtures, later workflow-test slices:
  - `test/WorkflowAgentSpec.hs`
  - `test/WorkflowEventLogSpec.hs`
  - `test/WorkflowExecutionSpec.hs`
  - `test/WorkflowIndexedSpec.hs`
- Tests/fixtures, runtime/CLI slices:
  - `test/RuntimeSpec.hs`
  - `test/CliSpec.hs`
  - `test/RuntimeCompatibilityFixtureSpec.hs`
- Policy/aggregator classification:
  - `test/FacadeImportPolicySpec.hs`: intentional facade-policy evidence candidate.
  - `test/Main.hs`: aggregate/legacy test body import candidate; left untouched for direction 011j or a later classified slice.
- Public facade:
  - `src/CodexWatcher/Core/Ids.hs`: public compatibility facade module itself.
- Cabal exposure:
  - `moifold.cabal`: exposed-module entry for the public facade.
- Docs:
  - `docs/agentic-workflow-framework/release-candidate-bundle.md`
  - `docs/agentic-workflow-framework/release-notes.md`
  - `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
- `app`, `agent-workflow-codex`, and `agent-workflow-github`: no remaining matches from the broad scan.

### Notes
No unsafe migration evidence appeared. The direct owner imports compiled without widening, so the facade import was not restored.

The worktree had pre-existing orchestrator state changes before implementation (`orchestrator/state.json` modified and `orchestrator/rounds/round-187/` untracked). This implementation did not edit `orchestrator/state.json`.
