### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-016-daemon-state-active-stopped-fixtures`
- Extracted item id: `direction-016-daemon-state-active-stopped-fixtures`
- Extracted item summary: Add active and stopped `daemon-state.json` fixture evidence while preserving existing tolerated old-shape evidence and stable daemon summary compatibility.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current `daemon-state.json` compatibility surface: active and stopped fixture evidence, tolerated old-shape evidence, current compatibility projection readback, healthcheck readback, repair readback, restart cleanup readback, and blockers before any later cleanup, migration, schema, timing, healthcheck, repair, projection, or removal decision.
- Out of scope: Daemon state filename changes, schema changes, event `type` changes, daemon summary compatibility changes, compatibility projection behavior changes, healthcheck behavior changes, repair behavior changes, restart cleanup behavior changes, production cleanup, removal, deprecation, migration, package publication, upload, or release approval.
- Concurrent batch context: none; `max_parallel_rounds` is 1 and the active roadmap sets the default lane to serial for compatibility cleanup.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestones 001 through 005 are complete, and milestone 006 is dependency-ready because it depends only on `milestone-005-import-facade-follow-up-evidence`. The active roadmap records round 064 as completing `direction-013-planning-state-fixture-policy`, round 065 as completing `direction-014-repair-state-fixture-reader-policy`, and round 066 as completing `direction-015-runtime-owner-fixture-operator-inventory`. The same roadmap states that milestone 006 remains pending because directions 016 through 019 are unresolved.

`direction-016-daemon-state-active-stopped-fixtures` is the next unresolved milestone-006 direction. It is a bounded evidence extraction for `daemon-state.json`, matching the roadmap preconditions to read back current compatibility projection, healthcheck, repair, and restart cleanup behavior before any future cleanup decision. This selection preserves daemon summary compatibility and limits the handoff to fixture evidence, old-shape evidence, and blocker documentation.
