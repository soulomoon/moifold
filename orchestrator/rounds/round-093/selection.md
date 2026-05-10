### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-007-runtime-compatibility-fixtures`
- Extracted item id: `round-093-repair-state-compatibility-fixtures`
- Extracted item summary: Add focused checked-in fixture coverage and watcher-core assertions for the current `repair-state.json` repair summary shape written by `repair-invalid-state --execute`, preserving current write ordering, explicit non-reader/non-healthcheck behavior, filename, and schema.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused `repair-state.json` repair-summary fixture files, exact JSON shape assertions, repair execute write-order/source-boundary assertions, explicit current non-reader and non-healthcheck evidence, and minimal watcher-core test wiring needed to prove the selected fixture remains aligned with the current repair compatibility contract.
- Out of scope: Fixtures for `runtime-owner.json`, checked-in compatibility snapshots, or live `issue-snapshot.json`; remaining healthcheck-contract slices except the selected `repair-state.json` non-reader boundary; external operator/downstream inventory; compatibility file deletion or rename; schema migration; repair behavior, replay behavior, healthcheck behavior, script behavior, or write-timing changes; public deprecation; facade removal; Cabal exposure changes; roadmap edits; controller state edits; and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, milestone 002 remains in progress, and this extracts the next narrow remaining fixture slice from direction 007 after rounds 090, 091, and 092 completed only the planner/planning, daemon-state, and repair-failure block-state fixture slices.

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
Milestone 001 is complete, so milestone 002 remains the dependency-ready prerequisite before runtime compatibility cleanup gates can proceed. Within milestone 002, direction 005 supplied the compatibility fixture gap inventory, direction 006 locked the distinct planner/planning state contract, round 089 completed only the `runtime-owner.json` healthcheck-contract slice of direction 008, and rounds 090 through 092 completed only selected direction 007 fixture slices for planner/planning, daemon-state, and repair-failure `block-state.json`.

The round-087 inventory orders the next immediate fixture blocker as `repair-state.json` repair summary coverage. That file is currently written by repair execution, has no production Haskell reader and no healthcheck reader, and still lacks a checked-in fixture. Adding focused fixture and test evidence now advances the required runtime-state evidence base while avoiding behavior, schema, healthcheck, repair, script, deprecation, migration, or removal changes.
