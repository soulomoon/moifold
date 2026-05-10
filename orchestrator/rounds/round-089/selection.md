### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-008-healthcheck-compatibility-contracts`
- Extracted item id: `round-089-runtime-owner-healthcheck-contract`
- Extracted item summary: Add or refresh focused healthcheck contract evidence for `runtime-owner.json`, including the current healthcheck reader status, the current `runtimeOwner` field-path behavior against the stored lease JSON shape, and explicit preservation of behavior without changing file names, readers, schemas, fixtures, or cleanup policy.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused tests or source-policy assertions that lock current `runtime-owner.json` healthcheck behavior, including that healthcheck treats it as the `runtimeOwner` state surface and records the current field-path contract for the lease-shaped JSON that runtime owner code writes.
- Out of scope: Broad runtime compatibility fixture additions, daemon/block/repair/planning/live issue-snapshot fixture work, compatibility file deletion or rename, schema migration, healthcheck behavior changes, repair behavior changes, runtime owner producer changes, public deprecation, facade removal, Cabal exposure changes, roadmap edits, controller state edits, and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, directions 005 and 006 are complete, and this round selects one narrow healthcheck-contract blocker inside pending milestone 002.

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
Milestone 001 is complete, and milestone 002 is the active pending prerequisite before runtime compatibility cleanup gates can proceed. Direction 005 supplied the current fixture gap inventory, and direction 006 completed the `planner-state.json` versus `planning-state.json` contract. Those completed directions must not be reselected.

Among the remaining milestone 002 choices, direction 007 would start a broader fixture campaign across several state files. The smaller next valuable extraction is a focused direction 008 slice for `runtime-owner.json`, because round-087 identified its healthcheck field-path behavior as a specific healthcheck-contract blocker while preserving it as a kept compatibility surface. This round should make that current contract explicit before any later fixture, operator/downstream, migration, or removal decision, and it must not change healthcheck behavior or treat the contract as cleanup approval.
