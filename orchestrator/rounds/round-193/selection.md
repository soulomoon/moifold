### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011i-core-ids-runtime-cli-test-imports`
- Extracted item id: `direction-011i-runtime-spec-core-ids-import`
- Extracted item summary: Migrate `test/RuntimeSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing runtime command rendering, default-option, process, and GitHub/Git command assertions.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/RuntimeSpec.hs`; use direct owners for the runtime command ids already exported by `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; keep all runtime command rendering, default app-server options, process execution expectations, PASS labels, and aggregate wiring unchanged.
- Out of scope: migrate `test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, fixture data changes, milestone completion, terminal closeout, and policy/aggregator classification.
- Concurrent batch context: none. The active state is serial (`max_parallel_rounds = 1`), and direction 011i calls for one behavior area per round.

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
Milestone 004 is dependency-ready because milestone 003 is completed and the active roadmap records that no production `CodexWatcher.Core.Ids` users remain under `src/` beyond the public compatibility facade. Rounds 187 through 191 completed direction 011h workflow test imports, and round 192 completed the CLI slice of direction 011i, so the next roadmap-ordered work is the remaining direction 011i runtime test import burndown before any direction 011j policy or aggregator classification.

The current scan still finds `CodexWatcher.Core.Ids` in `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`, and `test/Main.hs`, plus docs, Cabal exposure, and the public facade module. `test/RuntimeSpec.hs` is the smallest next safe migration in direction 011i: its facade import is limited to `ThreadId` from `CodexWatcher.Workflow.Agent.Ids` and `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`. Selecting it keeps runtime compatibility fixture JSON and policy/aggregator facade evidence for later finite rounds.
