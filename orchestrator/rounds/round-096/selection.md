### Selected Extraction
- Milestone: Compatibility Fixtures And Runtime-State Contracts
- Milestone id: `milestone-002-compatibility-fixtures-contracts`
- Direction id: `direction-008-healthcheck-compatibility-contracts`
- Extracted item id: `round-096-runtime-state-healthcheck-read-nonread-contracts`
- Extracted item summary: Consolidate focused healthcheck read/non-read contract evidence for the selected runtime compatibility-state surfaces now that rounds 090-095 added the fixture base, preserving current healthcheck file mappings and explicit non-reader boundaries without behavior changes.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001`

### Boundaries
- In scope: focused watcher-core tests or source-policy assertions for current healthcheck reads of `daemon-state.json`, `planner-state.json`, `block-state.json`, and `runtime-owner.json`, plus explicit healthcheck non-reader assertions for `planning-state.json`, `repair-state.json`, and live `issue-snapshot.json`.
- Out of scope: production healthcheck behavior changes; runtime compatibility file deletion, rename, schema migration, or writer changes; repair, replay, restart, prompt, or snapshot behavior changes; fixture batch completion claims beyond existing reviewed slices; external operator/downstream inventory; cleanup classification; public deprecation; facade removal; Cabal exposure changes; roadmap edits; controller state edits; release approval; or milestone completion claims.
- Concurrent batch context: none; active state is serial with `max_parallel_rounds: 1`, and this is one remaining healthcheck-contract slice after round-089 covered only the `runtime-owner.json` field-path contract and rounds 090-095 covered the selected fixture slices.

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
Milestone 001 is complete, so milestone 002 remains dependency-ready. Direction 005 supplied the compatibility fixture gap inventory, direction 006 locked the distinct `planner-state.json` versus `planning-state.json` contract, round-089 completed only the `runtime-owner.json` healthcheck field-path slice, and rounds 090-095 completed fixture evidence for planner/planning, daemon-state, repair-failure block-state, repair-state, runtime-owner, and live issue-snapshot surfaces.

The immediate fixture blockers are now covered, but direction 008 remains partial because the roadmap still requires explicit healthcheck contract evidence for selected read and non-read surfaces. Selecting this consolidation now keeps milestone 002 on its evidence-first path before operator/downstream inventory, cleanup classification, import convergence, large-module decomposition, or removal gates. The round should make the current healthcheck contract easier to review without changing healthcheck behavior or implying migration, deprecation, deletion, or public compatibility removal approval.
