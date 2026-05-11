### Squash Commit
- Title: Consolidate healthcheck runtime-state contract evidence
- Summary: Round 096 adds focused watcher-core source-policy coverage for the current healthcheck runtime-state read and non-read contract. The test records the existing healthcheck mappings for `daemon-state.json`, `planner-state.json`, `block-state.json`, and `runtime-owner.json`; keeps explicit non-reader boundaries for `planning-state.json`, `repair-state.json`, and live `issue-snapshot.json`; and does not change production healthcheck behavior or runtime compatibility file formats.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `orchestrator/round-096-highest-value-cleanup-slice` and the base branch both point at `e7a541837d6453f5df792b5b8f5bb9611629bddd`. No `origin/codex/workflow-facade-extraction` ref is available, so remote freshness is not a separate gate for this repo-local merge.
- Merge ordering satisfied: yes. `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and `review.md` / `review-record.json` approve the round.
- Pending dependencies: none.

### Follow-Up Notes
Ready for squash merge. Review evidence records passing `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. This round is current contract evidence only; it does not approve compatibility-file migration, deprecation, deletion, release, publication, or milestone completion.
