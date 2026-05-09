### Selected Extraction
- Milestone: Expand Follow-Up Backlog Before Terminal Cleanup
- Milestone id: `milestone-004-expand-follow-up-backlog`
- Direction id: `direction-008-roadmap-expansion-update`
- Extracted item id: `round-059-roadmap-expansion-update`
- Extracted item summary: Publish the roadmap expansion decision from round 058 discovery and, when justified by that evidence, author a new active roadmap revision containing additional cleanup and evidence milestones or directions before final removals.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: a roadmap-update artifact for the round 058 discovery decision; a new immutable roadmap revision if the discovered follow-up items justify expansion; activation metadata notes for any changed `roadmap_id`, `roadmap_revision`, or `roadmap_dir`; compact milestone and direction sequencing for additional compatibility cleanup evidence before gated removals.
- Out of scope: production source, test, or docs policy changes; actual removals, migrations, or deprecations; Cabal exposure changes; compatibility file or import surface changes; package publication; release gates; or marking gated removals complete.
- Concurrent batch context: none. The controller is in serial mode with `max_parallel_rounds=1`, and this update controls future roadmap coordination.

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
Milestone 004 is dependency-ready because milestone 003 is complete and round 058 completed `direction-007-follow-up-discovery` as `ada64b6`. The active roadmap now leaves milestone 004 pending specifically on `direction-008-roadmap-expansion-update`, whose purpose is to decide whether the round 058 candidates should become a new active roadmap revision before any terminal cleanup or gated removal work begins.

Round 058 found concrete follow-up candidates across import-facade evidence, runtime compatibility-file fixtures and policy, runtime-owner, daemon-state, PR state/path, block-state, live issue-snapshot, and external operator/downstream inventory work. The next valuable extraction is therefore not a removal round: it is the serial roadmap expansion decision that either publishes those candidates into reviewed future milestones and directions or records why no expansion is justified.
