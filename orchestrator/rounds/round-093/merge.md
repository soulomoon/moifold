### Squash Commit
- Title: Add repair-state compatibility fixture
- Summary: This round adds the focused `repair-state.json` compatibility fixture for the completion-without-implementation repair path and extends watcher-core runtime compatibility tests to lock the current repair summary shape. The approved evidence covers exact summary fields, execute-output parity after archive-path normalization, separation from repair-failure `block-state.json`, repair writer ordering, compatibility rewrite separation, and current non-reader/non-healthcheck boundaries without changing production repair, replay, healthcheck, script, schema, migration, deprecation, or removal behavior.

### Merge Readiness
- Base branch freshness: confirmed against configured local base `codex/workflow-facade-extraction`; local base and `HEAD` both resolve to `bb785248e73a7d437db7a11f5f1e8f5a2036d442`, with ahead/behind count `0/0`. `origin` has no `origin/codex/workflow-facade-extraction` tracking ref, so remote freshness is not applicable for this configured base.
- Merge ordering satisfied: yes. `review.md` records `APPROVED`, `review-record.json` records `"decision": "approved"`, state is in `merge` for `round-093`, `merge_ready` is true, `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, `parallel_group` is null, `max_parallel_rounds` is 1, and `last_completed_round` is `round-092`.
- Pending dependencies: none.

### Follow-Up Notes
No merge blockers found for the approved round. This merge prepares only the selected `round-093-repair-state-compatibility-fixtures` slice; it does not approve broader runtime compatibility fixture batches, compatibility-file rename/deletion, schema migration, production repair behavior changes, healthcheck reader changes, deprecation, facade removal, Cabal exposure removal, release approval, or terminal roadmap completion.

The fixture intentionally records the current live repair result as `IssueImplement/Implementing`; the reviewer confirmed that this differs from stale plan example text but matches the current `repairIssueImplementEventLog` and executed `repairInvalidState` output.
