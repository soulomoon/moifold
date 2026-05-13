### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011f-core-ids-cli-production-imports`
- Extracted item id: `round-181-issue-fanout-core-ids-split-import-migration`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/Cli/Command/IssueFanout.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct agent and GitHub id owner imports, preserving fanout planning, child launch, command rendering, and runtime behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Cli/Command/IssueFanout.hs` imports for agent-owned ids (`RequestId`, `ThreadId`) and GitHub-owned ids (`BranchName`, `IssueNumber`, `RepoName`) so the module no longer imports `CodexWatcher.Core.Ids`; if behavior evidence shows the split is not safe, record the exact blocker/classification for this file.
- Out of scope: fanout planning logic, active issue discovery, child launch state writes, request-id progression behavior, command rendering, dry-run text, runtime process execution, status interpretation, parser/type modules already handled by rounds 179 and 180, test/fixture imports, `src/CodexWatcher/Core/Ids.hs`, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility files, milestone completion, and terminal completion.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`, and `direction-011f` says one CLI file per round by default.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences production `Core.Ids` imports before test/fixture imports. The current production scan still reports `src/CodexWatcher/Cli/Command/IssueFanout.hs` as the only remaining CLI production user after round 179 completed `src/CodexWatcher/Cli/Parser/Common.hs` and round 180 completed `src/CodexWatcher/Cli/Types.hs`.

Selecting `IssueFanout.hs` now finishes the remaining `direction-011f` CLI production slice while staying smaller than event-log, healthcheck, runtime compatibility, or domain-loop surfaces. Its current `Core.Ids` use maps to direct owner modules already exposed through the facade: `RequestId` and `ThreadId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `IssueNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`. The planner should still preserve the fallback path: if focused CLI/fanout evidence shows this direct-owner split is not safe, the round should classify this specific remaining production import with the exact missing evidence rather than expanding into unrelated cleanup.

The planner and reviewer should require the baseline checks, a selected-file scan proving `src/CodexWatcher/Cli/Command/IssueFanout.hs` no longer imports `CodexWatcher.Core.Ids` when migrated, direct-owner import scans, and a broad remaining-user scan that separates production users from tests, docs, Cabal files, and the public facade module. Successful migration or classification here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
