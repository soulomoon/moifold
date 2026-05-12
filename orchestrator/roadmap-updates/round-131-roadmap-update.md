### Source Round
- Round id: `round-131`
- Merged commit: `9107ffe` (`Move Main audit tests off EventLog facade`)
- Evidence: `orchestrator/rounds/round-131/selection.md`, `orchestrator/rounds/round-131/plan.md`, `orchestrator/rounds/round-131/implementation-notes.md`, `orchestrator/rounds/round-131/review.md`, `orchestrator/rounds/round-131/review-record.json`, `orchestrator/rounds/round-131/merge.md`, and the merged squash commit `9107ffe`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-131-roadmap-update.md`

### Rationale
Round 131 completed the `round-131-main-audit-eventlog-direct-owner-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/Main.hs` daemon audit assertions off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import. Existing daemon audit accessors and `WorkflowDaemonContinue` now use direct `CodexWatcher.Workflow.Audit` owner references, and `test/Main.hs` no longer has stale `WorkflowEventLog.` daemon-audit uses.

The merged change is status-only for the active roadmap revision. Verification passed with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, selected-file absence scans, and broad exact EventLog facade scans. The broad scan confirms the remaining exact EventLog facade imports are only out-of-scope tests: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete behavior-preserving migration after rounds 127 through 130 and preserves the operator steering: future selections should prefer lawful, behavior-preserving concrete migration or removal slices over readiness-only rounds where accepted evidence is sufficient. Milestone 003 and direction 012 remain in progress. Remaining test imports, docs/policy references, public facade/exposure, Cabal exposure, remaining EventLog migration, and Workflow.Permission migration remain out of scope. This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
