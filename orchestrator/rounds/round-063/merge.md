### Squash Commit
- Title: Record Workflow.Permission public API evidence
- Summary: This evidence-only round records the current public `CodexWatcher.Workflow.Permission` API surface, its Cabal exposure, repo-local import/reference inventory, behavior parity evidence, replacement guidance through `CodexWatcher.Workflow.Permission.Core`, and blockers before any later deprecation, facade narrowing, import migration, exposure change, or removal decision. The approved diff remains limited to round-local orchestrator artifacts.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-063-workflow-permission-public-api-review` is at `befb6d07255d81f5e3fd4f36c570aad45e084b5d`, matching the local base `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. The round is serial (`max_parallel_rounds` is 1), selected after rounds 060 through 062 completed the prior import-facade evidence directions, and has no merge-after items.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are empty, and `review.md` / `review-record.json` mark the round approved.

### Follow-Up Notes
No merge blocker for this approved evidence-only round. The recorded downstream/operator evidence gap remains a blocker only for later cleanup, deprecation, migration, exposure, publication, or removal work.
