### Squash Commit
- Title: Record block-state repair evidence
- Summary: This evidence-only round records the current repair-failure `block-state.json` writer shape, normal blocked writes, compatibility projection, healthcheck/snapshot/golden readback, stale-block cleanup, restart cleanup, fixture inventory, existing assertions, current keep classification, and conservative blockers for `direction-018-block-state-repair-failure-fixture`.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`, merge-base with `codex/workflow-facade-extraction`, and local base branch all resolve to `de6462a3efb08c44fa370bb25b88bb49ce168740`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0 0`.
- Merge ordering satisfied: yes. The active round is serial (`max_parallel_rounds = 1`), `depends_on_round_ids` and `merge_after_item_ids` are empty, and `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
This round does not approve filename, schema, event type, write-timing, healthcheck, repair, projection, stale-cleanup behavior changes, cleanup, deprecation, removal, publication, upload, or release. Later rounds should keep the missing repair-failure fixture/runner round-trip coverage and external operator/downstream inventory as explicit blockers until separately resolved.
