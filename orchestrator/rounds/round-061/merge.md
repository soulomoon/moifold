### Squash Commit
- Title: Record AppServerClient migration readiness
- Summary: Record the approved evidence-only `CodexWatcher.AppServerClient` migration-readiness round. The round refreshes the selected-facade import inventory, groups current callers by replacement ownership, confirms replacement module exposure and current app-server behavior coverage, and preserves the documented blockers for any later import migration, facade narrowing, deprecation, Cabal exposure change, or removal.

### Merge Readiness
- Base branch freshness: confirmed against local base `codex/workflow-facade-extraction`; the round branch and local base both resolve to `b3ca366f6b9b48f5fb71887b37a1d4838db0c02b`. No remote `origin/codex/workflow-facade-extraction` ref is published for an additional remote freshness comparison.
- Merge ordering satisfied: yes. Serial mode has no concurrent batch, `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and round state records `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `orchestrator/rounds/round-061/review.md` and `orchestrator/rounds/round-061/review-record.json`. Visible changes are limited to round-local artifacts under `orchestrator/rounds/round-061/`; no source, tests, package metadata, roadmap files, or `orchestrator/state.json` are part of this round diff. Squash merge is ready for the approved evidence-only round, subject to the controller performing the actual merge step.
