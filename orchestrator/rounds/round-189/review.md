### Checks Run
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, with `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `git diff --check`
  Result: pass; no whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass; nothing staged and no cached whitespace errors reported.

- Command: `rg -n "CodexWatcher.Core.Ids" test/WorkflowAgentSpec.hs`
  Result: pass; no matches. `rg` exited 1 as expected for an empty result.

- Command: `rg -n "CodexWatcher.Workflow.Agent.Ids|CodexWatcher.Workflow.GitHub.Ids" test/WorkflowAgentSpec.hs`
  Result: pass; direct imports found at lines 66 and 67.

- Command: `rg -n "CodexWatcher.Core.Ids" src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true`
  Result: pass; remaining users are outside the selected file and categorized below. No `app`, `agent-workflow-*`, `packages`, or production `src` users were found beyond the public facade module itself.

- Command: `git diff -- test/WorkflowAgentSpec.hs`
  Result: pass; selected-file diff is import-only, replacing the `CodexWatcher.Core.Ids` facade import with direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` imports.

### Plan Compliance
- Inspect current `CodexWatcher.Core.Ids` import and used identifiers: met. The selected file uses agent ids/progression (`RequestId`, `ThreadId`, `TurnId`, `nextRequestId`) and GitHub ids (`RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `CommitSha`, `ReviewThreadId`).
- Replace only the facade import with direct owner imports: met. `test/WorkflowAgentSpec.hs` now imports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` directly.
- Leave workflow behavior unchanged: met. The selected-file diff changes only imports; agent adapter assertions, request rendering expectations, turn classifier cases, fixtures, PASS labels, aggregate wiring, and behavior code are unchanged.
- Inspect diff for selected-file import-only scope: met. `git diff --unified=0 -- test/WorkflowAgentSpec.hs` shows one removed import and two added direct-owner imports.
- Record remaining `Core.Ids` users by category: met.

### Decision
**APPROVED**

### Evidence
Roadmap lineage is active for `2026-05-11-00-highest-value-cleanup` revision `rev-002` with roadmap dir `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`. The active round is `round-189`, selected item `direction-011h-workflow-agent-spec-core-ids-import`.

The tracked implementation change in `test/WorkflowAgentSpec.hs` is import-only:

```diff
-import CodexWatcher.Core.Ids
+import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..), nextRequestId)
+import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), IssueNumber (..), PrNumber (..), RepoName (..), ReviewThreadId (..))
```

The broader tracked diff also contains `orchestrator/state.json` review-stage metadata for round 189. That is control-plane state, not an implementation or behavior change. I did not edit implementation files during review.

Remaining `CodexWatcher.Core.Ids` users from the broad scan:

- Remaining workflow specs: `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`.
- Runtime/CLI tests: `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`.
- Policy/aggregator candidates: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`.
- Docs/Cabal/public facade: `moifold.cabal`, `docs/agentic-workflow-framework/release-candidate-bundle.md`, `docs/agentic-workflow-framework/package-extraction-readiness.md`, `docs/agentic-workflow-framework/release-notes.md`, `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, and `src/CodexWatcher/Core/Ids.hs`.
- Production/app/package users: none found in `app`, `agent-workflow-*`, `packages`, or production `src` beyond the facade module itself.

No deprecation, Cabal exposure removal, public facade removal, runtime compatibility cleanup, fixture change, milestone completion, or policy/aggregator migration is implied by this approval.
