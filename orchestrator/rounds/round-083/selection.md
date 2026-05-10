### Selected Extraction
- Milestone: Test Topology And Cleanup Inventory
- Milestone id: `milestone-001-test-topology-inventory`
- Direction id: `direction-001-cleanup-inventory-refresh`
- Extracted item id: `round-083-cleanup-inventory-refresh`
- Extracted item summary: Refresh the current cleanup inventory across compatibility facades, runtime compatibility files, oversized test/helper clusters, and large behavior modules, producing round-local evidence for the next test topology, fixture, import-convergence, and module-split slices.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Round-local inventory artifacts covering import scans, module line counts, fixture coverage, policy references, prior terminal-hold context, and downstream/operator inventory scope for the cleanup surfaces named by the active roadmap.
- Out of scope: Production code, test code, Cabal files, docs, compatibility behavior, event schemas, healthcheck behavior, repair behavior, import migration, deprecation, facade removal, runtime compatibility-file deletion or rename, implementation planning, roadmap updates, and controller state edits.
- Concurrent batch context: none; active state uses `max_parallel_rounds: 1`, and the roadmap keeps milestone 001 serial until inventory proves disjoint ownership.

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
The active roadmap is the fresh `2026-05-11-00-highest-value-cleanup` family at `rev-001`. Its first milestone, `milestone-001-test-topology-inventory`, has no milestone dependencies, while later milestones depend on milestone 001 evidence or on downstream directions that are not ready yet.

Within milestone 001, `direction-001-cleanup-inventory-refresh` is the smallest dependency-ready extraction. Directions 002 through 004 rely on current inventory or clarified helper ownership before splitting tests, and milestones 002 through 006 depend on this evidence-first sequence. Selecting this inventory round now preserves the prior facade-removal terminal hold as non-removal evidence while giving downstream roles a current map of the cleanup surfaces they may safely plan against.
