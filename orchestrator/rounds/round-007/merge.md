### Squash Commit
- Title: Add indexed PR-review checking adapter
- Summary: Port PR-review checking and verification observations to a moifold-owned indexed adapter while preserving the existing compatibility facade and externally visible behavior. The round adds focused parity coverage for unresolved threads, clean threads, feedback observations, verification start, replay/effect/permission behavior, and invalid observation failures without routing live daemon paths through the indexed adapter.

### Merge Readiness
- Base branch freshness: confirmed locally against `codex/workflow-facade-extraction`; `HEAD` and the local base ref are both `147563bac79e067170683385f58f75e2722154a8` with `0	0` divergence. No `origin/codex/workflow-facade-extraction` remote ref is present, so remote freshness could not be checked.
- Merge ordering satisfied: yes. `item-007-indexed-pr-review-checking` declares `Merge after: none`, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
The round is approved in `review.md` and `review-record.json`. Verification evidence recorded by the reviewer includes `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` passing. The next roadmap item is `item-008-indexed-pr-review-worker-outcomes`, which depends on this item after squash merge.
