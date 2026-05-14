### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011i-core-ids-runtime-cli-test-imports`
- Extracted item id: `direction-011i-runtime-compatibility-fixture-core-ids-import`
- Extracted item summary: Migrate `test/RuntimeCompatibilityFixtureSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing runtime compatibility fixture JSON, repair, healthcheck, daemon, and projection assertions.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/RuntimeCompatibilityFixtureSpec.hs`; use direct owners for the fixture ids already exported by `CodexWatcher.Workflow.Agent.Ids` (`ThreadId`, `TurnId`) and `CodexWatcher.Workflow.GitHub.Ids` (`BranchName`, `IssueNumber`, `PrNumber`, `RepoName`); keep fixture data, runtime compatibility writes, repair behavior, healthcheck reader boundaries, daemon-state assertions, planning graph assertions, PASS labels, and aggregate wiring unchanged.
- Out of scope: migrate or classify `test/FacadeImportPolicySpec.hs` or `test/Main.hs`; edit production modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, compatibility file names, fixture JSON, healthcheck behavior, repair behavior, milestone completion, terminal closeout, or policy/aggregator classification.
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
Milestone 004 is dependency-ready because milestone 003 is completed and the active roadmap records that no production `CodexWatcher.Core.Ids` users remain under `src/` beyond the public compatibility facade. Rounds 187 through 191 completed direction 011h workflow test imports, round 192 completed the CLI slice of direction 011i, and round 193 completed the `RuntimeSpec` slice of direction 011i. The roadmap says to continue direction 011i with `test/RuntimeCompatibilityFixtureSpec.hs` if it still imports `CodexWatcher.Core.Ids`.

The current scan still finds `CodexWatcher.Core.Ids` in `test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`, and `test/Main.hs`, plus docs, Cabal exposure, and the public facade module. `test/RuntimeCompatibilityFixtureSpec.hs` is the remaining safe runtime/CLI test migration before direction 011j policy/aggregator classification: its facade import is limited to `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, plus `BranchName`, `IssueNumber`, `PrNumber`, and `RepoName` from `CodexWatcher.Workflow.GitHub.Ids`. Selecting it continues import convergence without approving fixture JSON changes, runtime compatibility cleanup, public facade cleanup, policy weakening, milestone completion, or terminal roadmap completion.
