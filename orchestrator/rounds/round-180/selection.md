### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011f-core-ids-cli-production-imports`
- Extracted item id: `round-180-cli-types-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Cli/Types.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct agent and GitHub id owner imports, preserving CLI command/type definitions and derived behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Cli/Types.hs` imports for agent-owned ids (`ThreadId`, `TurnId`) and GitHub-owned ids (`BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`) so the module no longer imports `CodexWatcher.Core.Ids`.
- Out of scope: CLI constructors, record fields, derived instances, `CliDomain` behavior, parser/rendering behavior, option names, parser errors, dry-run text, fanout manifest behavior, child args, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Core/Ids.hs`, test/fixture imports, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility files, and milestone completion.
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
`rev-002` keeps `milestone-003-core-ids-production-import-burndown` in progress and sequences production `Core.Ids` imports before test/fixture imports. The current production scan still reports `src/CodexWatcher/Cli/Types.hs` and `src/CodexWatcher/Cli/Command/IssueFanout.hs` as the remaining CLI users after round 179 completed `src/CodexWatcher/Cli/Parser/Common.hs`.

`Cli/Types.hs` is the smaller next `direction-011f` extraction: it is a pure CLI type surface whose `Core.Ids` use can be split to direct owner imports without changing parser code, fanout execution, runtime command rendering, or compatibility files. Selecting it now continues concrete migration progress inside milestone 003 while preserving the public `CodexWatcher.Core.Ids` facade and leaving `Cli/Command/IssueFanout.hs` as a later one-file CLI production slice.

The planner and reviewer should require the baseline checks, a selected-file scan proving `src/CodexWatcher/Cli/Types.hs` no longer imports `CodexWatcher.Core.Ids`, direct-owner import scans, and a broad remaining-user scan that separates production users from tests, docs, Cabal files, and the public facade module. Successful migration here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
