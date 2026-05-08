### Squash Commit
- Title: docs(orchestrator): plan issue-planning indexed adoption
- Summary: Adds the artifact-only rev-003 roadmap bundle for `2026-05-07-00-workflow-kernel-indexing`. The revision marks `item-012-indexed-next-domain-plan` done, selects `IssuePlanning` as the next indexed adoption domain, explicitly defers `IssueImplement`, and carries forward verification and retry contracts with issue-planning parity, graph, daemon, retry, compatibility-write, request-id, package-boundary, and fanout surfaces.

### Merge Readiness
- Review approval: confirmed. `orchestrator/rounds/round-012/review.md` records `APPROVED`, and `review-record.json` records decision `approved` for `item-012-indexed-next-domain-plan`.
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`. The round branch HEAD, local base ref, and merge-base all resolve to `d8634ea6e3be486c8138c3789e0a568881a5b2c4`; `origin` does not advertise a `codex/workflow-facade-extraction` branch, so no remote ref was available to compare.
- Merge ordering satisfied: yes. `item-012-indexed-next-domain-plan` declares `Merge after: item-011-indexed-pr-review-daemon-path`; `rev-002/roadmap.md` marks item 011 done, and `orchestrator/state.json` records `last_completed_round` as `round-011`.
- Pending dependencies: none. The active round has no `depends_on_round_ids`, no `pending_merge_rounds`, and `merge_ready` is `true`.

### Follow-Up Notes
This round is ready for a squash merge as an artifact-only roadmap update. Keep the merge focused on the rev-003 roadmap bundle plus round-012 control artifacts; do not include production source, tests, golden fixtures, rev-002 files, or controller-owned `orchestrator/state.json` changes unless the controller explicitly owns that state transition.
