### Squash Commit
- Title: Add runtime-owner compatibility fixture
- Summary: Adds the checked-in `runtime-owner.json` current-lease compatibility fixture and extends the watcher-core runtime compatibility fixture tests to lock the current top-level `lease` shape, runtime-owner reader acceptance, healthcheck `runtimeOwner` mapping and summary field path, and restart-script pid extraction and cleanup assumptions.

### Merge Readiness
- Base branch freshness: confirmed; `HEAD`, `codex/workflow-facade-extraction`, and their merge-base all resolve to `4687047d50bd23061eff42b731556b9e161d8a35`, so the round worktree is based on the current local base branch tip.
- Merge ordering satisfied: yes; state is at `stage: merge` for `round-094`, `last_completed_round` is `round-093`, `pending_merge_rounds` is empty, and the selected round declares no `merge_after_item_ids`.
- Pending dependencies: none; the active round declares no `depends_on_round_ids`, no parallel group, and review approved the round after `watcher-core-test`, `cabal build all`, and diff checks passed.

### Follow-Up Notes
This round is fixture and test evidence only. It does not authorize runtime-owner schema migration, compatibility-file removal or rename, public deprecation, healthcheck behavior changes, restart-script behavior changes, repair behavior changes, roadmap edits, or controller-state edits beyond the existing active-round metadata.
