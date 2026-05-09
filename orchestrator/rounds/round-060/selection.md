### Selected Extraction
- Milestone: Complete Import-Facade Follow-Up Evidence
- Milestone id: `milestone-005-import-facade-follow-up-evidence`
- Direction id: `direction-009-core-ids-split-import-evidence`
- Extracted item id: `round-060-core-ids-split-import-evidence`
- Extracted item summary: Produce evidence for `CodexWatcher.Core.Ids` by refreshing recursive import usage, confirming package-boundary exposure, and mapping agent-id versus GitHub-id ownership and migration risks without changing the public facade.
- Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

### Boundaries
- In scope: source-backed evidence for `CodexWatcher.Core.Ids`; recursive import scan across source, tests, examples, package docs, Cabal descriptors, public package docs, and available downstream/operator references; current package-boundary assertions; ownership map separating agent identifiers from GitHub identifiers; explicit migration risks and remaining blockers for later cleanup decisions.
- Out of scope: deprecation pragmas, facade removal or narrowing, Cabal exposed-module changes, production import migration, event schema changes, runtime compatibility-file changes, package publication, release approval, or any gated-removal decision.
- Concurrent batch context: none. The controller is in serial mode with `max_parallel_rounds=1`; this is the first import-facade follow-up evidence item in milestone 005.

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
The active state resolves to roadmap `2026-05-09-01-compatibility-surface-cleanup` revision `rev-002`, and that revision records milestones 001 through 004 as complete through rounds 052-059. Milestone 005 is therefore the first dependency-ready pending milestone: it depends on milestone 004, whose roadmap expansion work has already completed and activated this revision.

Within milestone 005, `direction-009-core-ids-split-import-evidence` is the first listed candidate direction and matches the required evidence-first ordering for import facades. It is narrower than the other pending import-facade directions and directly satisfies the roadmap's stated preconditions for `CodexWatcher.Core.Ids`: a refreshed recursive import scan and current package-boundary assertions before any later downstream compatibility, deprecation, or removal selection. No merge dependency fields are needed because the ordering prerequisites are already completed in the active roadmap and there are no concurrent or pending merge rounds for this serial selection.
