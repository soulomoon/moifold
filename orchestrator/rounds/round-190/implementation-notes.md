### Changes Made
- `test/WorkflowExecutionSpec.hs`: replaced the `CodexWatcher.Core.Ids` facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`/`TurnId` and `CodexWatcher.Workflow.GitHub.Ids` for GitHub identifiers. No test bodies, fixture values, assertion text, PASS labels, runtime command expectations, replay expectations, or aggregate wiring were changed.

### Tests
- `test/WorkflowExecutionSpec.hs`: existing workflow execution coverage was preserved under `cabal test watcher-core-test`.
- `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowExecutionSpec.hs`: no matches.
- `rg -n "\\bRequestId\\b" test/WorkflowExecutionSpec.hs`: no matches.
- `rg -n "CodexWatcher\\.Core\\.Ids" test src app docs moifold.cabal agent-workflow-*`: remaining out-of-scope users are Cabal exposure (`moifold.cabal`), facade source (`src/CodexWatcher/Core/Ids.hs`), docs/policy references (`docs/agentic-workflow-framework/*`), and other tests (`test/FacadeImportPolicySpec.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `test/WorkflowIndexedSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`). No `app` or `agent-workflow-*` matches were reported.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff -- test/WorkflowExecutionSpec.hs`: import-only diff confirmed.

### Notes
The worktree already had unrelated orchestrator metadata changes before this implementation (`orchestrator/state.json` modified and `orchestrator/rounds/round-190/` untracked). I did not edit `orchestrator/state.json`, roadmap files, Cabal files, docs, source modules, fixtures, policy/aggregator files, or other tests.
