### Selected Extraction
- Milestone: Prove Replacement Paths And Behavior Gates
- Milestone id: `milestone-002-replacement-paths-and-behavior-gates`
- Direction id: `direction-004-runtime-file-behavior-gates`
- Extracted item id: `round-055-runtime-file-behavior-gates`
- Extracted item summary: Prove runtime compatibility-file behavior gates from the round 053 inventory by adding or recording golden replay, repair, healthcheck, write-timing, and old snapshot/file evidence for `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR review state files, `block-state.json`, `repair-state.json`, `runtime-owner.json`, and compatibility snapshots without changing file names, schemas, write timing, or removal status.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: readiness evidence and focused tests or source-backed documentation for runtime compatibility-file behavior gates; explicit fixture, command, healthcheck path, repair path, old snapshot assumption, and write-timing coverage for each selected runtime compatibility surface; conservative keep/defer/remove-later readiness notes where evidence is missing.
- Out of scope: file schema migration, compatibility-file removal, filename changes, event JSON `type` changes, healthcheck or repair redesign, daemon ownership changes, app-server startup policy changes, import-facade policy, cleanup policy, deprecation pragmas, roadmap expansion, and final removal approval.
- Concurrent batch context: none; the controller is in serial mode with `max_parallel_rounds=1`, round 054 already completed import replacement readiness, and this is the remaining milestone 002 readiness direction before policy work can start.

### Scheduler Fields
```json
{
  "depends_on_round_ids": [
    "round-053",
    "round-054"
  ],
  "merge_after_item_ids": [
    "round-053-runtime-compatibility-file-inventory",
    "round-054-import-replacement-readiness"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete, and milestone 002 has already completed `direction-003-import-replacement-readiness` via round 054. The roadmap still marks milestone 002 pending because `direction-004-runtime-file-behavior-gates` is open, and later policy and removal milestones depend on runtime behavior evidence.

This extraction is dependency-ready because round 053 produced the source-backed runtime compatibility-file inventory, including producers, consumers, write timing, healthcheck, repair paths, golden fixtures, old-state assumptions, protecting tests, and unknowns. It is the smallest next valuable milestone 002 slice because it turns that inventory into behavior-gate evidence while preserving the roadmap non-goals: no runtime compatibility-file migration, no policy, no deprecation, and no removal before the reviewed final cleanup milestone.
