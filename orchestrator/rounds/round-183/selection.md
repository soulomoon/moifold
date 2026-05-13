### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011c-core-ids-runtime-compatibility-production-classification`
- Extracted item id: `round-183-runtime-compatibility-core-ids-import-migration-or-classification`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/Runtime/Compatibility.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports while preserving current compatibility write paths, JSON shapes, write timing, repair and healthcheck behavior, and runtime state semantics.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Runtime/Compatibility.hs` imports for the id types currently pulled from `CodexWatcher.Core.Ids`, using direct owner modules when focused runtime compatibility evidence proves the move safe; otherwise record the exact runtime-compat blocker/classification for this file.
- Out of scope: compatibility file deletion or rename, compatibility write timing changes, compatibility JSON shape migration, repair behavior changes, healthcheck behavior changes, event schema or replay changes, domain-loop imports, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, and public compatibility removal.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`, and `direction-011c` is serial with healthcheck and runtime cleanup milestones.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences production `Core.Ids` imports before test/fixture imports. Round 182 completed the event-log production import slice and left four production users: `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.

Selecting `Runtime/Compatibility.hs` now follows the next active roadmap direction and keeps the production burndown finite without jumping to public facade, Cabal, docs, or runtime compatibility-file cleanup. The file is a high-value remaining production user because compatibility writes are later removal gates; making its id ownership explicit, or classifying exactly why it cannot yet move, gives milestone 003 a concrete closeout path.

The planner and reviewer should require the baseline checks plus focused runtime compatibility evidence for current compatibility file names, fixture shapes, healthcheck reader/non-reader contracts, summary paths, write timing, repair boundaries, and selected-file direct-owner imports. They should also require a selected-file scan proving `src/CodexWatcher/Runtime/Compatibility.hs` no longer imports `CodexWatcher.Core.Ids` when migrated, plus a broad remaining-user scan that separates production users from tests, docs, Cabal files, and the public facade module. Successful migration or classification here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.
