### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-007-runtime-compatibility-fixtures`
- Extracted item id: `round-095-live-issue-snapshot-compatibility-fixtures`
- Extracted item summary: Add focused checked-in fixture or fixture-equivalent evidence and watcher-core assertions for the current live `issue-snapshot.json` shape written before planner turn start and rendered into planner prompt output, preserving current file name, schema, write timing, prompt behavior, and healthcheck/repair/replay/restart non-reader boundaries.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: live `issue-snapshot.json` fixture or fixture-equivalent evidence, focused watcher-core assertions for current writer timing and prompt consumption, and source-boundary checks proving current non-reader behavior for healthcheck, repair, replay, and restart paths.
- Out of scope: deleting, renaming, migrating, or changing `issue-snapshot.json`; changing planner prompt semantics; changing healthcheck, repair, replay, restart, or compatibility write behavior; broad runtime compatibility cleanup decisions; public deprecation, Cabal exposure changes, facade removal, release approval, or milestone completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, milestone 002 remains in progress, and this extracts one remaining direction 007 fixture blocker after rounds 090 through 094 completed only the planner/planning, daemon-state, repair-failure block-state, repair-state, and runtime-owner fixture slices.

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
Milestone 001 is complete, so milestone 002 remains dependency-ready and is still the active prerequisite before runtime compatibility cleanup gates can proceed. Direction 005 supplied the current fixture gap inventory, direction 006 locked the distinct planner/planning state contract, round 089 completed only the runtime-owner healthcheck-contract slice of direction 008, and rounds 090 through 094 completed selected direction 007 fixture slices for planner/planning, daemon-state, repair-failure `block-state.json`, `repair-state.json`, and `runtime-owner.json`.

The round-087 inventory still lists live `issue-snapshot.json` fixture or fixture-equivalent evidence for planner prompt consumption and write timing as an immediate fixture blocker. Selecting this slice now keeps the roadmap on its evidence-first cleanup path, advances the incomplete direction 007 without implying any migration or removal approval, and leaves later healthcheck-contract, operator/downstream, classification, import-convergence, large-module, and final removal work for separate reviewed rounds.
