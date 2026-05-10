### Selected Extraction
- Milestone: Internal Import Migration Readiness
- Milestone id: `milestone-002-internal-import-migration`
- Direction id: `direction-004-core-ids-split-import-migration`
- Extracted item id: `round-078-core-ids-split-import-migration`
- Extracted item summary: Split a focused, behavior-neutral set of internal `CodexWatcher.Core.Ids` imports to direct `CodexWatcher.Workflow.Agent.Ids` or `CodexWatcher.Workflow.GitHub.Ids` imports where each caller only needs one identifier owner, while recording any callers that still legitimately need the combined facade.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Internal moifold import migration for `CodexWatcher.Core.Ids` at caller sites whose imports can be split cleanly between agent ids (`RequestId`, `ThreadId`, `TurnId`, `nextRequestId`) and GitHub ids (`RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `ReviewThreadId`, `CommitSha`); focused identifier parser/rendering or command-output checks for touched code.
- Out of scope: Newtype constructor, parser, renderer, command-output, event-schema, healthcheck, repair, runtime compatibility-file, package descriptor, README/docs, deprecation, Cabal exposure, public API, facade removal, `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Permission`, `CodexWatcher.Workflow.Types`, and `CodexWatcher.Workflow.Execution` changes.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and this is the next serial milestone-002 extraction after the completed AppServerClient migration slice.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076", "round-077"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification",
    "round-077-appserverclient-import-migration-readiness"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete: round 075 refreshed the selected-facade inventory and replacement mapping, and round 076 classified `CodexWatcher.Core.Ids` as a pure reexport convenience facade over `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. Round 077 completed direction 003 for `CodexWatcher.AppServerClient`, leaving directions 004 and 005 pending under milestone 002.

Direction 004 is the next smallest dependency-ready extraction because `Core.Ids` has a direct owner split and current local evidence shows remaining imports across `src`, `app`, and `test`, while direction 005 covers mixed `Workflow.EventLog` and `Workflow.Permission` surfaces with concrete moifold behavior bridges that may require hold decisions instead of migration. Selecting this item now advances internal import readiness without approving deprecation, Cabal exposure changes, facade removal, public API changes, or runtime compatibility-file cleanup.
