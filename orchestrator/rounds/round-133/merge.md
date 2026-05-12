### Squash Commit
- Title: Move WorkflowIndexed audit tests off EventLog facade
- Summary: `test/WorkflowIndexedSpec.hs` audit accessor and recommendation references now use `CodexWatcher.Workflow.Audit`; the existing direct owner imports for `EventLog.Commit.Core` and `EventLog.File.Core` are preserved. Public facades, Cabal metadata, docs, runtime compatibility files, event schemas, and production code are unchanged.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; the round branch, base branch, and merge-base all resolve to `39ddbdc`.
- Merge ordering satisfied: yes. State is serial with `max_parallel_rounds: 1`; active round `round-133` is at merge stage with `merge_ready: true`; `pending_merge_rounds` is empty.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are both empty.
- Review approval: confirmed. `review.md` decision is `APPROVED`, and `review-record.json` records `"decision": "approved"`.

### Follow-Up Notes
Remaining exact `EventLog` facade imports are out-of-scope tests: `test/FacadeImportPolicySpec.hs` and `test/WorkflowEventLogSpec.hs`.
