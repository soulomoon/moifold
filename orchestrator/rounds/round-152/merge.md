### Squash Commit
- Title: Round 152: Migrate AppServerProbeSpec ThreadId import
- Summary: This round migrates `test/AppServerProbeSpec.hs` away from the `CodexWatcher.Core.Ids` compatibility facade for `ThreadId` and `unThreadId`, using the direct owner import from `CodexWatcher.Workflow.Agent.Ids` while preserving the existing app-server probe command coverage and leaving public compatibility surfaces available.

### Merge Readiness
- Base branch freshness: confirmed locally; `codex/workflow-facade-extraction` and `orchestrator/round-152-highest-value-cleanup-slice` both resolve to `55d87e75b3f7855dc87090bc230b80c5106f79d2`, and the base branch is an ancestor of `HEAD`.
- Merge ordering satisfied: yes; `merge_ready` is true, `pending_merge_rounds` is empty, `merge_after_item_ids` is empty, and the reviewer approved the round.
- Pending dependencies: none; `depends_on_round_ids` is empty.

### Follow-Up Notes
`origin` did not advertise a `codex/workflow-facade-extraction` ref when refreshed, so freshness is confirmed against the local base branch named by `orchestrator/state.json`. No implementation code, staging, commit, or merge was performed by the merger.
