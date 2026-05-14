### Squash Commit
- Title: Round 192: Migrate CLI spec ID imports
- Summary: This round migrates `test/CliSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade and onto direct id-owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for the selected CLI parser spec and preserves CLI parse expectations, defaults, option names, parser rejection behavior, guard-domain assertions, and `test/Main.hs` aggregate wiring.

### Merge Readiness
- Base branch freshness: confirmed against the observable local base. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `62a472850e752ddfd92e737ddab5eabc40575c03`.
- Merge ordering satisfied: yes. The live active-round state has `merge_ready: true`, `pending_merge_rounds: []`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`; selection also records no concurrent batch context.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is explicit in `review.md` and `review-record.json`. Remaining `CodexWatcher.Core.Ids` users are out of scope for this round: runtime tests, runtime compatibility fixture tests, facade import policy coverage, test aggregator wiring, docs/Cabal public facade references, and the facade module itself.
