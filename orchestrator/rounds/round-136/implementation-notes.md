### Changes Made
- `test/WorkflowDocsMigrationSpec.hs`: replaced the `CodexWatcher.Workflow.Permission` compatibility-facade import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`, and updated only the existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` call heads to the direct owner qualifier.

### Tests
- `test/WorkflowDocsMigrationSpec.hs`: existing DocsMigration permission assertions, indexed permission parity checks, fixtures, event schemas, aggregate wiring, and EventLog direct-owner imports were preserved; no assertions were changed.
- `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.' test/WorkflowDocsMigrationSpec.hs`: pre-change scan confirmed one exact facade import and only `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` old-qualifier call heads.
- `rg -n 'module CodexWatcher\.Workflow\.Permission\.Core|validateWorkflowEffectPlanCore' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`: passed; direct owner module and export are present.
- `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.|WorkflowPermissionCore\.' test/WorkflowDocsMigrationSpec.hs`: passed; selected file has no old facade import or `WorkflowPermission.` references, and has seven `WorkflowPermissionCore.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` references.
- `rg -n 'import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal`: passed for this round; remaining matches are out-of-scope imports in `test/WorkflowAgentSpec.hs`, `test/FacadeImportPolicySpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowExecutionSpec.hs`, and `test/WorkflowIndexedSpec.hs`.
- `git diff --name-only`: showed `orchestrator/state.json` as pre-existing orchestrator state plus this round's implementation file before notes were written.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed after rerunning serially.
- `git diff --check`: passed.
- `git diff --cached --name-only`: no staged files, so `git diff --cached --check` was not applicable.

### Notes
An initial parallel `cabal test watcher-core-test` attempt failed before compilation with `ghc-pkg-9.12.2: cannot create ... dist-newstyle/packagedb/ghc-9.12.2 already exists` because it ran concurrently with `cabal build all`; the serial rerun passed. No production, package descriptor, docs, facade, fixture, runtime compatibility, roadmap, or controller-state files were edited by this implementer.
