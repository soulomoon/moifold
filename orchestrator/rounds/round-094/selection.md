### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-007-runtime-compatibility-fixtures`
- Extracted item id: `round-094-runtime-owner-compatibility-fixtures`
- Extracted item summary: Add focused checked-in fixture coverage and watcher-core assertions for the current `runtime-owner.json` lease shape, preserving current healthcheck reader mapping, script field-path assumptions, filename, and schema.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused `runtime-owner.json` fixture files, exact current lease JSON shape assertions, current runtime-owner parser/reader fixture coverage, and minimal watcher-core source-policy or fixture-backed checks needed to preserve the existing healthcheck and restart-script field-path assumptions.
- Out of scope: Fixtures for live `issue-snapshot.json` or unrelated checked-in compatibility snapshots; remaining fixture batch approval; external downstream inventory; compatibility file deletion or rename; schema migration; runtime-owner producer changes; healthcheck behavior changes; script behavior changes; repair behavior changes; public deprecation; facade removal; Cabal exposure changes; roadmap edits; controller state edits; and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, milestone 002 remains in progress, and this extracts the next narrow remaining direction 007 fixture blocker after rounds 090, 091, 092, and 093 completed only the planner/planning, daemon-state, repair-failure block-state, and repair-state fixture slices.

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
Milestone 001 is complete, so milestone 002 remains the dependency-ready prerequisite before runtime compatibility cleanup gates can proceed. Within milestone 002, direction 005 supplied the compatibility fixture gap inventory, direction 006 locked the distinct planner/planning state contract, round 089 completed only the `runtime-owner.json` healthcheck-contract slice of direction 008, and rounds 090 through 093 completed only selected direction 007 fixture slices for planner/planning, daemon-state, repair-failure `block-state.json`, and `repair-state.json`.

The next smallest valuable extraction is the fifth immediate fixture blocker from the round-087 inventory: current `runtime-owner.json` lease fixture coverage. `runtime-owner.json` remains a kept compatibility surface with runtime owner producers, runtime owner readers, healthcheck reader mapping, and restart-script cleanup assumptions. Adding focused fixture and test evidence now advances the runtime-state evidence base while avoiding behavior, schema, healthcheck, script, repair, deprecation, migration, or removal changes.
