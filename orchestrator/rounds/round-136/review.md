### Checks Run
- Command: `rg -n 'CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission|WorkflowPermission\.|WorkflowPermissionCore\.' test/WorkflowDocsMigrationSpec.hs`
  Result: pass; selected file has no old facade import and no `WorkflowPermission.` references. It has seven `WorkflowPermissionCore.validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` references at lines 338, 340, 346, 717, 719, 726, and 735.
- Command: `rg -n 'module CodexWatcher\.Workflow\.Permission\.Core|validateWorkflowEffectPlanCore' agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
  Result: pass; `CodexWatcher.Workflow.Permission.Core` is the module declaration, exports `validateWorkflowEffectPlanCore`, and defines it.
- Command: `rg -n 'import CodexWatcher\.Workflow\.Permission qualified as WorkflowPermission' src app test agent-workflow-core agent-workflow-codex agent-workflow-github moifold.cabal`
  Result: pass for this round; remaining exact facade imports are only out-of-scope tests/support: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
- Command: `git diff --name-only`
  Result: pass; tracked changes are only `orchestrator/state.json` and `test/WorkflowDocsMigrationSpec.hs` before reviewer artifacts.
- Command: `git diff --name-only -- . ':(exclude)test/WorkflowDocsMigrationSpec.hs' ':(exclude)orchestrator/state.json' ':(exclude)orchestrator/rounds/round-136/selection.md' ':(exclude)orchestrator/rounds/round-136/plan.md' ':(exclude)orchestrator/rounds/round-136/implementation-notes.md'`
  Result: pass; no out-of-scope implementation, package, docs, policy, facade, runtime compatibility, or roadmap files were touched.
- Command: `git diff -- test/WorkflowDocsMigrationSpec.hs`
  Result: pass; the diff only replaces the facade import with `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` and changes the seven existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` call heads to the new qualifier. DocsMigration assertions, indexed permission parity checks, fixtures, event schemas, aggregate wiring, and direct EventLog owner imports are unchanged.
- Command: `cabal test watcher-core-test`
  Result: pass; watcher-core-test completed successfully with `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass; no whitespace or conflict-marker issues.
- Command: `git diff --cached --check`
  Result: pass; no staged diff issues.

### Plan Compliance
- Pre-change scan recorded by implementer: met; implementation notes record one exact selected-file facade import and only old-qualifier `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` call heads before editing.
- Direct owner export confirmed: met; reviewer scan confirms `Permission.Core` exports and defines `validateWorkflowEffectPlanCore`.
- Edit only `test/WorkflowDocsMigrationSpec.hs`: met for implementation scope; tracked implementation diff is only that file plus controller-owned `orchestrator/state.json`.
- Replace only the selected qualifier call heads: met; the seven migrated call heads are all `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec`.
- Preserve behavior and evidence surfaces: met; the selected-file diff changes no assertion bodies, fixtures, event schemas, aggregate wiring, indexed permission parity checks, or existing direct EventLog owner imports.
- Preserve out-of-scope imports and surfaces: met; remaining `Workflow.Permission` facade imports are unchanged out-of-scope tests/support only. No public facade deprecation/removal, Cabal exposure cleanup, package descriptor cleanup, docs/policy change, milestone completion, terminal completion, release approval, or public compatibility removal is present or claimed.
- Run active roadmap baseline and focused checks: met; selected scans, broad import scan, diff-name checks, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

### Decision
**APPROVED**

### Evidence
The integrated round result matches the selected slice from roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-012-eventlog-permission-bridge-split-readiness`, extracted item `round-136-workflow-docs-migration-spec-permission-core-import-convergence`.

The only selected implementation change is qualifier ownership: `test/WorkflowDocsMigrationSpec.hs` now imports `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` and all seven migrated call heads remain the same `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` assertions. Remaining exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports are intentionally out of scope and remain in other test/support files.
