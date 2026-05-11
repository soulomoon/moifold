### Squash Commit
- Title: Refresh compatibility facade import inventory
- Summary: Round 097 records the current import, exposure, documentation, and standalone package-candidate inventory for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The approved artifact confirms current selected-facade counts, package exposure, direct-owner package availability, `Core.Ids` domain classifications, and next-slice blockers without changing implementation code, tests, package descriptors, docs, public API, runtime compatibility files, roadmap files, or controller state.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD`, `codex/workflow-facade-extraction`, and their merge-base all resolve to `460a74b829d6676e04ccc949fb488b5e2a8a0d6f`. No `origin/codex/workflow-facade-extraction` ref is available, so remote freshness is not a separate gate for this repo-local merge.
- Merge ordering satisfied: yes. `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, `max_parallel_rounds` is `1`, and `review.md` / `review-record.json` approve the round.
- Pending dependencies: none.

### Follow-Up Notes
Ready for squash merge. Review evidence records corrected `Core.Ids` exact-token totals of 3 GitHub-only, 2 agent-only, and 39 combined users, confirms `test/BoundaryPolicySpec.hs` is GitHub-only, and preserves the round as evidence-only. Later convergence slices should use this inventory for scoped import moves, but this round does not approve import migration, Cabal exposure changes, public deprecation, facade removal, runtime compatibility cleanup, release approval, or milestone completion.
