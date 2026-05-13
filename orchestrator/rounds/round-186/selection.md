### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011e-core-ids-domain-loop-production-imports`
- Extracted item id: `round-186-issue-implement-loop-core-ids-import-migration-or-classification`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/Domain/IssueImplement/Loop.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct id owner imports while preserving issue-implementation request-id threading, worker/reviewer thread handling, repo/issue/PR rendering, event append order, daemon transition behavior, app-server turn classification, command rendering, and failure text.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Domain/IssueImplement/Loop.hs` imports for the id types currently pulled from `CodexWatcher.Core.Ids` (`BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RequestId`, and `ThreadId`), using direct owner modules when focused issue-implementation loop evidence proves the move safe; otherwise record the exact behavior blocker/classification for this file.
- Out of scope: `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, any other production file, tests/fixtures, `src/CodexWatcher/Core/Ids.hs`, daemon-loop state transition changes, event append order changes, app-server turn classification changes, request-id progression changes, repo/issue/PR command rendering changes, failure text changes, compatibility file deletion or rename, compatibility write timing changes, healthcheck or repair behavior changes, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, terminal completion, release approval, and public compatibility removal.
- Concurrent batch context: none; default execution is serial with `max_parallel_rounds: 1`, and `direction-011e` says to prefer one loop per round unless disjoint behavior and verification justify pairing loops. Round 185 already handled the planning loop, so this selection intentionally isolates the remaining issue-implementation loop.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress, and that milestone depends only on the already completed test-topology inventory. The active roadmap records round 185 as an import-only migration for `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and names `src/CodexWatcher/Domain/IssueImplement/Loop.hs` as the remaining production `Core.Ids` user.

Selecting the issue-implementation loop now follows `direction-011e` and keeps the round to the preferred one-file import-only slice. The selected file currently imports `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RequestId`, and `ThreadId` through the combined facade, while the public facade reexports direct agent and GitHub id owner modules. A safe implementation should replace only that facade import or classify the exact blocker if behavior evidence does not support the move.

This slice must run before `direction-011g-core-ids-production-closeout-classification`, because closeout requires all safe production migration slices to have landed or been reviewed as blocked. It also stays ahead of milestone 004 test/fixture import work and leaves public facade, Cabal, docs, runtime compatibility cleanup, milestone completion, terminal completion, and public compatibility removal for separately selected gates.
