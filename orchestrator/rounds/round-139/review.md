### Checks Run
- Command: `git status --short`
  Result: pass; before review artifacts, tracked changes were `orchestrator/state.json` and `test/WorkflowExecutionSpec.hs`, with untracked round-139 artifacts.
- Command: `git diff --name-status`
  Result: pass; tracked implementation diff is limited to `test/WorkflowExecutionSpec.hs` plus controller-owned `orchestrator/state.json`.
- Command: `git diff -- test/WorkflowExecutionSpec.hs`
  Result: pass; the diff removes `CodexWatcher.Workflow.Permission qualified as WorkflowPermission`, adds `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`, replaces both `WorkflowPermission.validateMoifoldEffectPlan` calls with `validatePhaseActionPlan`, and replaces both `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` call heads with `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`.
- Command: `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowExecutionSpec.hs`
  Result: pass; command exited 1 with no matches, so the selected file has no exact old Permission facade import and no `WorkflowPermission.` use.
- Command: `rg -n 'WorkflowPermissionCore\.validateWorkflowEffectPlanCore @MoifoldSpec|validatePhaseActionPlan|CodexWatcher\.Workflow\.Permission\.Core qualified as WorkflowPermissionCore' test/WorkflowExecutionSpec.hs`
  Result: pass; direct owner import and migrated core validation calls are present, and direct `validatePhaseActionPlan` checks are present in the selected assertions.
- Command: `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null`
  Result: pass; remaining exact Permission facade import/use matches are only in `test/FacadeImportPolicySpec.hs`.
- Command: `git diff --name-only -- ':!orchestrator/state.json' ':!orchestrator/rounds/round-139/*'`
  Result: pass; only `test/WorkflowExecutionSpec.hs` changed outside orchestrator state/artifacts.
- Command: `git diff --name-only -- src app docs '*.cabal' 'cabal.project*' 'agent-workflow-core' 'agent-workflow-codex' 'agent-workflow-github' 'test/FacadeImportPolicySpec.hs'`
  Result: pass; no public facade modules, Permission.Core exports, StateMachine behavior, package descriptors, docs/policy, runtime files, fixtures, EventLog parity owner, or `test/FacadeImportPolicySpec.hs` changed.
- Command: `git diff --cached --name-status`
  Result: pass; no staged changes.
- Command: `cabal test watcher-core-test`
  Result: pass; `Test suite watcher-core-test: PASS`, 1 of 1 test suites passed.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.

### Plan Compliance
- Confirm the starting point and migrate only `test/WorkflowExecutionSpec.hs`: met; the selected file is the only non-orchestrator implementation/test path changed.
- Replace the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`: met; the old exact import is absent and the direct owner import is present at `test/WorkflowExecutionSpec.hs:183`.
- Replace `WorkflowPermission.validateMoifoldEffectPlan` with direct `validatePhaseActionPlan`: met; selected assertions now call `validatePhaseActionPlan` at `test/WorkflowExecutionSpec.hs:355`, `test/WorkflowExecutionSpec.hs:448`, and `test/WorkflowExecutionSpec.hs:454`.
- Replace `WorkflowPermission.validateWorkflowEffectPlanCore @MoifoldSpec` with `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`: met; direct owner calls are present at `test/WorkflowExecutionSpec.hs:450` and `test/WorkflowExecutionSpec.hs:455`.
- Preserve workflow execution assertions, fixtures, event schemas, aggregate wiring, dry-run checks, permission-error expectations, and surrounding behavior: met; the diff only changes the import and selected validation call heads.
- Leave no `WorkflowPermission.` use and no exact old Permission facade import in `test/WorkflowExecutionSpec.hs`: met; focused scan returned no matches.
- Leave exact Permission facade import/use only in `test/FacadeImportPolicySpec.hs`: met; broad scan reports only the policy/parity owner file.
- Do not edit `test/FacadeImportPolicySpec.hs`, public `CodexWatcher.Workflow.Permission` facade implementation or exports, `Permission.Core` exports, `StateMachine`, package descriptors, docs/policy, runtime compatibility files, EventLog facade parity coverage, public facade deprecation/removal, Cabal exposure cleanup, package descriptor cleanup, release approval, milestone completion, terminal completion, or public compatibility removal: met; changed-path checks show none of those surfaces changed.
- Active roadmap and project-contract baseline: met; the round records lineage for `2026-05-11-00-highest-value-cleanup` / `rev-001`, stays inside milestone 003 direction 012 import convergence, keeps public compatibility facades available, and passes all baseline checks.

### Decision
**APPROVED**

### Evidence
The integrated round is the selected one-file import convergence slice. `test/WorkflowExecutionSpec.hs:183` now imports `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`; the exact old `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import is gone. The selected `validateMoifoldEffectPlan` uses are now direct `validatePhaseActionPlan` calls, and the selected core permission checks now use `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`.

The duplicate direct `validatePhaseActionPlan` calls in the allowed/rejected mergeability assertions are redundant, but they are not a review blocker for this round. The plan explicitly preserves the old assertion shape while replacing the facade helper with its direct owner path. That no longer proves facade-vs-direct equivalence in this file, but this round intentionally removes `WorkflowExecutionSpec` from facade parity responsibility, and the broad scan confirms `test/FacadeImportPolicySpec.hs` remains the only exact Permission facade import/use owner for facade policy parity.

No `WorkflowPermission.` use or exact old Permission facade import remains in `test/WorkflowExecutionSpec.hs`. Broad scans over source, app, tests, docs, Cabal descriptors, cabal project files, and standalone package candidates leave exact Permission facade import/use only in `test/FacadeImportPolicySpec.hs`.

The only non-orchestrator implementation/test path changed is `test/WorkflowExecutionSpec.hs`; no public facade modules, `Permission.Core` exports, StateMachine behavior, package descriptors, docs/policy, runtime files, fixtures, EventLog parity coverage, or `test/FacadeImportPolicySpec.hs` changed. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.
