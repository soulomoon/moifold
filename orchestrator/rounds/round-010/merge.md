### Squash Commit
- Title: Complete indexed PR-review mergeability terminal coverage
- Summary: Extends the PR-review mergeability indexed slice with blocked and complete target markers and focused parity coverage for retry, recheck, fix-required, blocked, clean merge, and merge-completed observations. The round preserves the compatibility facade and existing moifold behavior while proving replay, effect planning, permissions, dry-run output, request-id progression, merge pre-commit ordering, and merged-state compatibility writes remain aligned with the legacy path.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD...codex/workflow-facade-extraction` is `0 0`, so the worktree starts from the configured base tip. `origin` does not currently advertise a `codex/workflow-facade-extraction` ref.
- Merge ordering satisfied: yes. `item-010-indexed-pr-review-mergeability-complete` declares `Merge after: item-009-indexed-pr-review-reviewer-outcomes`; the active roadmap marks item 009 done and `orchestrator/state.json` records `last_completed_round` as `round-009`.
- Pending dependencies: none. The active round has no `depends_on_round_ids`, `pending_merge_rounds` is empty, and `review.md` explicitly approves the round.

### Follow-Up Notes
Round 010 is ready for squash merge after item 009. Keep the squash commit scoped to the indexed mergeability terminal coverage and its tests; do not include controller-state churn beyond the existing round artifacts.
