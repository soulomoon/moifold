### Squash Commit
- Title: Round 187: Migrate workflow test-support ID imports
- Summary: This round migrates `test/TestSupport/Workflow.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` owner imports. The approved diff is import-only for the workflow test-support helper and preserves helper exports, fixtures, assertions, PASS labels, fake executor behavior, aggregate wiring, and downstream workflow-test behavior.

### Merge Readiness
- Base branch freshness: confirmed. The local base branch `codex/workflow-facade-extraction` resolves to `8976440f0b98191af83b4c983584d4f345d7b756`, the same commit as this round branch `HEAD`, and is an ancestor of the round branch.
- Merge ordering satisfied: yes. Selection declares no `depends_on_round_ids` and no `merge_after_item_ids`; `max_parallel_rounds` is serial at `1`; `pending_merge_rounds` is empty; review is approved.
- Pending dependencies: none.

### Follow-Up Notes
Round 187 is ready for squash merge with the title above.

Remaining `CodexWatcher.Core.Ids` users are intentionally left for later workflow-test, runtime/CLI, policy/aggregator, public facade, Cabal, and docs slices. This merge readiness confirmation does not approve milestone 004 completion, public facade deprecation or removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, terminal completion, or public compatibility removal.
