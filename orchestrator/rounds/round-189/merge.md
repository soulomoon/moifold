### Squash Commit
- Title: Round 189: Migrate workflow agent spec ID imports
- Summary: Migrates `test/WorkflowAgentSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade and onto the direct agent and GitHub ID owner modules. The approved implementation is import-only and preserves the existing workflow agent, request rendering, turn classifier, fixture, PASS-label, and aggregate wiring behavior.

### Merge Readiness
- Base branch freshness: confirmed against the locally visible `codex/workflow-facade-extraction` head `cc57d8b252f2dcf08a5db7f9122975fbabf98378`; the round branch `orchestrator/round-189-highest-value-cleanup-slice` and its merge-base with the base branch are the same commit.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve `direction-011h-workflow-agent-spec-core-ids-import`; `orchestrator/state.json` marks the active round `merge_ready: true`; `pending_merge_rounds` is empty; and the selected item declares no `merge_after_item_ids` or `parallel_group`.
- Pending dependencies: none. The selected item declares no `depends_on_round_ids`, and the scheduler context is serial with no dependency blockers recorded.

### Follow-Up Notes
The controller can prepare the squash merge with the title above. Remaining `CodexWatcher.Core.Ids` users are intentionally left for later selected rounds, including the other workflow specs, runtime/CLI tests, policy/aggregator surfaces, docs, Cabal exposure, and the public facade module itself.
