### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-007-runtime-compatibility-fixtures`
- Extracted item id: `round-091-daemon-state-compatibility-fixtures`
- Extracted item summary: Add focused checked-in fixture coverage and watcher-core assertions for current `daemon-state.json` active and stopped compatibility shapes, preserving current producers, readers, healthcheck behavior, repair rewrite behavior, restart cleanup behavior, filenames, and schemas.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused `daemon-state.json` fixture files, exact JSON shape assertions, current `compatibilityStateWrites` coverage for representative active and stopped daemon states, and minimal watcher-core test wiring needed to prove the selected fixtures remain aligned with the current compatibility contract.
- Out of scope: Fixtures for `block-state.json`, `repair-state.json`, `runtime-owner.json`, checked-in compatibility snapshots beyond the selected daemon files, or live `issue-snapshot.json`; remaining healthcheck-contract slices under direction 008; external operator/downstream inventory; compatibility file deletion or rename; schema migration; producer, reader, healthcheck, repair, script, or write-timing behavior changes; public deprecation; facade removal; Cabal exposure changes; roadmap edits; controller state edits; and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, milestone 002 is in progress, and this extracts one narrow remaining fixture slice from direction 007 after round 090 completed only the planner/planning fixture slice.

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
Milestone 001 is complete, so milestone 002 remains the dependency-ready prerequisite before runtime compatibility cleanup gates can proceed. Within milestone 002, direction 005 supplied the compatibility fixture gap inventory, direction 006 locked the distinct `planner-state.json` and `planning-state.json` contract, round 089 completed only the `runtime-owner.json` healthcheck-contract slice of direction 008, and round 090 completed only the planner/planning fixture slice of direction 007. Those accepted slices do not complete milestone 002 and do not approve runtime compatibility cleanup.

The smallest next valuable extraction is the next direction 007 fixture blocker from the round-087 inventory: active and stopped `daemon-state.json` fixtures. `daemon-state.json` is still a kept compatibility surface with production compatibility writers, healthcheck readers, snapshot/repair interactions, restart cleanup behavior, and only an older checked-in issue-implementation snapshot fixture. Adding focused current active/stopped fixture evidence now advances the fixture base needed for later cleanup classification while avoiding behavior, schema, healthcheck, repair, script, deprecation, migration, or removal changes.
