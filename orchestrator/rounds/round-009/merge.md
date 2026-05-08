### Squash Commit
- Title: Add indexed PR-review reviewer outcome adapter
- Summary: Port PR-review reviewer outcome transitions to the indexed workflow API with a narrow moifold adapter for clean, problems-added, incomplete, blocked, verification-clean, and missing-thread verification outcomes. The implementation keeps live daemon routing and compatibility behavior unchanged while adding focused parity coverage for facade observation, compatibility planning, indexed planning, replay, apply, validation, permissions, classifier evidence, invalid observations, and existing effect ordering.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-009-indexed-pr-review-reviewer-outcomes` and `codex/workflow-facade-extraction` both resolve to `417eb9a329ade2426f1fac1f208b5f04c8de6026`, and `codex/workflow-facade-extraction` is an ancestor of the round branch.
- Merge ordering satisfied: yes. `item-009-indexed-pr-review-reviewer-outcomes` declares `Merge after: item-008-indexed-pr-review-worker-outcomes`; the roadmap marks item 008 done, and `state.json` records `last_completed_round` as `round-008`.
- Pending dependencies: none. `review.md` and `review-record.json` approve the round after `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

### Follow-Up Notes
After this round is squashed, the next roadmap item is `item-010-indexed-pr-review-mergeability-complete`, which depends on item 009 and should extend indexed mergeability and merge terminal coverage without changing daemon result shapes, dry-run text, event schemas, or golden logs.
