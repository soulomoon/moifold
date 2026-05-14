### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011i-core-ids-runtime-cli-test-imports`
- Extracted item id: `direction-011i-cli-spec-core-ids-import`
- Extracted item summary: Migrate `test/CliSpec.hs` from the `CodexWatcher.Core.Ids` facade import to direct id-owner imports while preserving existing CLI parsing expectations, option names, parser errors, and test-suite wiring.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: update only `CodexWatcher.Core.Ids` import ownership in `test/CliSpec.hs`; use direct owners for the CLI parser ids already exported by `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; keep CLI parse results, defaults, option names, parser error behavior, and aggregate wiring unchanged.
- Out of scope: migrate `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, source modules, docs, Cabal exposure, public facade deprecation/removal, runtime compatibility cleanup, fixture data changes, milestone completion, terminal closeout, and policy/aggregator classification.
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
Milestone 004 is dependency-ready because milestone 003 is completed and the active roadmap records that no production `CodexWatcher.Core.Ids` users remain under `src/` beyond the public compatibility facade. Rounds 187 through 191 completed direction 011h workflow test imports, so the next roadmap-ordered work is direction 011i runtime/CLI test import burndown before any direction 011j policy or aggregator classification.

`test/CliSpec.hs` is the smallest remaining direction-011i behavior area: it imports only `IssueNumber`, `RepoName`, and `ThreadId` from the facade, and the direct owner modules already expose those ids. Selecting this narrow CLI parser slice mirrors the completed production CLI ownership split while keeping runtime fixture JSON, runtime command behavior tests, public facade/Cabal/docs decisions, and runtime compatibility cleanup out of scope.
