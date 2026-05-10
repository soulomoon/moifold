### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-007-runtime-compatibility-fixtures`
- Extracted item id: `round-090-planner-planning-compatibility-fixtures`
- Extracted item summary: Add focused checked-in fixture coverage and tests for the current `planner-state.json` and `planning-state.json` compatibility shapes, using the reviewed planner/planning contract from round 088 and preserving current file names, producers, readers, write timing, and healthcheck behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused fixture files, fixture parsing/shape tests, and any minimal watcher-core test wiring needed to cover `planner-state.json` summary/status output and `planning-state.json` planning-graph output for the current compatibility contract.
- Out of scope: Fixtures for `daemon-state.json`, `block-state.json`, `repair-state.json`, `runtime-owner.json`, checked-in compatibility snapshots, or live `issue-snapshot.json`; remaining healthcheck-contract slices under direction 008; compatibility file deletion or rename; schema migration; producer, reader, healthcheck, repair, script, or write-timing behavior changes; public deprecation; facade removal; Cabal exposure changes; roadmap edits; controller state edits; and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, milestone 002 is in progress, and this extracts one narrow fixture slice from pending direction 007 after directions 005 and 006 completed and direction 008 recorded only a partial runtime-owner healthcheck contract.

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
Milestone 001 is complete, so milestone 002 is dependency-ready and remains the active prerequisite before runtime compatibility cleanup gates can proceed. Direction 005 supplied the fixture gap inventory, direction 006 locked the `planner-state.json` versus `planning-state.json` compatibility contract, and direction 008 is only partial after round 089 recorded the `runtime-owner.json` healthcheck slice. Those completed or partial items should not be reselected as complete milestone work.

The smallest next valuable extraction is the first direction 007 fixture slice for `planner-state.json` and `planning-state.json`. Round 087 lists these as the highest-priority immediate fixture blockers, and round 088 provides the reviewed producer, reader, healthcheck, docs, and write-timing contract needed to add fixture evidence without guessing. This round should create the checked-in evidence base for the two planning surfaces before broader fixture batches, remaining healthcheck non-reader/read-contract slices, or any cleanup-gate classification work. It must preserve behavior and must not treat fixture coverage as approval for rename, deletion, migration, deprecation, or removal.
