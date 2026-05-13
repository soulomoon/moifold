### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011d-core-ids-healthcheck-production-import`
- Extracted item id: `round-184-healthcheck-core-ids-import-migration-or-classification`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/Healthcheck.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports while preserving healthcheck JSON shapes, summary paths, reader set, command rendering, app-server thread checks, and runtime-state semantics.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Healthcheck.hs` imports for the id types currently pulled from `CodexWatcher.Core.Ids`, using direct owner modules when focused healthcheck parsing/rendering and runtime-state reader evidence proves the move safe; otherwise record the exact healthcheck blocker/classification for this file.
- Out of scope: domain-loop imports, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, healthcheck JSON shape changes, summary path changes, reader set changes, command rendering changes, app-server behavior changes, compatibility file deletion or rename, compatibility write timing changes, repair behavior changes, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, and public compatibility removal.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`, and `direction-011d` is serial with runtime compatibility work.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences production `Core.Ids` imports before test/fixture imports. Round 183 completed `direction-011c` for `src/CodexWatcher/Runtime/Compatibility.hs`, and the active roadmap now lists only `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs` as remaining production users.

Selecting `Healthcheck.hs` now follows the next active milestone-003 direction and keeps the production burndown finite without jumping to the domain-loop pair, test/fixture imports, public facade, Cabal, docs, or runtime compatibility-file cleanup. The file is an operator-facing reader with clear direct id owner modules and focused verification requirements; making its id ownership explicit, or classifying exactly why it cannot yet move, reduces the remaining production set before the more behavior-heavy loop slices.

The planner and reviewer should require the baseline checks plus focused healthcheck evidence for parsing/rendering, runtime-state reader/non-reader contracts, summary paths, command rendering, app-server thread checks, current compatibility file names, fixture shapes, repair boundaries, and selected-file direct-owner imports. They should also require a selected-file scan proving `src/CodexWatcher/Healthcheck.hs` no longer imports `CodexWatcher.Core.Ids` when migrated, plus a broad remaining-user scan that separates production users from tests, docs, Cabal files, and the public facade module. Successful migration or classification here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.
