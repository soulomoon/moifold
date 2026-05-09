### Squash Commit
- Title: Record daemon-state compatibility evidence
- Summary: This round records artifact-only evidence for `direction-016-daemon-state-active-stopped-fixtures`: current `daemon-state.json` active, stopped, and idle projection readback; tolerated old-shape fixture behavior; snapshot and golden replay readback; healthcheck, repair, and restart cleanup behavior; current `keep` classification; and conservative blockers before any future compatibility cleanup decision.

### Merge Readiness
- Base branch freshness: confirmed. Local `HEAD`, the merge base with `codex/workflow-facade-extraction`, and the local base branch all resolve to `df4ba25b8272e362526f7d584a0f0718e68098a8`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0 0`.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve the artifact-only evidence round, `orchestrator/state.json` marks round-067 `merge_ready: true`, `pending_merge_rounds` is empty, and the selected scheduler fields declare no `merge_after_item_ids`.
- Pending dependencies: none. The selected scheduler fields declare no `depends_on_round_ids`, and the active state has no resume or retry blocker.

### Follow-Up Notes
This merge note does not approve behavior changes, cleanup, migration, deprecation, removal, publication, upload, or release. Later rounds should keep the documented blockers conservative until active/stopped fixture coverage, round-trip fixture coverage, and external operator or downstream inventory gaps are resolved.
