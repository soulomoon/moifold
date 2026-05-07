### Selected Item
- Roadmap item: Port DocsMigration as the first indexed workflow proof
- Item id: item-005-indexed-docs-migration
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-001
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-001

### Rationale
`item-005-indexed-docs-migration` is dependency-ready now because the active
roadmap records its only dependency, `item-004-indexed-spec-api`, as `[done]`
with completion notes showing it was completed in round-004. The current
`orchestrator/state.json` also records `last_completed_round` as `round-004`
and the active round as `round-005` for this item.

The selected item's `Depends on:` and `Merge after:` entries both point to
`item-004-indexed-spec-api`, so the serial ordering constraint is satisfied.
It is the next smallest pending roadmap item, and the following item,
`item-006-indexed-pr-review-slice`, depends on this DocsMigration proof.
