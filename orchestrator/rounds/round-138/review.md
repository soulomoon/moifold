### Checks Run
- Command: `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/WorkflowIndexedSpec.hs`
  Result: pass; command exited 1 with no matches, so `test/WorkflowIndexedSpec.hs` has no exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import and no `WorkflowPermission.` use.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." test/FacadeImportPolicySpec.hs test/WorkflowExecutionSpec.hs`
  Result: pass; matches remain only in the two explicitly out-of-scope test files.
- Command: `zsh -lc 'paths=($(rg --files src app test docs -g"*.hs" -g"*.md") $(rg --files -g"*.cabal" -g"cabal.project*")); rg -n "CodexWatcher\\.Workflow\\.Permission qualified as WorkflowPermission|WorkflowPermission\\." $paths'`
  Result: pass; broad scan over Haskell sources, docs, Cabal descriptors, and cabal project files reports only `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`.
- Command: `rg -n "CodexWatcher\\.Workflow\\.Permission\\.Core qualified as WorkflowPermissionCore|WorkflowPermissionCore\\.validateWorkflowEffectPlanCore" test/WorkflowIndexedSpec.hs`
  Result: pass; direct owner import is present at line 183 and the existing validation call now uses `WorkflowPermissionCore.validateWorkflowEffectPlanCore` at line 4660.
- Command: `git diff --name-only`
  Result: pass; changed tracked paths before review artifacts were `orchestrator/state.json` and `test/WorkflowIndexedSpec.hs`.
- Command: `git diff --name-only -- 'src' 'app' 'docs' '*.cabal' 'cabal.project*' 'test/FacadeImportPolicySpec.hs' 'test/WorkflowExecutionSpec.hs'`
  Result: pass; no public facade modules, package descriptors, docs/policy, runtime files, fixtures, `test/FacadeImportPolicySpec.hs`, or `test/WorkflowExecutionSpec.hs` changed.
- Command: `git diff -- test/WorkflowIndexedSpec.hs`
  Result: pass; implementation diff is limited to replacing the exact `Workflow.Permission` facade import with `Workflow.Permission.Core` and updating the existing `validateWorkflowEffectPlanCore @MoifoldSpec` qualifier.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites passed.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Confirm starting point and migrate only `test/WorkflowIndexedSpec.hs`: met; the selected file changed only the permission import and the single existing `validateWorkflowEffectPlanCore @MoifoldSpec` qualifier.
- Replace `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`: met; the old exact import is absent and the direct owner import is present.
- Update only the existing `validateWorkflowEffectPlanCore @MoifoldSpec` call to the direct owner qualifier: met; the call now uses `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`.
- Leave no `WorkflowPermission.` use and no exact old Permission facade import in `test/WorkflowIndexedSpec.hs`: met; focused scan returned no matches.
- Broad scans leave exact Permission facade import/use only in out-of-scope files: met; remaining matches are only in `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`.
- Do not modify public facade modules, package descriptors, docs/policy, runtime files, fixtures, `test/FacadeImportPolicySpec.hs`, or `test/WorkflowExecutionSpec.hs`: met; changed-path checks show none of those paths changed.
- Do not claim facade deprecation/removal, Cabal exposure cleanup, milestone completion, terminal completion, release approval, or public compatibility removal: met; implementation notes claim only this file-local import convergence.
- Active roadmap and project-contract baseline: met; baseline commands passed, public compatibility facades remain available, and the round stays inside milestone 003 / direction 012 import convergence.

### Decision
**APPROVED**

### Evidence
The integrated implementation is the selected one-file import convergence slice:

- `test/WorkflowIndexedSpec.hs:183` now imports `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`.
- `test/WorkflowIndexedSpec.hs:4660` now calls `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec wrongPhaseState checkingEffects`.

No `WorkflowPermission.` use or exact old `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import remains in `test/WorkflowIndexedSpec.hs`. Broad scans over `src`, `app`, `test`, `docs`, Cabal descriptors, and cabal project files leave the Permission facade import/use only in `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`, both explicitly out of scope for this round.

The tracked implementation diff before review artifacts was limited to `test/WorkflowIndexedSpec.hs` plus controller-owned `orchestrator/state.json`; untracked round artifacts were selection, plan, and implementation notes. No public facade modules, package descriptors, docs/policy, runtime files, fixtures, `test/FacadeImportPolicySpec.hs`, or `test/WorkflowExecutionSpec.hs` changed.

`cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.
