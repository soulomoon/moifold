### Goal
Migrate only `test/WorkflowDocsMigrationSpec.hs` from the `CodexWatcher.Workflow.Permission` compatibility-facade import to the direct `CodexWatcher.Workflow.Permission.Core` owner import for existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` assertions.

### Approach
Keep the round as a sequential single-file implementation. The selected file currently imports `CodexWatcher.Workflow.Permission qualified as WorkflowPermission`, and its `WorkflowPermission.` use sites are limited to `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec`. Replace that exact import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`, then update only those existing qualifier references.

Do not change any DocsMigration assertions, indexed permission parity checks, fixtures, event schemas, aggregate wiring, EventLog direct-owner imports, package descriptors, production/app files, docs/policy files, facade modules, roadmap files, or controller state. Do not create `worker-plan.json`; fan-out is not justified for this one-file import migration.

### Steps
1. Record the pre-change selected-file scan:
   - `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowDocsMigrationSpec.hs`
   - Confirm the exact facade import is present once.
   - Confirm every `WorkflowPermission.` selected-file use is an existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` assertion.
2. Confirm the direct owner export before editing:
   - `rg -n 'module CodexWatcher\.Workflow\.Permission\.Core|validateWorkflowEffectPlanCore' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
   - Confirm `CodexWatcher.Workflow.Permission.Core` exports `validateWorkflowEffectPlanCore`.
3. Edit only `test/WorkflowDocsMigrationSpec.hs`:
   - Replace `import CodexWatcher.Workflow.Permission qualified as WorkflowPermission` with `import CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`.
   - Replace only existing `WorkflowPermission.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec ...` call heads with `WorkflowPermissionCore.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec ...`.
4. Run the post-change selected-file scan:
   - `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.|WorkflowPermissionCore\.' test/WorkflowDocsMigrationSpec.hs`
   - Confirm there is no selected-file exact facade import.
   - Confirm there are no remaining selected-file `WorkflowPermission.` references.
   - Confirm the new `WorkflowPermissionCore.` references correspond exactly to the migrated `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` use sites.
5. Run the broad exact Permission facade import scan and record remaining out-of-scope imports:
   - `rg -n 'import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal`
   - Treat all remaining matches outside `test/WorkflowDocsMigrationSpec.hs` as out of scope for this round unless the scan unexpectedly shows the selected file still importing the facade.
6. Confirm out-of-scope files are untouched:
   - `git diff --name-only`
   - The implementation diff should include only `test/WorkflowDocsMigrationSpec.hs` plus round artifacts/state already managed by the orchestrator.
   - If a narrower out-of-scope check is needed, use `git diff --name-only -- . ':(exclude)test/WorkflowDocsMigrationSpec.hs' ':(exclude)orchestrator/rounds/round-136/plan.md' ':(exclude)orchestrator/state.json'` and confirm no implementation/package/docs files appear.

### Verification
Run the focused scans from the steps and the active roadmap baseline:

1. `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.|WorkflowPermissionCore\.' test/WorkflowDocsMigrationSpec.hs`
2. `rg -n 'module CodexWatcher\.Workflow\.Permission\.Core|validateWorkflowEffectPlanCore' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
3. `rg -n 'import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal`
4. `git diff --name-only`
5. `cabal test watcher-core-test`
6. `cabal build all`
7. `git diff --check`
8. `git diff --cached --check` if staging is involved

The reviewer should reject the round if the selected file still imports the `Workflow.Permission` facade, if any migrated qualifier is not an existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` assertion, if DocsMigration behavior/fixtures/event schema assertions are weakened, or if any out-of-scope test, production/app file, package descriptor, docs/policy file, facade module, roadmap file, or controller state is edited by the implementer.
