### Squash Commit
- Title: Port issue-planning policy to the indexed workflow API
- Summary: Adds a moifold-owned indexed issue-planning adapter for the existing compatibility policy surface, exposing typed indexed wrappers and conversion helpers while delegating behavior through `MoifoldSpec`. The round also exposes the adapter from `moifold.cabal` and adds focused parity coverage for issue-planning transitions, blocked and graph-validation paths, invalid observations, replay/effect/permission checks, dry-run/action ordering, request-id progression, and compatibility writes without changing live daemon routing.

### Merge Readiness
- Review approval: confirmed. `review.md` records `APPROVED`, and `review-record.json` records decision `approved` for `item-013-indexed-issue-planning-policy`.
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of `HEAD`, and `git rev-list --left-right --count HEAD...codex/workflow-facade-extraction` reports `0 0`.
- Merge ordering satisfied: yes. The active item declares `Merge after: item-012-indexed-next-domain-plan`; the roadmap marks item 012 done, and `state.json` records `last_completed_round` as `round-012`.
- Pending dependencies: none. The active round has no `depends_on_round_ids`; the roadmap dependency on `item-012-indexed-next-domain-plan` is already satisfied.

### Follow-Up Notes
Do not route live issue-planning daemon observations through this merge. The next roadmap item, `item-014-indexed-issue-planning-daemon-start`, owns routing `PlanningReady` plus `ObservedPlanningTurnStarted` through the indexed adapter after this round is squash-merged and the controller records item 013 as complete.
