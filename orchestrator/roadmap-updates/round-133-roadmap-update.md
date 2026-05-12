### Source Round
- Round id: `round-133`
- Merged commit: `bfcf423` (`Move WorkflowIndexed audit tests off EventLog facade`)
- Evidence: `orchestrator/rounds/round-133/selection.md`, `orchestrator/rounds/round-133/plan.md`, `orchestrator/rounds/round-133/implementation-notes.md`, `orchestrator/rounds/round-133/review.md`, `orchestrator/rounds/round-133/review-record.json`, `orchestrator/rounds/round-133/merge.md`, and the merged squash commit `bfcf423`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-133-roadmap-update.md`

### Rationale
Round 133 completed the `round-133-workflow-indexed-audit-eventlog-direct-owner-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/WorkflowIndexedSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import. Existing audit accessors and `WorkflowDaemonStop` now use direct `CodexWatcher.Workflow.Audit` owner references, while the existing `WorkflowEventLogCommit` and `WorkflowEventLogFileCore` direct owner imports stayed unchanged. `test/WorkflowIndexedSpec.hs` no longer has stale `WorkflowEventLog.` audit or recommendation uses.

The merged change is status-only for the active roadmap revision. Verification passed with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, selected-file absence scans, selected owner import scans, and broad exact EventLog facade/stale-use scans. No files were staged in review, so `git diff --cached --check` was skipped as not applicable. The broad scan confirms the remaining exact EventLog facade imports are out-of-scope tests: `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`.

This update does not change future coordination enough to require a new roadmap revision. It records another concrete behavior-preserving migration after rounds 127 through 132 and preserves the operator steering: future selections should prefer lawful, behavior-preserving concrete migration or removal slices over readiness-only rounds where accepted evidence is sufficient. Milestone 003 and direction 012 remain in progress. Remaining policy/facade and mixed tests, docs/policy references, public facade/exposure, Cabal exposure, and Workflow.Permission migration remain out of scope. This update does not approve public facade removal/deprecation, Cabal exposure removal, public API cleanup, package descriptor cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
