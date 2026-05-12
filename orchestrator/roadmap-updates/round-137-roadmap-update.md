### Source Round
- Round id: `round-137`
- Merged commit: `0651039` (`Remove unused Workflow Permission imports from tests`)
- Evidence: `orchestrator/rounds/round-137/selection.md`, `orchestrator/rounds/round-137/plan.md`, `orchestrator/rounds/round-137/implementation-notes.md`, `orchestrator/rounds/round-137/review.md`, `orchestrator/rounds/round-137/review-record.json`, `orchestrator/rounds/round-137/merge.md`, and the merged squash commit `0651039`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-137-roadmap-update.md`

### Rationale
Round 137 completed the `round-137-unused-workflow-permission-import-removal` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by removing only the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports from `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs`.

The merged change is status-only for the active roadmap revision. Review evidence records that assertions, fixtures, event schemas, aggregate wiring, helper exports, direct EventLog owner imports, production/app files, package descriptors, docs/policy, public facade modules, and out-of-scope permission behavior were preserved. Verification passed with the selected-file scan showing no facade imports or `WorkflowPermission.` use sites in those three files, a broad exact Permission facade import scan leaving only `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`, a broad `WorkflowPermission.` scan leaving only the same three files, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

This update does not change future coordination enough to require a new roadmap revision. It records one concrete internal Permission facade-import removal and preserves the operator steering: future selections should prefer lawful concrete migration or removal slices over readiness-only gate work where evidence already makes the slice lawful. Milestone 003 and direction 012 remain in progress. The exact remaining Permission facade imports and use sites are intentionally only `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`. The explicit EventLog facade parity owner, docs/policy references, public facade/exposure, Cabal exposure, package descriptor cleanup, remaining Permission facade migration, release approval, milestone completion, terminal completion, and public compatibility removal remain out of scope. This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, docs/policy cleanup, remaining Permission facade migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
