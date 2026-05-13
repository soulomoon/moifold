### Selected Extraction
- Milestone: Core.Ids Production Import Burndown
- Milestone id: `milestone-003-core-ids-production-import-burndown`
- Direction id: `direction-011f-core-ids-cli-production-imports`
- Extracted item id: `round-179-cli-parser-common-core-ids-split-import-migration`
- Extracted item summary: Migrate only `src/CodexWatcher/Cli/Parser/Common.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct agent and GitHub id owner imports, preserving CLI parser behavior.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `src/CodexWatcher/Cli/Parser/Common.hs` imports for `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `IssueNumber`, `RepoName`, and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`; keep constructors, field accessors, exported parser helpers, and parse results available exactly as before.
- Out of scope: option names, parser error text, metavar/help text, default values, command rendering, dry-run text, child args, fanout manifest behavior, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, test/fixture `Core.Ids` imports, `src/CodexWatcher/Core/Ids.hs`, public facade exposure, Cabal exposure cleanup, docs cleanup, runtime compatibility files, and milestone completion.
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
`rev-002` splits the old overloaded import/removal gate into finite queues, and `milestone-003-core-ids-production-import-burndown` is still in progress with `src/CodexWatcher/Cli/Parser/Common.hs` listed as a remaining production `CodexWatcher.Core.Ids` user. This slice keeps making concrete migration progress inside the production Core.Ids lane without treating import convergence as public facade removal or runtime compatibility cleanup.

`Cli/Parser/Common.hs` is the smallest high-value CLI production slice under `direction-011f`: it owns shared parsers for repo, issue, review-thread, thread, and turn ids, while the roadmap explicitly keeps CLI parser/types/fanout work separate and defaults to one CLI file per round. The planner and reviewer should require focused CLI parser evidence for the touched ids, a selected-file scan proving `src/CodexWatcher/Cli/Parser/Common.hs` no longer imports `CodexWatcher.Core.Ids`, and the broad remaining-user scan that separates production users from tests, docs, Cabal, and the public facade module. Successful migration here must not be treated as public facade deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
