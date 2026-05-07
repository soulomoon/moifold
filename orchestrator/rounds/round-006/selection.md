### Selected Item
- Roadmap item: Port one PR-review transition slice to the indexed API
- Item id / roadmap_item_id: item-006-indexed-pr-review-slice
- Roadmap id / roadmap_id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision / roadmap_revision: rev-001
- Roadmap dir / roadmap_dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
`item-006-indexed-pr-review-slice` is dependency-ready now because the active roadmap records `item-005-indexed-docs-migration` as `[done]` with completion in round-005. The selected item has both `Depends on:` and `Merge after:` set to `item-005-indexed-docs-migration`, so its ordering gate is satisfied by the current roadmap state and `orchestrator/state.json` recording `last_completed_round` as `round-005`.

This is the smallest next valuable pending item in the active roadmap. Items 001 through 005 are already done, item 006 is the first pending item, and it is not marked parallel-safe, so it should be selected alone for round-006.
