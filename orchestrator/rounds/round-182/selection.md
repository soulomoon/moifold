### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011a-core-ids-eventlog-types-production-import`
- Extracted item id: `round-182-eventlog-types-core-ids-split-import-migration`
- Extracted item summary: Migrate or classify only `src/CodexWatcher/EventLog/Types.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct agent and GitHub id owner imports, preserving watcher event constructors, codecs, metadata labels, schema version, golden replay, and old-log parsing behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/EventLog/Types.hs` imports for agent-owned ids (`ThreadId`, `TurnId`) and GitHub-owned ids (`BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`) so the module no longer imports `CodexWatcher.Core.Ids`; if focused event-log evidence shows the split is not safe, record the exact blocker/classification for this file.
- Out of scope: event constructor changes, JSON `type` labels, schema-version changes, metadata-label changes, codec field names, old fixture edits, golden replay behavior changes, runtime compatibility files, healthcheck behavior, domain-loop imports, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, and terminal completion.
- Concurrent batch context: none; default serial execution with `max_parallel_rounds: 1`, and `direction-011a` is serial with golden replay and runtime compatibility work.

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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences production `Core.Ids` imports before test/fixture imports. Round 181 completed `direction-011f` CLI production imports, and the reviewed round-181 roadmap update leaves five production users: `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, and `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.

Selecting `EventLog.Types.hs` now follows the first remaining active candidate direction and burns down a central compatibility surface as a single-file slice. Its current `Core.Ids` use maps to direct owner modules already exposed through the facade: `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`.

The planner and reviewer should require the baseline checks, focused event-log coverage for golden replay, old-log parsing, event JSON `type` stability, schema compatibility, and selected-file direct-owner imports. They should also require a selected-file scan proving `src/CodexWatcher/EventLog/Types.hs` no longer imports `CodexWatcher.Core.Ids` when migrated, plus a broad remaining-user scan that separates production users from tests, docs, Cabal files, and the public facade module. Successful migration or classification here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
