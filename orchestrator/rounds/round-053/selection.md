### Selected Extraction
- Milestone: Inventory Compatibility Surfaces
- Milestone id: `milestone-001-inventory-compatibility-surfaces`
- Direction id: `direction-002-runtime-compatibility-file-inventory`
- Extracted item id: `round-053-runtime-compatibility-file-inventory`
- Extracted item summary: Inventory runtime compatibility files and snapshots, including current write sites, read sites, repair and healthcheck use, old-log assumptions, protecting tests, and unknowns for `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR URL/state files, block state, repair state, runtime owner files, and compatibility snapshots.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: source-backed inventory artifacts for runtime compatibility files, producer and consumer paths, old-log and golden fixture assumptions, repair and healthcheck references, write-timing observations, existing test coverage, and unresolved risks.
- Out of scope: file name changes, field changes, schema migration, compatibility write behavior changes, removal, deprecation, renaming, policy wording, import-facade follow-up work, and final cleanup candidate approval.
- Concurrent batch context: none selected for this round; round 052 already completed the disjoint import-facade inventory, and the active controller state allows one active round at a time.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [],
  "merge_after_item_ids": [
    "round-052-import-facade-inventory"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 1 has no external dependencies, but it remains pending because runtime compatibility-file inventory is still open after round 052 completed the import-facade inventory. This extraction is the next dependency-ready item because later replacement gates, policy, roadmap expansion, and removal milestones all depend on a complete inventory of both import facades and runtime compatibility files. The scope is evidence-only and preserves the roadmap rule that runtime compatibility files must not be renamed, migrated, removed, or have write behavior changed before old-log, golden, repair, healthcheck, and write-timing evidence exists.
