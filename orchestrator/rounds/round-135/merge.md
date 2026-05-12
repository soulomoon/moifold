### Squash Commit
- Title: Remove WorkflowEventLogSpec facade import
- Summary: Remove the remaining `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` facade import from `test/WorkflowEventLogSpec.hs` by keeping the behavior spec on direct `WorkflowEventLogCore` owner calls, while leaving the explicit facade parity coverage in untouched `test/FacadeImportPolicySpec.hs`.

### Merge Readiness
- Base branch freshness: confirmed; `orchestrator/round-135-highest-value-cleanup-slice` and `codex/workflow-facade-extraction` resolve to the same base commit before the round diff.
- Merge ordering satisfied: yes; round-135 is a serial round with `max_parallel_rounds: 1`, no `merge_after_item_ids`, no pending merge queue entry, and no concurrent batch context.
- Pending dependencies: none; `depends_on_round_ids` is empty and review approved the round.

### Follow-Up Notes
Round-135 is ready for squash merge into `codex/workflow-facade-extraction`. The remaining exact EventLog facade import is intentionally isolated to `test/FacadeImportPolicySpec.hs` for facade parity coverage; public facade removal, Cabal exposure cleanup, milestone completion, release approval, and terminal completion remain out of scope for this merge.
