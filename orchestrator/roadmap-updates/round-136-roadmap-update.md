### Source Round
- Round id: `round-136`
- Merged commit: `74368a8` (`Move DocsMigration permission tests to Permission.Core`)
- Evidence: `orchestrator/rounds/round-136/selection.md`, `orchestrator/rounds/round-136/plan.md`, `orchestrator/rounds/round-136/implementation-notes.md`, `orchestrator/rounds/round-136/review.md`, `orchestrator/rounds/round-136/review-record.json`, `orchestrator/rounds/round-136/merge.md`, and the merged squash commit `74368a8`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-136-roadmap-update.md`

### Rationale
Round 136 completed the `round-136-workflow-docs-migration-spec-permission-core-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by moving only `test/WorkflowDocsMigrationSpec.hs` from `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` to direct `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` for seven existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` call heads.

The merged change is status-only for the active roadmap revision. Review evidence records that DocsMigration assertions, indexed permission parity checks, fixtures, event schemas, aggregate wiring, existing EventLog direct-owner imports, production/app files, package descriptors, docs/policy, and facade modules were preserved. Verification passed with the selected-file scan showing no old facade import or `WorkflowPermission.` references and seven `WorkflowPermissionCore.validateWorkflowEffectPlanCore` references, the direct owner export scan, a broad exact Permission facade import scan leaving out-of-scope imports in `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/TestSupport/Workflow.hs`, `test/WorkflowAgentSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

This update does not change future coordination enough to require a new roadmap revision. It records one concrete Permission direct-owner migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 012 remain in progress. The explicit EventLog facade parity owner, remaining Workflow.Permission facade imports, docs/policy references, public facade/exposure, Cabal exposure, package descriptor cleanup, docs/policy cleanup, remaining Permission facade migration, release approval, milestone completion, terminal completion, and public compatibility removal remain out of scope. This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, remaining Permission facade migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
