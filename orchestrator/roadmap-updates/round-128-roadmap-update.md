### Source Round
- Round id: `round-128`
- Merged commit: `2682cca` (`Move Daemon audit off EventLog facade`)
- Evidence: `orchestrator/rounds/round-128/selection.md`, `orchestrator/rounds/round-128/implementation-notes.md`, `orchestrator/rounds/round-128/review.md`, `orchestrator/rounds/round-128/review-record.json`, `orchestrator/rounds/round-128/merge.md`, and the merged squash commit `2682cca`.

### Roadmap Change
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Prior revision: `rev-001`
- Proposed revision: `rev-001`
- Files changed: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-128-roadmap-update.md`

### Rationale
Round 128 completed the Daemon EventLog audit direct-owner import-convergence slice under `milestone-003-import-convergence-package-boundaries` / `direction-012-eventlog-permission-bridge-split-readiness` by moving only `src/CodexWatcher/Daemon.hs` off the exact mixed `CodexWatcher.Workflow.EventLog` facade for daemon audit helper usage. Daemon now uses direct `CodexWatcher.Workflow.Audit` owner references for audit types and helpers while keeping direct `CodexWatcher.Workflow.EventLog.Commit.Core` ownership unchanged.

The merged change is status-only for the roadmap. It records the accepted Daemon production import migration and, together with round 127's DocsMigration migration, closes the current known production source exact `CodexWatcher.Workflow.EventLog` facade import subset. Round evidence shows daemon observed-tick, audit, transaction, replay, event-commit, compatibility-write, failure-formatting, and public-export behavior were preserved. Verification passed with focused daemon/workflow REPL probes, `cabal build all`, `cabal test watcher-core-test`, diff checks, and facade/import scans.

This update does not change future coordination enough to require a new roadmap revision. Milestone 003 and direction 012 remain in progress: remaining exact EventLog facade references in tests/test support, docs/policy references, public facade/exposure, and Cabal exposure are intentionally out of scope, and Workflow.Permission bridge migration remains unapproved. This update does not approve test-policy/support migration, facade deprecation/removal, Cabal exposure removal, public API cleanup, package descriptor cleanup, Workflow.Permission migration, release approval, milestone completion, terminal completion, or public compatibility removal.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
