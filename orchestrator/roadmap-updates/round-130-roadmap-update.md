### Source Round
- Round id: `round-130`
- Merged commit: `64680dc` (`Migrate DocsMigration spec off EventLog facade`)
- Evidence: `orchestrator/rounds/round-130/selection.md`, `orchestrator/rounds/round-130/implementation-notes.md`, `orchestrator/rounds/round-130/review.md`, `orchestrator/rounds/round-130/review-record.json`, `orchestrator/rounds/round-130/merge.md`, and the merged squash commit `64680dc`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-130-roadmap-update.md`

### Rationale
Round 130 completed the `round-130-workflow-docs-migration-spec-eventlog-direct-owner-import-convergence` slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by migrating only `test/WorkflowDocsMigrationSpec.hs` off the exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import. Existing replay, fixture, and replay-failure helper calls now use `CodexWatcher.Workflow.EventLog.Core`, and existing audit accessor calls now use `CodexWatcher.Workflow.Audit`.

The merged change is status-only for the active roadmap revision. It records a concrete test-side EventLog facade import migration after rounds 127 and 128 closed the known production source exact EventLog facade import subset and round 129 removed unused test/support imports. Verification passed with the focused DocsMigration REPL aggregate, `cabal test watcher-core-test`, `cabal build all`, diff checks, selected-file facade scans, broad facade scans, and no-worker-plan checks. The reviewed diff preserved DocsMigration assertions, fixtures, aggregate wiring, event schemas, package descriptors, docs, runtime files, public facade exposure, and out-of-scope test and policy references.

This update does not change future coordination enough to require a new roadmap revision. It preserves the direction-012 steering signal: where accepted evidence is sufficient, future selections should continue preferring lawful, behavior-preserving concrete migration or removal slices over readiness-only rounds. Milestone 003 and direction 012 remain in progress. Remaining exact EventLog facade imports in other tests, docs/policy references, public facade/exposure, and Cabal exposure remain out of scope, and Workflow.Permission migration remains unapproved. This update does not approve public facade removal/deprecation, Cabal exposure removal, package descriptor cleanup, public API cleanup, remaining EventLog facade migration, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
