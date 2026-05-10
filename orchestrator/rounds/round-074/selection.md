### Selected Extraction
- Milestone: Close The Cleanup Family
- Milestone id: `milestone-009-close-cleanup-family`
- Direction id: `direction-024-terminal-cleanup-gate`
- Extracted item id: `round-074-terminal-cleanup-gate`
- Extracted item summary: Produce the explicit terminal done-or-hold decision artifact and supporting notes for the current rev-003 hold path after the approved round 073 final compatibility surface report.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-003`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003`

### Boundaries
- In scope: Round-local terminal gate artifact and supporting notes only: decide whether the current rev-003 hold path should close as a reviewed hold or remain blocked, cite the round 073 final report, preserve milestone 008 as held rather than removal-complete, carry forward explicit blockers, and record any validation/readback evidence needed for that hold-or-closeout decision.
- Out of scope: Package publication, public release, upload, deprecation, migration, removal, Cabal exposure changes, production import rewrites, compatibility behavior changes, schema or filename changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, operator behavior changes, roadmap expansion, state.json mutation, production code, tests, package descriptors, and silent terminal completion.
- Concurrent batch context: none; the active controller state has `max_parallel_rounds` set to 1, round 073 and its roadmap update are already merged, and rev-003 records `direction-024-terminal-cleanup-gate` as the next lawful serial dispatch after the final report.

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
The active roadmap is `2026-05-09-01-compatibility-surface-cleanup` revision `rev-003`, with active roadmap dir `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-003`. State records `round-073` as the last completed round and `round-074` as the current `select-task` round.

Rev-003 records milestone 008 as held rather than removal-complete. That hold does not approve deprecation, migration, removal, publication, release, Cabal exposure changes, production import rewrites, or compatibility behavior changes. Round 073 completed `direction-023-final-compatibility-surface-report` via commit `37cde0a`, carrying forward kept and deferred compatibility surfaces, preserving the removed-surface set as empty, and leaving `direction-024-terminal-cleanup-gate` out of scope.

The round 073 roadmap update and its review keep milestone 009 pending until `direction-024-terminal-cleanup-gate` is selected, reviewed, and accepted. This selection therefore extracts only the terminal gate for the current hold path. On the current evidence, terminal completion means a reviewed hold or explicit continued hold with blockers; it must not silently mark the family done or convert the held removal milestone into cleanup, publication, release, deprecation, migration, Cabal exposure, production import, or compatibility behavior approval.
