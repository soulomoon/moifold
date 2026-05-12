### Changes Made
- `test/WorkflowIndexedSpec.hs`: replaced the `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` compatibility-facade import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`, then updated the existing `validateWorkflowEffectPlanCore @MoifoldSpec` assertion to use the direct owner qualifier.

### Tests
- `test/WorkflowIndexedSpec.hs`: existing indexed workflow permission-law assertion now exercises `validateWorkflowEffectPlanCore` through `Permission.Core` directly while preserving the same wrong-phase rejection expectations.
- Focused scan: `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/WorkflowIndexedSpec.hs` returned no matches.
- Out-of-scope scan: `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/FacadeImportPolicySpec.hs test/WorkflowExecutionSpec.hs` returned only the two approved remaining facade users.
- Broad scan: `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." src app test docs moifold.cabal cabal.project` returned only `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`.
- `cabal test watcher-core-test` passed.
- `cabal build all` passed.
- `git diff --check` passed.
- `git diff --cached --check` passed; no changes were staged.
- Changed-path review: tracked diff is `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`; untracked round artifacts are `orchestrator/rounds/round-138/implementation-notes.md`, `orchestrator/rounds/round-138/plan.md`, and `orchestrator/rounds/round-138/selection.md`.

### Notes
No blockers. I did not stage changes; `git diff --cached --check` ran against the empty index and passed.
