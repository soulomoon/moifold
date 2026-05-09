### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-013-planning-state-fixture-policy`
- Extracted item id: `direction-013-planning-state-fixture-policy`
- Extracted item summary: Add evidence for `planning-state.json`, including fixture coverage or explicit non-healthcheck policy for its current write-only projection.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current `planning-state.json` compatibility projection: producer readback, healthcheck state-file readback, existing fixture coverage or an explicit non-healthcheck policy, and clear blockers before any later cleanup, migration, schema, timing, or removal decision.
- Out of scope: Filename changes, schema changes, event `type` changes, compatibility write-timing changes, healthcheck behavior changes, repair behavior changes, compatibility projection behavior changes, production cleanup, removal, deprecation, migration, package publication, upload, or release approval.
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
Milestones 001 through 004 are complete, and milestone 005 is now complete after round 063 was marked complete in `06dc160`. Milestone 006 depends only on `milestone-005-import-facade-follow-up-evidence`, so runtime compatibility follow-up evidence is the next dependency-ready depth. Within milestone 006, `direction-013-planning-state-fixture-policy` is the first unresolved candidate direction and is narrowly evidence-oriented: it covers `planning-state.json` fixture or policy evidence while preserving active compatibility writes and avoiding any behavior or cleanup change.
