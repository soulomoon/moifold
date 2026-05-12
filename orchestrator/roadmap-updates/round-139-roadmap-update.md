### Source Round
- Round id: `round-139`
- Merged commit: `5cc9be9` (`Move WorkflowExecutionSpec permission checks to direct owners`)
- Evidence: `orchestrator/rounds/round-139/selection.md`, `orchestrator/rounds/round-139/plan.md`, `orchestrator/rounds/round-139/implementation-notes.md`, `orchestrator/rounds/round-139/review.md`, `orchestrator/rounds/round-139/review-record.json`, `orchestrator/rounds/round-139/merge.md`, and the merged squash commit `5cc9be9`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-139-roadmap-update.md`

### Rationale
Round 139 completed the `round-139-workflow-execution-spec-permission-direct-owner-migration` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/WorkflowExecutionSpec.hs` away from the exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` compatibility-facade import/use.

The merged change is status-only for the active roadmap revision. Review evidence records that selected `validateMoifoldEffectPlan` assertions now use direct `validatePhaseActionPlan`; selected `validateWorkflowEffectPlanCore @MoifoldSpec` call heads now use `CodexWatcher.Workflow.Permission.Core qualified as WorkflowPermissionCore`; `test/WorkflowExecutionSpec.hs` has no old Permission facade import or `WorkflowPermission.` use; broad scans leave exact Permission facade import/use only in `test/FacadeImportPolicySpec.hs`; and `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete internal Permission direct-owner migration and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 012 remain in progress. The only remaining exact Permission facade import/use in current code is intentionally `test/FacadeImportPolicySpec.hs`, the explicit facade/policy parity owner. This narrows the next coordination question to policy/docs/public-exposure/removal gates, but it does not approve public facade removal.

This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
