### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-005-compatibility-fixture-gap-inventory`
- Extracted item id: `round-087-compatibility-fixture-gap-inventory`
- Extracted item summary: Refresh fixture gaps for planning, daemon, block, repair, runtime-owner, checked-in snapshots, and live issue-snapshot compatibility surfaces, comparing producers/readers, healthcheck readers, golden snapshots, docs policy, and remaining evidence blockers without changing runtime behavior or file names.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: Round-local inventory evidence for runtime compatibility fixture gaps, including production producer/reader scans, healthcheck reader evidence, existing golden/snapshot fixture coverage, docs or policy references, and prioritized blockers for later fixture and contract rounds.
- Out of scope: Production code, test code, Cabal files, docs changes, fixture additions, compatibility file deletion or rename, healthcheck behavior changes, repair behavior changes, import convergence, public deprecation, facade removal, runtime compatibility-file migration/removal, roadmap updates, and controller state edits.
- Concurrent batch context: none; this is serial. Active state has `max_parallel_rounds: 1`, milestone 002 needs a shared fixture gap inventory before fixture additions or healthcheck contract work, and no lawful concurrent batch is selected for this round.

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
Milestone 001 is completed in the active roadmap by rounds 083 through 086, so `milestone-002-compatibility-fixtures-contracts` is dependency-ready. Milestones 005 and 006 remain blocked by milestone 002 and later import-convergence evidence, while milestones 003 and 004 are also ready but are larger cleanup tracks that do not unblock runtime compatibility-file decisions as directly.

Within milestone 002, `direction-005-compatibility-fixture-gap-inventory` is the smallest next valuable extraction. It is explicitly serial, changes no runtime behavior or file names, and establishes the fixture ownership and priority evidence needed before `direction-006-planner-vs-planning-state-contract`, `direction-007-runtime-compatibility-fixtures`, or `direction-008-healthcheck-compatibility-contracts` can proceed without guessing. The prior round-083 inventory already named uneven fixture coverage; this round narrows that broad evidence into the compatibility-fixture gap map required for later fixture, healthcheck, and cleanup-gate selections.
