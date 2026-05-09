### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-015-runtime-owner-fixture-operator-inventory`
- Extracted item id: `direction-015-runtime-owner-fixture-operator-inventory`
- Extracted item summary: Record checked-in fixture coverage, `lease` field-path readback, healthcheck behavior, and operator script or runbook inventory for `runtime-owner.json` while preserving it as live daemon ownership state.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current `runtime-owner.json` compatibility surface: current runtime owner store readback, CLI readback, `lease` field-path evidence, healthcheck behavior, checked-in fixture or fixture-gap evidence, and operator script or runbook inventory including `scripts/restart-watcher`.
- Out of scope: Runtime owner filename changes, schema changes, `lease` field migration, event `type` changes, daemon ownership behavior changes, healthcheck behavior changes, repair behavior changes, compatibility projection timing changes, production cleanup, deprecation, migration, removal, package publication, upload, or release approval.
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
Milestones 001 through 005 are complete, and milestone 006 is dependency-ready because it depends only on `milestone-005-import-facade-follow-up-evidence`. The current roadmap records round 064 as completing `direction-013-planning-state-fixture-policy` and round 065 as completing `direction-014-repair-state-fixture-reader-policy`; the current branch head also contains the round-065 completion marker. Directions 015 through 019 remain unresolved.

`direction-015-runtime-owner-fixture-operator-inventory` is the next unresolved milestone-006 direction. It is a bounded evidence extraction for `runtime-owner.json`, matching the roadmap preconditions to read back the current runtime owner store, CLI, healthcheck behavior, and `scripts/restart-watcher` operator path before any future cleanup decision. This selection keeps `runtime-owner.json` live as daemon ownership state and limits the handoff to evidence, inventory, and blocker documentation.
