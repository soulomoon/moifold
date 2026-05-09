### Selected Extraction
- Milestone: Write Cleanup Policy From Evidence
- Milestone id: `milestone-003-evidence-backed-cleanup-policy`
- Direction id: `direction-006-runtime-compatibility-cleanup-policy`
- Extracted item id: `round-057-runtime-compatibility-cleanup-policy`
- Extracted item summary: Document keep/defer/remove-later policy for runtime compatibility files and snapshots using the round 053 inventory and round 055 behavior-gate evidence, including required old-log, repair, healthcheck, and write-timing gates for every selected runtime compatibility surface.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: policy documentation for `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR review state files and PR URL fields, `block-state.json`, `repair-state.json`, `runtime-owner.json`, checked-in compatibility snapshots, and live `issue-snapshot.json`; citations to round 053 inventory and round 055 behavior-gate evidence; conservative keep/defer/remove-later classifications; required old-log, golden, repair, healthcheck, write-timing, fixture, and external-operator evidence before any future deprecation, migration, or removal.
- Out of scope: file migration or removal, schema changes, compatibility filename changes, compatibility write-timing changes, source/runtime behavior changes, import-facade policy, roadmap expansion, terminal cleanup, removal approval, healthcheck redesign, repair redesign, daemon ownership changes, app-server policy changes, and package-boundary changes unrelated to documenting the runtime compatibility-file cleanup policy.
- Concurrent batch context: none; the controller is serial with `max_parallel_rounds=1`, milestone 003's import-facade policy sibling completed in round 056, and this selection is the remaining pending runtime compatibility policy extraction.

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
Milestones 001 and 002 are complete, and round 056 completed the import-facade cleanup policy under milestone 003. The roadmap now names `direction-006-runtime-compatibility-cleanup-policy` as the remaining pending direction before milestone 003 can close. Its precondition, known runtime behavior gates, is satisfied by the completed round 055 artifact, while the source-backed runtime compatibility inventory from round 053 provides the selected file and snapshot surface.

This item should run now because runtime compatibility files are operator-visible contracts with stricter gates than import facades. The next planner needs a bounded policy-from-evidence task that preserves every current filename, schema, write order, repair path, healthcheck behavior, and runtime behavior while documenting which surfaces stay, which are deferred, and which gates would be required before any later removal candidate could be selected.
