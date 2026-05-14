### Squash Commit
- Title: Round 193: Migrate RuntimeSpec ID imports
- Summary: Migrate `test/RuntimeSpec.hs` from the `CodexWatcher.Core.Ids` compatibility facade to direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only for the selected runtime spec, preserving runtime command rendering, default-option, process, GitHub/Git command assertions, PASS labels, and aggregate wiring.

### Merge Readiness
- Base branch freshness: confirmed; `orchestrator/round-193-highest-value-cleanup-slice` is based on local `codex/workflow-facade-extraction` at `45e87a91d4b5fe02f348edd9a77db85c9fde6b8c`.
- Merge ordering satisfied: yes; the selected item declares no `depends_on_round_ids`, no `merge_after_item_ids`, no `parallel_group`, and state records serial execution for `round-193`.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `orchestrator/rounds/round-193/review.md` and `orchestrator/rounds/round-193/review-record.json`. Remaining `CodexWatcher.Core.Ids` users in runtime compatibility fixtures, facade policy tests, `test/Main.hs`, docs, Cabal exposure, and the public facade module are out of scope for this round and remain for later roadmap items.
