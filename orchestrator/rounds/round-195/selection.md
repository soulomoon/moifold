### Selected Extraction
- Milestone: Core.Ids Test And Fixture Import Burndown
- Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
- Direction id: `direction-011j-core-ids-policy-and-aggregator-classification`
- Extracted item id: `direction-011j-core-ids-policy-aggregator-classification`
- Extracted item summary: Artifact-only classification of the remaining test `CodexWatcher.Core.Ids` imports in `test/FacadeImportPolicySpec.hs` and `test/Main.hs` as intentional policy and aggregate evidence surfaces.
- Roadmap id: `2026-05-11-00-highest-value-cleanup`
- Roadmap revision: `rev-002`
- Roadmap dir: `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002`

### Boundaries
- In scope: record the exact remaining test imports in `test/FacadeImportPolicySpec.hs` and `test/Main.hs`; classify `test/FacadeImportPolicySpec.hs` as facade-policy evidence that intentionally exercises the combined `CodexWatcher.Core.Ids` compatibility facade; classify `test/Main.hs` as watcher-core-test aggregate wiring and broad property-test support that still centralizes shared id generators and constructors; run scans sufficient to prove no other safe test/fixture `Core.Ids` imports remain.
- Out of scope: migrate either selected file to direct owner imports in this round; edit production modules, test code, fixtures, docs, Cabal exposure, public facade exports, compatibility facade availability, runtime compatibility files, event schemas, policy assertions, aggregate wiring, milestone status, roadmap files, or `orchestrator/state.json`.
- Concurrent batch context: none. The active state is serial (`max_parallel_rounds = 1`), and direction 011j allows an artifact-only or narrow test-only classification round for the naturally coupled policy and aggregate surfaces.

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
Milestone 004 is dependency-ready because milestone 003 is completed and rounds 187 through 194 have already migrated the safe workflow, CLI, runtime, and runtime-compatibility fixture test imports away from `CodexWatcher.Core.Ids`. The active roadmap records direction 011h and direction 011i as complete, and names the remaining `Core.Ids` test users as `test/FacadeImportPolicySpec.hs` and `test/Main.hs` policy/aggregator candidates for direction 011j.

The current scan confirms the same remaining live code/package users: `test/FacadeImportPolicySpec.hs`, `test/Main.hs`, `src/CodexWatcher/Core/Ids.hs`, and `moifold.cabal`, with docs and prior round artifacts also mentioning the facade. `test/FacadeImportPolicySpec.hs` is a policy surface for facade and package-boundary assertions, while `test/Main.hs` is the watcher-core-test aggregate entrypoint containing shared `Arbitrary` instances and broad behavior properties that still consume the combined id facade. Classifying both together is the smallest finite extraction that can close the remaining direction 011j question without weakening tests or implying public facade deprecation, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, release approval, or terminal roadmap completion.
