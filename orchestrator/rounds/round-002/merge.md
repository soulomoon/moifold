### Squash Commit
- Title: Add workflow facade law parity coverage
- Summary: Adds DocsMigration and PR-review mergeability workflow facade law coverage for observe/plan agreement, apply and replay parity, effect-history stability, permission behavior, and dry-run/action ordering. The round also preserves the existing event-codec, schema, golden fixture, and boundary guards while making a narrow permission-core fix so spec-level effect-plan validation runs before per-effect permission checks.

### Merge Readiness
- Base branch freshness: confirmed. The round branch `orchestrator/round-002-facade-laws` is based on the current local base branch `codex/workflow-facade-extraction` at `64672ec`, and `codex/workflow-facade-extraction` is an ancestor of `HEAD`. No remote head for `codex/workflow-facade-extraction` was advertised by `origin`, so freshness is confirmed against the repo-local base.
- Merge ordering satisfied: yes. `item-002-facade-laws` declares `Merge after: item-001-checked-action-failure-core`; the active roadmap marks item-001 done, and `orchestrator/state.json` records `last_completed_round` as `round-001`. `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `review.md` and `review-record.json`. The review evidence records passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, and focused facade-law, schema/golden guard, and permission-core boundary checks. After this squash merge, the next dependent roadmap item is `item-003-boundary-guards`.
