### Changes Made
- `test/WorkflowIndexedSpec.hs`: replaced the `CodexWatcher.Core.Ids` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- `orchestrator/rounds/round-191/implementation-notes.md`: recorded this round's scoped change and verification results.

### Tests
- `test/WorkflowIndexedSpec.hs`: existing indexed workflow specs were preserved unchanged; only imports changed.
- `rg -n "CodexWatcher\\.Core\\.Ids" test/WorkflowIndexedSpec.hs`: passed with no matches.
- `rg -n "CodexWatcher\\.Core\\.Ids" test src moifold.cabal examples agent-workflow-codex agent-workflow-github`: `test/WorkflowIndexedSpec.hs` is absent. Remaining matches are out-of-scope categories: Cabal/public facade exposure (`moifold.cabal`), the facade module itself (`src/CodexWatcher/Core/Ids.hs`), facade policy coverage (`test/FacadeImportPolicySpec.hs`), runtime/CLI tests (`test/RuntimeSpec.hs`, `test/CliSpec.hs`), runtime compatibility fixture coverage (`test/RuntimeCompatibilityFixtureSpec.hs`), and test aggregate wiring (`test/Main.hs`).
- `cabal test watcher-core-test`: passed; 1 of 1 test suites passed.
- `cabal build all`: passed; built the `moifold` executable after the test build.
- `git diff --check`: passed.
- `git diff -- test/WorkflowIndexedSpec.hs`: inspected and confirmed the diff is import-only.

### Notes
No fixtures, assertion text, PASS labels, event/replay expectations, runtime command expectations, or aggregate wiring were changed. Existing unrelated worktree state was left untouched.
