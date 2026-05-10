### Squash Commit
- Title: Add issue-snapshot compatibility fixture
- Summary: Adds the checked-in live `issue-snapshot.json` compatibility fixture for a scoped open root issue with a closed child sub-issue, and extends watcher-core runtime compatibility fixture tests to lock the current snapshot shape, parser acceptance, execute-mode write-before-planner-turn timing, planner prompt consumption, and healthcheck/repair/replay/restart non-reader boundaries.

### Merge Readiness
- Base branch freshness: confirmed; `HEAD`, `codex/workflow-facade-extraction`, and their merge-base all resolve to `f9c3d9747afcbeddac75164fd1bd844629030bd1`, so the round worktree is based on the current local base branch tip.
- Merge ordering satisfied: yes; state is at `stage: merge` for `round-095`, `last_completed_round` is `round-094`, `pending_merge_rounds` is empty, `max_parallel_rounds` is `1`, and the selected round declares no `merge_after_item_ids`.
- Pending dependencies: none; the active round declares no `depends_on_round_ids`, no parallel group, and review approved the round after `watcher-core-test`, `cabal build all`, and diff checks passed.

### Follow-Up Notes
This round is fixture and test evidence only. It does not authorize `issue-snapshot.json` schema migration, compatibility-file removal or rename, public deprecation, planner prompt behavior changes, healthcheck behavior changes, repair behavior changes, replay behavior changes, restart-script behavior changes, roadmap edits, or controller-state edits beyond the existing active-round metadata.
