### Selected Extraction
- Milestone: Expand Follow-Up Backlog Before Terminal Cleanup
- Milestone id: `milestone-004-expand-follow-up-backlog`
- Direction id: `direction-007-follow-up-discovery`
- Extracted item id: `round-058-follow-up-discovery`
- Extracted item summary: Review the completed inventories, cleanup policy docs, tests, TODOs, and reviewer notes from the compatibility-surface cleanup family to discover follow-up cleanup items before removal rounds; produce a compact candidate list with source evidence and recommended milestone placement.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001`

### Boundaries
- In scope: read the source-backed inventory artifacts from rounds 052 and 053, readiness and behavior-gate artifacts from rounds 054 and 055, cleanup policy artifacts and reviewer notes from rounds 056 and 057, current policy docs, relevant tests, TODOs, and source references needed to identify follow-up cleanup candidates; write a round-local discovery artifact with candidate items, evidence, blockers, and recommended milestone placement for later roadmap expansion.
- Out of scope: editing roadmap status or roadmap revision, publishing a roadmap expansion, performing removals, changing source, tests, docs policy, runtime compatibility files, import surfaces, Cabal exposure, deprecation/removal approval, or runtime behavior.
- Concurrent batch context: none. The controller is serial, milestone 004 is serial, and this discovery item must complete before `direction-008-roadmap-expansion-update`.

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
Milestone 003 is complete in the active roadmap: round 056 documented the import-facade cleanup policy, and round 057 documented the runtime compatibility-file cleanup policy. That satisfies milestone 004's dependency on `milestone-003-evidence-backed-cleanup-policy`.

The active roadmap's global sequencing rule requires a follow-up discovery and roadmap-update round near the end of the initial pending list before terminal cleanup begins. `direction-007-follow-up-discovery` is therefore the next dependency-ready extraction: it is the first open direction in milestone 004, and `direction-008-roadmap-expansion-update` depends on discovery completion.

This selection keeps the round evidence-only. It lets the next roles inspect the merged evidence from rounds 052-057 and prepare a compact, source-backed candidate list without changing production code, public compatibility facades, runtime compatibility files, policy docs, roadmap revision metadata, or removal approval state.
