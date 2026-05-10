### Source Round
- Round id: `round-072`
- Merged commit: `161b6edf3f90f4f799af5bdb22919622d4f4d882`
- Evidence: `orchestrator/rounds/round-072/selection.md`, `orchestrator/rounds/round-072/plan.md`, `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`, `orchestrator/rounds/round-072/implementation-notes.md`, `orchestrator/rounds/round-072/review.md`, `orchestrator/rounds/round-072/review-record.json`, and `orchestrator/rounds/round-072/merge.md`

### Roadmap Change
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Prior revision: `rev-002`
- Proposed revision: `rev-002`
- Files changed: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`

### Rationale
Round 072 was approved and merged as `161b6edf3f90f4f799af5bdb22919622d4f4d882` for `round-072-no-lawful-removal-surface-status`. Its artifact-only evidence records that `milestone-008-gated-compatibility-removals` is dependency-reached after milestone 007, but currently blocked/held because no exact public import facade or runtime compatibility surface satisfies every removal gate and exact reviewer approval.

The roadmap status update keeps milestone 008 pending and records both removal directions as held. `direction-021-remove-approved-import-facades` has no exact import facade with all policy, follow-up evidence, external inventory, unsupported-user, behavior/package-boundary, and exact reviewer-approval gates satisfied. `direction-022-remove-approved-runtime-compatibility-surfaces` has no exact runtime compatibility file or snapshot with all old-log/golden, repair, healthcheck or non-healthcheck, runtime-owner, fixture, operator, write-timing, unsupported-user, and exact reviewer-approval gates satisfied.

Round 072 preserves the round 071 blocker model: unavailable external downstream repositories, unavailable live state archives, unavailable external operator scripts, blocked operator/reviewer/release-gate approval evidence, missing unsupported-user decisions, and per-surface blockers remain blockers. Local absence remains unavailable or blocked evidence, not removal approval.

This update does not mark milestone 008 complete, does not mark `direction-021` or `direction-022` complete, and does not select or complete milestone 009. It does not approve deprecation, migration, removal, package publication, upload, release, Cabal exposure changes, production import rewrites, schema or filename changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, or operator behavior changes.

This is a status-only update to the active revision. It does not change future coordination, sequencing, milestone boundaries, cleanup policy, expansion decisions, or active revision metadata, so the proposed revision remains `rev-002`.

### State Activation
- Requires state.json roadmap metadata update: no
- New roadmap_dir when applicable: n/a
