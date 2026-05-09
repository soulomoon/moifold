### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-017-pr-state-external-path-inventory`
- Extracted item id: `direction-017-pr-state-external-path-inventory`
- Extracted item summary: Inventory PR review compatibility state files, PR URL fields, absent dedicated PR URL/state paths, runbooks, scripts, and downstream/operator expectations before any later cleanup decision.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current PR review compatibility outputs: state files, PR URL field usage, absence or presence of dedicated PR URL/state paths, relevant runbooks and scripts, downstream/operator expectations, current PR review compatibility output readback, and golden fixture readback.
- Out of scope: Filename changes, schema changes, event `type` changes, PR review state projection behavior changes, PR URL storage migration, healthcheck or repair redesign, production cleanup, removal, deprecation, package publication, upload, or release approval.
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
Milestones 001 through 005 are complete, so milestone 006 is dependency-ready because it depends only on `milestone-005-import-facade-follow-up-evidence`. The active roadmap records rounds 064 through 067 as completing directions 013 through 016, and states that milestone 006 remains pending because directions 017 through 019 are unresolved.

`direction-017-pr-state-external-path-inventory` is therefore the next serial unresolved direction in milestone 006. It is a bounded evidence extraction for PR review compatibility state and PR URL path expectations, with preconditions limited to current PR review compatibility output and golden fixture readback. This selection preserves all current compatibility outputs and keeps later cleanup, migration, deprecation, or removal decisions behind explicit future evidence and reviewer approval.
