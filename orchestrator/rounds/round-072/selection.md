### Selected Extraction
- Milestone: Perform Gated Compatibility Removals
- Milestone id: `milestone-008-gated-compatibility-removals`
- Direction id: `none-selected-no-lawful-removal-surface`
- Extracted item id: `round-072-no-lawful-removal-surface-status`
- Extracted item summary: No milestone-008 removal extraction is lawful yet. Record that no exact import facade or runtime compatibility surface currently satisfies the removal gates, because round 071 inventory preserves unavailable external evidence, blocked approval evidence, missing unsupported-user decisions, and per-surface blockers.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Selection-status evidence only: identify that `milestone-008-gated-compatibility-removals` is dependency-reached after milestone 007, but neither removal direction has an exact surface with satisfied gates and reviewer approval.
- Out of scope: Deprecation, migration, removal, publication, upload, release, Cabal exposure changes, production import rewrites, schema changes, filename changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, operator behavior changes, unsupported-user decisions, and reviewer approval of any removal.
- Concurrent batch context: none; the active controller state has `max_parallel_rounds` set to 1, and no milestone-008 removal surface is ready for parallel selection.

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
The active roadmap is `2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`. Milestones 001 through 007 are complete, and round 071 completed `direction-020-external-operator-downstream-inventory` for milestone 007. That makes milestone 008 the next pending milestone in roadmap order, but milestone 008 allows removal only when a selected round names exact surfaces, records every satisfied gate, and has reviewer approval for that exact removal evidence.

The current roadmap progress text says round 071 did not approve any exact surface for removal. The round 071 inventory records unavailable external downstream repositories, unavailable live state archives, unavailable external operator scripts, blocked operator/reviewer/release-gate approval evidence, no recorded unsupported-user decisions, and per-surface blockers for every inventoried public import facade and runtime compatibility path. Under the roadmap gates, neither `direction-021-remove-approved-import-facades` nor `direction-022-remove-approved-runtime-compatibility-surfaces` has a lawful exact removal surface to select.

Milestone 009 contains hold/closeout directions, but it depends on milestone 008. Because milestone 008 has not produced approved removals or an approved hold decision yet, this select-task artifact records the selection uncertainty and blockage rather than selecting milestone 009 prematurely. The next controller action should route this no-lawful-removal status for review or roadmap-update handling; it should not infer approval for any removal from this artifact.
