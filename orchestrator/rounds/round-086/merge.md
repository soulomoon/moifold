### Squash Commit
- Title: Extract workflow behavior tests from Main
- Summary: Splits the workflow behavior coverage out of `test/Main.hs` into focused watcher-core test modules for event-log behavior, agent/facade behavior, indexed workflow behavior, DocsMigration behavior, and execution behavior, with shared test-only support and `watcher-core-test` aggregation preserved. The round keeps behavior coverage reachable through `workflowFacadeExtractionTests`, limits Cabal changes to watcher-core test metadata, and leaves production code, docs, fixtures, runtime compatibility files, exposed modules, facade availability, and behavior semantics unchanged.

### Merge Readiness
- Base branch freshness: confirmed. Local base `codex/workflow-facade-extraction`, round branch `orchestrator/round-086-highest-value-cleanup-slice`, and their merge-base all point at `b128deb2c2e10fb430b0788082e89b6ab238f213`.
- Merge ordering satisfied: yes. `review.md` approves the round, `review-record.json` records `decision: approved`, state has `merge_ready: true`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, and `merge_after_item_ids: []`.
- Pending dependencies: none.

### Follow-Up Notes
Ready for squash merge into local base `codex/workflow-facade-extraction` with no merge-after items, dependency blockers, or pending merge rounds. Verification recorded by review passed `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, status review, Cabal scope inspection, runner reachability inspection, and label-preservation comparison.
