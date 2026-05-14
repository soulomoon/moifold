### Changes Made
- `test/WorkflowAgentSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility facade import with direct imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; no assertions, fixtures, aggregate wiring, request/rendering expectations, turn classifier cases, PASS labels, or behavior were changed.

### Tests
- `test/WorkflowAgentSpec.hs`: covered by `cabal test watcher-core-test`; the target passed.
- `rg -n "CodexWatcher.Core.Ids" test/WorkflowAgentSpec.hs`: no matches; `rg` exited 1 as expected for an empty result.
- `rg -n "CodexWatcher.Workflow.Agent.Ids|CodexWatcher.Workflow.GitHub.Ids" test/WorkflowAgentSpec.hs`: found the two direct-owner imports at lines 66 and 67.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `rg -n "CodexWatcher.Core.Ids" src app test docs moifold.cabal agent-workflow-* packages 2>/dev/null || true`: remaining users are outside the selected file. Categories:
  - Public facade/Cabal/docs surfaces: `src/CodexWatcher/Core/Ids.hs`, `moifold.cabal`, and `docs/agentic-workflow-framework/*` compatibility/readiness documents.
  - Workflow specs: `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`.
  - Runtime/CLI tests: `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`.
  - Policy/aggregator candidates: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`.
  - No app, reusable package, or production `src` user was reintroduced beyond the facade module itself.

### Notes
`git diff -- test/WorkflowAgentSpec.hs` is import-only. Existing unowned worktree changes were left untouched: `orchestrator/state.json` was already modified and `orchestrator/rounds/round-189/plan.md` was already untracked before this implementation.
