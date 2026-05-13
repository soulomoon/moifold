### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011e-core-ids-domain-loop-production-imports`
- Extracted item id: `round-185-issue-planning-loop-core-ids-import-migration-or-classification`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports while preserving planning-loop request-id progression, planner thread/turn handling, repo/issue rendering, event append order, daemon transition behavior, app-server turn classification, and failure text.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` imports for the id types and helpers currently pulled from `CodexWatcher.Core.Ids`, using direct owner modules when focused planning-loop evidence proves the move safe; otherwise record the exact planning-loop blocker/classification for this file.
- Out of scope: `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, daemon-loop state transition changes, event append order changes, app-server turn classification changes, request-id progression changes, repo/issue command rendering changes, failure text changes, compatibility file deletion or rename, compatibility write timing changes, healthcheck or repair behavior changes, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, and public compatibility removal.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`, and `direction-011e` says to prefer one loop per round unless disjoint behavior and verification justify pairing both loops. This selection intentionally leaves the issue-implementation loop for a later round.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences remaining production `Core.Ids` imports before test/fixture imports, public-surface cleanup, Cabal cleanup, docs cleanup, and runtime compatibility cleanup. Round 184 completed the Healthcheck production import slice, and the active roadmap now names only `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and `src/CodexWatcher/Domain/IssueImplement/Loop.hs` as remaining production users.

Selecting the issue-planning loop now follows `direction-011e` while respecting its one-loop-per-round guidance. The planning loop is high-traffic runtime behavior, but it has a narrower first slice than the issue-implementation loop: its current facade import covers `IssueNumber`, `RepoName`, `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId`, with focused evidence around planner thread startup, request-id advancement, active-turn handling, snapshot fetching, repo/issue rendering, and planning failure text. Handling this file first reduces the remaining production set without pairing two behavior-heavy loops in one round.

The planner and reviewer should require baseline validation plus focused planning-loop behavior evidence for request-id progression, thread/turn id handling, repo/issue rendering, event append order, daemon transition behavior, app-server turn classification, and failure text. They should also require a selected-file scan proving `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` no longer imports `CodexWatcher.Core.Ids` when migrated, plus a broad remaining-user scan that separates remaining production users from tests, docs, Cabal files, and the public facade module. Successful migration or classification here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, terminal completion, or public compatibility removal.
