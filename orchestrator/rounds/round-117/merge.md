### Squash Commit
- Title: Move Healthcheck off AppServerClient facade
- Summary: Round 117 moves `src/CodexWatcher/Healthcheck.hs` off the public `CodexWatcher.AppServerClient` compatibility facade and onto the direct Codex client and transport owner imports. The approved diff is import-only for Healthcheck, preserves the existing app-server thread inspection behavior, and leaves the facade, package exposure, protocol modules, tests, docs, and remaining facade users unchanged for later rounds.

### Merge Readiness
- Base branch freshness: confirmed; local `codex/workflow-facade-extraction` and the round worktree HEAD are both at `bef93fd`, the provided base HEAD before the round-117 squash commit.
- Merge ordering satisfied: yes; `merge_after_item_ids` is empty and `pending_merge_rounds` is empty.
- Pending dependencies: none; `depends_on_round_ids` is empty and review approved `round-117-healthcheck-appserverclient-import-convergence`.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` source users are intentionally out of scope for this squash and should be selected in later import-convergence rounds. This merge should not be treated as facade deprecation, facade removal, package-boundary completion, or milestone completion.
