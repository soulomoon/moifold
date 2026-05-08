### Selected Item
- Roadmap item: Port IssueImplement policy transitions to the indexed API
- Item id: item-018-indexed-issue-implementation-policy
- Roadmap id: 2026-05-07-00-workflow-kernel-indexing
- Roadmap revision: rev-004
- Roadmap dir: orchestrator/roadmaps/2026-05-07-00-workflow-kernel-indexing/rev-004

### Rationale
`item-018-indexed-issue-implementation-policy` is the next legal roadmap item for round 018. The active controller state already records this item for `round-018`, and the active `rev-004` roadmap shows its only dependency, `item-017-indexed-issue-implementation-next-domain-plan`, is done. It is also the first pending IssueImplement item; every later IssueImplement daemon-routing and lifecycle-hardening item depends on this policy adapter, either directly or through the ordered chain. The item is not parallel-safe and has `Merge after: item-017-indexed-issue-implementation-next-domain-plan`, which is already satisfied by the completed round 017, so selecting this single item preserves roadmap ordering and keeps live daemon routing deferred as required.
