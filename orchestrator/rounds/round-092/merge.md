### Squash Commit
- Title: Add repair-failure block-state compatibility fixture
- Summary: This round adds the focused repair-failure `block-state.json` compatibility fixture and watcher-core assertions for the current repair-failure shape. The approved evidence locks exact parity with `repairFailureBlockStateJson`, snapshot reader tolerance, repair-failure-specific fields, non-interchangeability with normal blocked writes, and the current block-state source-boundary interactions without production behavior changes.

### Merge Readiness
- Base branch freshness: confirmed against `codex/workflow-facade-extraction`; local base and `HEAD` both resolve to `e24a4b0844fe94fc4fba99085362aabdb8dc689a`, with ahead/behind count `0/0`.
- Merge ordering satisfied: yes. `review.md` records `APPROVED`, `review-record.json` records `"decision": "approved"`, state is in `merge` for `round-092`, `merge_ready` is true, `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
No merge blockers found for the approved round. This merge prepares only the selected `round-092-repair-failure-block-state-compatibility-fixtures` slice; it does not approve broader fixture batches, compatibility-file rename/deletion, schema migration, deprecation, facade removal, Cabal exposure removal, release approval, or terminal roadmap completion.
