### Squash Commit
- Title: Add indexed PR-review mergeability slice
- Summary: Port the PR-review mergeability-clean transition to the indexed workflow API through a sibling `Mergeability.Indexed` module while preserving the compatibility facade path. The round exposes the indexed module in `moifold.cabal` and strengthens golden-backed parity tests for the clean mergeability transition, merge pre-commit effect ordering, replay behavior, and mismatched clean-commit rejection.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` and `orchestrator/round-006-indexed-pr-review-slice` both resolve to `f4ec2d7` (`Mark workflow roadmap round 005 complete`), and the base is an ancestor of the round worktree HEAD.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `last_completed_round` as `round-005`, `pending_merge_rounds` as empty, and round-006 `merge_after_item_ids` as `item-005-indexed-docs-migration`; the active roadmap marks item-005 `[done]` and item-006 depends on / merges after item-005.
- Pending dependencies: none. Reviewer decision is approved in `review.md` and `review-record.json`; required checks recorded by review are `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`, all passing.

### Follow-Up Notes
Keep the squash focused on the round implementation and this merge preparation artifact. `orchestrator/state.json` is dirty with active round metadata in this worktree; leave any controller state advancement to the controller/update-roadmap stage rather than folding it into the implementation squash.
