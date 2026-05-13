### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011b-core-ids-golden-replay-production-import`
- Extracted item id: `round-178-golden-replay-core-ids-split-import-migration`
- Extracted item summary: Migrate `src/CodexWatcher/GoldenReplay.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct GitHub and agent id owner imports, preserving replay and bootstrap behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/GoldenReplay.hs` imports for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`, and `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`; keep constructors and field accessors available exactly as before.
- Out of scope: snapshot normalization changes, replay warning changes, bootstrap event changes, fixture edits, event JSON/schema changes, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility file changes, and milestone completion.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`.

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
`rev-002` marks `milestone-003-core-ids-production-import-burndown` as the active finite production import queue, and `GoldenReplay.hs` remains one of the listed production `CodexWatcher.Core.Ids` users. It is a smaller next slice than `EventLog.Types`, `Runtime.Compatibility`, `Healthcheck`, the domain loops, or the CLI group because the file only needs direct id-owner imports and the roadmap already isolates it under `direction-011b`. This should run now because golden replay is compatibility evidence for later event and runtime cleanup, but this round can keep the change to import ownership only.

The planner and reviewer should require focused golden replay and snapshot normalization evidence, selected-file scans proving `src/CodexWatcher/GoldenReplay.hs` no longer imports `CodexWatcher.Core.Ids`, and the broad remaining-user scan that separates production users from tests, docs, Cabal, and the public facade module. Successful import migration in this file must not be treated as public facade deprecation/removal, Cabal cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
