### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-006-planner-vs-planning-state-contract`
- Extracted item id: `round-088-planner-vs-planning-state-contract`
- Extracted item summary: Record and test the compatibility contract for `planner-state.json` and `planning-state.json`, including producer paths, healthcheck reader versus non-reader behavior, docs/policy expectations, fixture expectations, and write-timing evidence without renaming files, deleting files, or changing healthcheck behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Focused contract and test evidence for the distinct `planner-state.json` and `planning-state.json` compatibility surfaces, using the round-087 fixture gap inventory as the current source of producer, reader, healthcheck, docs, and fixture blockers.
- Out of scope: Broad runtime compatibility fixture additions, compatibility file deletion or rename, schema migration, healthcheck reader changes, repair behavior changes, production import convergence, public deprecation, facade removal, Cabal exposure changes, roadmap edits, controller state edits, and unrelated runtime-state cleanup.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, direction 005 is complete, and milestone 002 still needs this narrow state-file contract before broad fixture, healthcheck-contract, or runtime cleanup gate work can proceed safely.

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
Milestone 001 is complete in the active roadmap, and round-087 completed `direction-005-compatibility-fixture-gap-inventory` for milestone 002 at `51774b6`. That inventory records `planner-state.json` and `planning-state.json` as distinct compatibility surfaces, identifies both producer paths, confirms healthcheck currently reads `planner-state.json` and not `planning-state.json`, and lists the missing contract, fixture, and write-timing evidence as blockers rather than cleanup approval.

Within the dependency-ready milestone 002 work, `direction-006-planner-vs-planning-state-contract` is the smallest next valuable extraction. It is narrower than broad fixture additions in direction 007 and narrower than all-surface healthcheck contract work in direction 008, while still unblocking both by making the planning state-file contract explicit. Milestone 005 remains blocked on completion of milestone 002, and this round does not select import-convergence or large-module work from later milestones because the pending compatibility-state contract is the more immediate runtime cleanup gate.
