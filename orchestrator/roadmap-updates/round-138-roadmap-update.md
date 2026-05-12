### Source Round
- Round id: `round-138`
- Merged commit: `2fffb4e` (`Move WorkflowIndexedSpec permission check to Permission.Core`)
- Evidence: `orchestrator/rounds/round-138/selection.md`, `orchestrator/rounds/round-138/plan.md`, `orchestrator/rounds/round-138/implementation-notes.md`, `orchestrator/rounds/round-138/review.md`, `orchestrator/rounds/round-138/review-record.json`, `orchestrator/rounds/round-138/merge.md`, and the merged squash commit `2fffb4e`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-138-roadmap-update.md`

### Rationale
Round 138 completed the `round-138-workflow-indexed-spec-permission-core-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/WorkflowIndexedSpec.hs` from the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` facade import/use to direct `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore` for its single existing `validateWorkflowEffectPlanCore @MoifoldSpec` assertion.

The merged change is status-only for the active roadmap revision. Review evidence records that `test/WorkflowIndexedSpec.hs` has no old Permission facade import or `WorkflowPermission.` use; broad scans leave exact Permission facade import/use only in `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This update does not change future coordination enough to require a new roadmap revision. It records one concrete internal Permission direct-owner import migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 012 remain in progress. The exact remaining Permission facade imports and use sites are intentionally only `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs`; `WorkflowExecutionSpec` is the remaining non-policy concrete Permission migration candidate, while `FacadeImportPolicySpec` remains explicit facade/policy parity coverage.

This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, remaining Permission facade migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
