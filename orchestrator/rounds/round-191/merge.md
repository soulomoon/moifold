### Squash Commit
- Title: Round 191: Migrate workflow indexed spec ID imports
- Summary: This round migrates `test/WorkflowIndexedSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto the direct Agent and GitHub id-owner imports. The approved diff is import-only for the selected workflow indexed spec, preserving the existing indexed workflow assertions, fixtures, PASS labels, event/replay expectations, runtime command expectations, and suite wiring.

### Merge Readiness
- Base branch freshness: confirmed against the observable local base. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `b40296b060e81a746aaf8fd6e05d54cbf97ffc15` (`Clear roadmap update after round 190`). No `origin/codex/workflow-facade-extraction` tracking ref was present in this worktree, so remote freshness was not asserted.
- Merge ordering satisfied: yes. The live active-round state has `merge_ready: true`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`; selection also records no concurrent batch context.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is explicit in `review.md` and `review-record.json`. Remaining `CodexWatcher.Core.Ids` users are out of scope for this round: runtime/CLI tests, policy and aggregator coverage, runtime compatibility fixture coverage, public facade/Cabal exposure, docs/public compatibility policy, and the facade module itself.
