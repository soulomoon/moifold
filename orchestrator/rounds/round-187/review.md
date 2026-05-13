### Checks Run
- Command: `cabal build all`
  Result: pass. Output: `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass. Built and ran `watcher-core-test` with GHC 9.12.2. Output ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`

- Command: `git diff --check`
  Result: pass. No whitespace errors.

- Command: `git diff --cached --check`
  Result: pass. No staged diff; no staged whitespace errors.

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test/TestSupport/Workflow.hs`
  Result: pass. No matches; the selected helper no longer imports the `Core.Ids` facade.

- Command: `rg -n "CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids" test/TestSupport/Workflow.hs`
  Result: pass. Direct owner imports found:
  - `98:import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId, TurnId (..))`
  - `99:import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName, ReviewThreadId (..))`

- Command: `rg -n "CodexWatcher\\.Core\\.Ids" test src app moifold.cabal docs agent-workflow-codex agent-workflow-github -g '*.hs' -g '*.md' -g '*.cabal'`
  Result: pass with classification. Remaining matches are:
  - Workflow test slices: `test/WorkflowAgentSpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`.
  - Runtime/CLI test slices: `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`.
  - Policy/aggregator: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`.
  - Public facade: `src/CodexWatcher/Core/Ids.hs`.
  - Cabal exposure: `moifold.cabal`.
  - Docs: `docs/agentic-workflow-framework/release-candidate-bundle.md`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, `docs/agentic-workflow-framework/release-notes.md`.
  - Production users beyond the public facade: none. `app`, `agent-workflow-codex`, and `agent-workflow-github` had no matches.

- Command: `set -o pipefail; dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/build/watcher-core-test/watcher-core-test | rg "PASS (workflow execution facade preserves dry-run reports|workflow Codex adapter renders typed thread start request|workflow Codex adapter parses turn start|workflow Codex adapter renders typed thread read request|indexed issue-planning projection starts planner turn with compatibility labels and request id|indexed issue-planning daemon execute starts planner turn before append|workflow event codec round-trips issue_planning_initialized)"`
  Result: pass. Focused workflow evidence preserved existing PASS labels:
  - `PASS workflow event codec round-trips issue_planning_initialized`
  - `PASS workflow execution facade preserves dry-run reports`
  - `PASS workflow Codex adapter renders typed thread start request`
  - `PASS workflow Codex adapter parses turn start`
  - `PASS workflow Codex adapter renders typed thread read request`
  - `PASS indexed issue-planning projection starts planner turn with compatibility labels and request id`
  - `PASS indexed issue-planning daemon execute starts planner turn before append`

- Command: `git diff --unified=0 -- test/TestSupport/Workflow.hs`
  Result: pass. The selected source diff is import-only: one `CodexWatcher.Core.Ids` import removed and two direct owner imports added.

- Command: `git diff --name-only -- test/WorkflowAgentSpec.hs test/WorkflowEventLogSpec.hs test/WorkflowExecutionSpec.hs test/WorkflowIndexedSpec.hs test/RuntimeSpec.hs test/CliSpec.hs test/RuntimeCompatibilityFixtureSpec.hs test/Main.hs test/FacadeImportPolicySpec.hs src app moifold.cabal docs agent-workflow-codex agent-workflow-github`
  Result: pass. No forbidden workflow spec, runtime/CLI test, `test/Main.hs`, `FacadeImportPolicySpec`, source, docs, Cabal, runtime compatibility, or public facade paths changed.

- Command: `git diff --name-status -- orchestrator/roadmaps orchestrator/project-contract.md orchestrator/roles src app test moifold.cabal docs agent-workflow-codex agent-workflow-github`
  Result: pass. Only `M test/TestSupport/Workflow.hs` appeared in those scoped paths; no roadmap, contract, role, source, docs, Cabal, runtime compatibility, or public facade changes.

### Plan Compliance
- Step 1, confirm the only planned edit is the `CodexWatcher.Core.Ids` import in `test/TestSupport/Workflow.hs`: met. The selected source diff is import-only.
- Step 2, replace the facade import with direct owner imports: met. `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` are imported explicitly with the required identifiers.
- Step 3, preserve exports, helper definitions, fixtures, assertion strings, PASS/FAIL labels, fake executor behavior, aggregate wiring, and unrelated formatting: met. The diff touches only the import block. The exported helper list, fixtures such as `sampleIssuePlanMarkdown`, assertion helper, `FakeActionCall`, `fakeActionExecutor*`, `defaultFakeAppServer`, and `callBefore` are unchanged; `watcher-core-test` and focused PASS-label evidence exercised the aggregate wiring.
- Step 4, build and test, widening only direct owner imports if needed: met. The direct owner imports compiled without widening beyond the plan and both baseline commands passed.
- Steps 5-7, unsafe/blocker paths: not needed. No Cabal/package exposure blocker, facade-policy blocker, or behavior drift appeared.

### Decision
**APPROVED**

### Evidence
The integrated round source change is limited to `test/TestSupport/Workflow.hs`, and within that file the diff is only the import migration from `CodexWatcher.Core.Ids` to the direct agent and GitHub id owner modules. No workflow spec files, runtime/CLI tests, `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, source modules, docs, Cabal files, roadmap files, runtime compatibility files, or public facade files changed.

The active roadmap bundle is `2026-05-11-00-highest-value-cleanup` / `rev-002`, and this round matches `milestone-004-core-ids-test-and-fixture-import-burndown`, `direction-011h-core-ids-workflow-test-imports`, and extracted item `direction-011h-testsupport-workflow-core-ids-import`.

Roadmap boundary checks are satisfied. This review does not approve public facade removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, deprecation, removal, milestone completion, terminal completion, release approval, or package publication. Remaining `Core.Ids` users are classified for later workflow-test, runtime/CLI-test, policy/aggregator, public facade, Cabal, and docs slices.

`orchestrator/state.json` is present as control-plane round activation metadata moving round 187 to review; I did not edit state. The reviewer-owned outputs are this `review.md` and the approved `review-record.json`.
