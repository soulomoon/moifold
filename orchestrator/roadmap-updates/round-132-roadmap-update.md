### Source Round
- Round id: `round-132`
- Merged commit: `a671212` (`Move WorkflowExecution audit tests off EventLog facade`)
- Evidence: `orchestrator/rounds/round-132/selection.md`, `orchestrator/rounds/round-132/plan.md`, `orchestrator/rounds/round-132/implementation-notes.md`, `orchestrator/rounds/round-132/review.md`, `orchestrator/rounds/round-132/review-record.json`, `orchestrator/rounds/round-132/merge.md`, and the merged squash commit `a671212`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-132-roadmap-update.md`

### Rationale
Round 132 completed the `round-132-workflow-execution-audit-eventlog-direct-owner-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/WorkflowExecutionSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import. Existing audit accessors and `WorkflowDaemonRetry` / `WorkflowDaemonStop` now use direct `CodexWatcher.Workflow.Audit` owner references, while the existing `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` direct owner imports stayed unchanged. `test/WorkflowExecutionSpec.hs` no longer has stale `WorkflowEventLog.` audit or recommendation uses.

The merged change is status-only for the active roadmap revision. Verification passed with `cabal build watcher-core-test`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, selected-file scans, and broad exact EventLog facade/stale-use scans. The broad scan confirms the remaining exact EventLog facade imports are out-of-scope tests: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and `test/WorkflowIndexedSpec.hs`.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete behavior-preserving migration after rounds 127 through 131 and preserves the operator steering: future selections should prefer lawful, behavior-preserving concrete migration or removal slices over readiness-only rounds where accepted evidence is sufficient. Milestone 003 and direction 012 remain in progress. Remaining test imports, docs/policy references, public facade/exposure, Cabal exposure, and Workflow.Permission migration remain out of scope. This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
