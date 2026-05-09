### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-018-block-state-repair-failure-fixture`
- Extracted item id: `direction-018-block-state-repair-failure-fixture`
- Extracted item summary: Add focused evidence for repair-failure `block-state.json` output shape, direct blocked writes, healthcheck reads, and stale-block cleanup before any later cleanup decision.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for repair-failure `block-state.json` compatibility output shape, direct blocked writes, healthcheck reads, stale-block cleanup behavior, and the current runner, effect interpreter, compatibility projection, and healthcheck paths that satisfy the direction preconditions.
- Out of scope: Filename changes, schema changes, event `type` changes, write-timing changes, healthcheck behavior changes, repair behavior changes, compatibility projection changes, stale-block cleanup redesign, production cleanup, removal, deprecation, package publication, upload, or release approval.
- Concurrent batch context: none; `max_parallel_rounds` is 1 and the active roadmap sets the default lane to serial for compatibility cleanup.

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
Milestones 001 through 005 are complete, so milestone 006 is dependency-ready because it depends only on `milestone-005-import-facade-follow-up-evidence`. The active roadmap records rounds 064 through 068 as completing directions 013 through 017, and states that milestone 006 remains pending because directions 018 and 019 are unresolved.

`direction-018-block-state-repair-failure-fixture` is therefore the next serial unresolved direction in milestone 006. It is a bounded evidence extraction for repair-failure block-state compatibility behavior, with preconditions limited to current runner, effect interpreter, compatibility projection, and healthcheck readback. This selection preserves all current compatibility outputs and keeps later cleanup, migration, deprecation, or removal decisions behind explicit future evidence and reviewer approval.
