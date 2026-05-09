### Selected Extraction
- Milestone: Complete Runtime Compatibility Follow-Up Evidence
- Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
- Direction id: `direction-019-live-issue-snapshot-fixture-timing`
- Extracted item id: `direction-019-live-issue-snapshot-fixture-timing`
- Extracted item summary: Add live `issue-snapshot.json` fixture and write-timing evidence for issue-planning snapshot creation before planner turn start.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: Evidence for the current issue-planning write path, timing tests, and live `issue-snapshot.json` fixture coverage needed to prove snapshot creation before planner turn start.
- Out of scope: Filename or schema changes, event type changes, planner turn behavior changes, compatibility projection changes, healthcheck or repair behavior changes, runtime cleanup/removal, and any work from later milestones.
- Concurrent batch context: none; the active roadmap and state use the default serial lane with `max_parallel_rounds` 1.

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
The active roadmap revision is `rev-002`, and milestone 006 depends only on milestone 005, which is complete. Within milestone 006, directions 013 through 018 are already complete via rounds 064 through 069, while `direction-019-live-issue-snapshot-fixture-timing` is the only unresolved candidate direction. Selecting it now preserves the roadmap's serial runtime-compatibility evidence order and keeps live snapshot timing treated as a workflow contract before any later external inventory or removal gate can run.
