### Squash Commit
- Title: Move WorkflowExecution audit tests off EventLog facade
- Summary: `test/WorkflowExecutionSpec.hs` moved audit accessor and daemon recommendation references from the exact `CodexWatcher.Workflow.EventLog` facade import to `CodexWatcher.Workflow.Audit`. The existing direct owner imports for `EventLog.Commit.Core` and `EventLog.File.Core` are preserved; public facades, Cabal files, docs, runtime files, production code, and other tests are unchanged.

### Merge Readiness
- Base branch freshness: confirmed. The configured base branch `codex/workflow-facade-extraction` is the current local base for `orchestrator/round-132-highest-value-cleanup-slice` at `a20e85a`; no remote ref for that base branch is advertised by `origin`.
- Merge ordering satisfied: yes. The controller is serial with `max_parallel_rounds: 1`; active round `round-132` is at merge stage with `merge_ready: true`, and `pending_merge_rounds` is empty.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are both empty.
- Review approval: confirmed. `orchestrator/rounds/round-132/review.md` records `APPROVED`, and `review-record.json` records `"decision": "approved"`.

### Follow-Up Notes
Remaining exact EventLog facade imports are out-of-scope tests: `test/FacadeImportPolicySpec.hs`, `test/WorkflowEventLogSpec.hs`, and `test/WorkflowIndexedSpec.hs`.
