### Squash Commit
- Title: Move WorkflowDocsMigrationSpec to direct agent ids import
- Summary: Round 102 moves the agent-id-only `test/WorkflowDocsMigrationSpec.hs` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`. The approved implementation preserves the existing docs-migration workflow behavior coverage, keeps package descriptors and public facade exposure unchanged, and is verified by the recorded `watcher-core-test`, `cabal build all`, and diff-check gates.

### Merge Readiness
- Base branch freshness: confirmed. `git fetch origin main` completed, `origin/main` is an ancestor of `HEAD`, and `git rev-list --left-right --count origin/main...HEAD` reports `0 236`.
- Merge ordering satisfied: yes. State is serial with `max_parallel_rounds: 1`, active round `round-102`, last completed round `round-101`, and the selection declares no `merge_after_item_ids`.
- Pending dependencies: none. The selection declares no `depends_on_round_ids`, and `review-record.json` records an approved decision for this round.

### Follow-Up Notes
No extra merge blockers are recorded for this round. Keep the squash focused on the single WorkflowDocsMigrationSpec import convergence; do not include unrelated controller-state or roadmap decisions in the merge message.
