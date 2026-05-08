### Source Round
- Round id: round-027
- Merged commit: c964007 (Add terminal and observation law assertions)
- Evidence: `orchestrator/rounds/round-027/selection.md`, `orchestrator/rounds/round-027/plan.md`, `orchestrator/rounds/round-027/implementation-notes.md`, `orchestrator/rounds/round-027/review.md`, `orchestrator/rounds/round-027/review-record.json`, `orchestrator/rounds/round-027/merge.md`, and the merged squash commit `c964007`.

### Roadmap Change
- Roadmap id: 2026-05-08-00-framework-kernel-migration
- Prior revision: rev-001
- Proposed revision: rev-001
- Files changed: `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`, `orchestrator/roadmap-updates/round-027-roadmap-update.md`

### Rationale
Round 027 completed `direction-003-terminal-and-observation-laws` inside `milestone-001-workflow-spec-contract` by strengthening workflow law coverage for DocsMigration and the representative PR-review checking indexed bridge. The accepted evidence shows assertions for indexed/unindexed observation parity, planned-event/apply consistency, replay determinism, terminal-state closure, and wrong-phase permission rejection, with review-record approval after `cabal build watcher-core-test`, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

This is a status/progress-only roadmap update within rev-001. The round did not change future coordination semantics, milestone dependencies, retry-subloop behavior, event schemas, golden fixtures, daemon/runtime behavior, package boundaries, public compatibility facade availability, or active revision metadata. Because directions 001, 002, and 003 are now complete and the completion signal names a documented, tested spec surface with existential boundaries, source/target labels, replay hooks, permission hooks, terminal semantics, and compatibility adapters for moifold and DocsMigration users, `milestone-001-workflow-spec-contract` moves to complete. The next dependency-ready work may proceed under milestone 002, 003, or 004 according to the roadmap's existing dependency and serial-lane rules.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
