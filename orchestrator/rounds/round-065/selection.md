### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-014-repair-state-fixture-reader-policy`
- Extracted item id: `direction-014-repair-state-fixture-reader-policy`
- Extracted item summary: Add fixture, reader, and healthcheck or non-healthcheck evidence for `repair-state.json` and repair execution ordering while preserving the current repair write order.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current `repair-state.json` compatibility surface: repair execute write-order readback, compatibility rewrite ordering, production reader inventory, healthcheck or explicit non-healthcheck policy, fixture or fixture-gap evidence, and blockers before any later cleanup, migration, schema, timing, healthcheck, projection, or removal decision.
- Out of scope: Repair write-order changes, filename changes, schema changes, event `type` changes, compatibility rewrite behavior changes, stale `block-state.json` cleanup behavior changes, healthcheck behavior changes, production cleanup, removal, deprecation, migration, package publication, upload, or release approval.
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
Milestones 001 through 005 are complete, and milestone 006 is dependency-ready because it depends only on `milestone-005-import-facade-follow-up-evidence`. Round 064 completed `direction-013-planning-state-fixture-policy` and the active roadmap now records directions 014 through 019 as the unresolved milestone-006 work.

`direction-014-repair-state-fixture-reader-policy` is the next unresolved direction in milestone 006. It is a bounded evidence extraction for `repair-state.json`, matching the round 058 follow-up discovery that found execute repair writes the file but no production reader, healthcheck reader, or checked-in fixture. This selection keeps the protected repair execution order intact and limits the handoff to evidence, policy, and blocker documentation before any future cleanup or removal proposal.
