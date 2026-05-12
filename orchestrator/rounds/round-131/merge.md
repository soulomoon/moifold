### Squash Commit
- Title: Move Main audit tests off EventLog facade
- Summary: `test/Main.hs` daemon audit assertions now use `Workflow.Audit` for the existing audit accessors and daemon recommendation. Public facades, Cabal files, docs, and runtime files remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; round branch `orchestrator/round-131-highest-value-cleanup-slice` is based on current local `codex/workflow-facade-extraction` at `a80c411`.
- Merge ordering satisfied: yes; serial controller state has `max_parallel_rounds: 1`, the active round is `round-131`, `merge_ready` is `true`, and `pending_merge_rounds` is empty.
- Pending dependencies: none; `depends_on_round_ids` and `merge_after_item_ids` are empty for the active round.
- Review status: explicitly approved in `orchestrator/rounds/round-131/review.md` and recorded as approved in `orchestrator/rounds/round-131/review-record.json`.

### Follow-Up Notes
Remaining exact EventLog facade imports are out-of-scope tests: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs`.
