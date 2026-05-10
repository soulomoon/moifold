### Selected Extraction
- Milestone: Internal Import Migration Readiness
- Milestone id: `milestone-002-internal-import-migration`
- Direction id: `direction-003-appserverclient-import-migration`
- Extracted item id: `round-077-appserverclient-import-migration-readiness`
- Extracted item summary: Migrate the smallest behavior-neutral set of internal `CodexWatcher.AppServerClient` imports to direct `CodexWatcher.Workflow.Agent.Codex.Client` and/or `CodexWatcher.Workflow.Agent.Codex.Transport` imports, with focused validation that app-server protocol parsing, endpoint/session handling, and failure formatting do not drift.
- Roadmap id: `2026-05-10-00-facade-removal-readiness`
- Roadmap revision: `rev-001`
- Roadmap dir: `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`

### Boundaries
- In scope: Internal moifold import migration for `CodexWatcher.AppServerClient` where round-075 replacement mapping and round-076 pure-reexport classification make direct Codex client or transport imports behavior-neutral; focused tests or checks for touched app-server parsing, transport/session, endpoint, and failure-formatting behavior.
- Out of scope: Deprecation pragmas, facade removal, Cabal exposed-module changes, public API decisions, docs or release wording that signals deprecation/removal, runtime compatibility-file changes, event JSON changes, healthcheck or repair behavior changes, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Permission`, `CodexWatcher.Workflow.Types`, and `CodexWatcher.Workflow.Execution`.
- Concurrent batch context: none; active state keeps `max_parallel_rounds` at 1, and this is a single serial extraction within milestone 002.

### Scheduler Fields
```json
{
  "depends_on_round_ids": ["round-075", "round-076"],
  "merge_after_item_ids": [
    "round-075-import-scan-refresh",
    "round-076-behavior-owner-classification"
  ],
  "parallel_group": null,
  "merge_ready": false
}
```

### Rationale
Milestone 001 is complete: round 075 refreshed the current selected-facade scan and replacement mapping, and round 076 classified `CodexWatcher.AppServerClient` as a pure reexport of `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. That satisfies the dependency for milestone 002 and the precondition for direction 003.

Direction 003 is the smallest dependency-ready milestone-002 slice because `CodexWatcher.AppServerClient` is a pure reexport convenience facade with a direct replacement path, while `CodexWatcher.Core.Ids` spans both agent and GitHub identifier owners across many more imports, and `Workflow.EventLog` and `Workflow.Permission` are mixed moifold behavior bridge surfaces that may validly result in holds instead of migration. Selecting this item now advances internal import readiness without approving deprecation, Cabal exposure changes, facade removal, or any runtime compatibility-file cleanup.
