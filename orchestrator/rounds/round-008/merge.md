### Squash Commit
- Title: Add indexed PR-review worker outcome adapter
- Summary: Port PR-review fix-worker outcome transitions to a moifold-owned indexed adapter while preserving the existing compatibility facade and externally visible behavior. The round adds focused parity coverage for completed, incomplete, blocked, classifier-backed, and invalid worker observations without changing event schemas, golden logs, daemon result shapes, dry-run output, action rendering, or live daemon routing.

### Merge Readiness
- Base branch freshness: confirmed locally against `codex/workflow-facade-extraction`; `HEAD` and the local base ref are both `a722745f10ea62776b291274da9b393ed650f297` with `0	0` divergence. Remote freshness could not be checked because `origin` does not advertise `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. `item-008-indexed-pr-review-worker-outcomes` declares `Merge after: item-007-indexed-pr-review-checking`; the roadmap marks item 007 done, `state.json` records `last_completed_round` as `round-007`, `pending_merge_rounds` is empty, and the local base includes the round-007 completion commit.
- Pending dependencies: none.

### Follow-Up Notes
The round is approved in `review.md` and `review-record.json`. Reviewer evidence records `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check` passing. The next roadmap item is `item-009-indexed-pr-review-reviewer-outcomes`, which depends on item 008 after squash merge.
