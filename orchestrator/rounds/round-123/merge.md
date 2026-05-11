### Squash Commit
- Title: Add PR-review launch app-server coverage
- Summary: Adds focused watcher-core coverage for the PR-review launch CLI app-server path. The round exercises endpoint-backed worker and reviewer `thread/start` launches, refreshed thread-id persistence, dry-run child command rendering for root and non-root app-server paths, and selected JSON-RPC/decode failure formatting, with no production code changes.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction` and `orchestrator/round-123-highest-value-cleanup-slice` both resolve to `f76b2610862fa2f4fec27033fcda1b66afdbe9fb`, so the round worktree diff is based on the current local base.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids`, no `merge_after_item_ids`, and no `parallel_group`; `orchestrator/state.json` has no pending merge rounds and marks round-123 at merge stage with `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved in `review.md` and `review-record.json`. Reviewer evidence reports passing focused REPL coverage, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, import/migration guards, changed-path guards, forbidden-surface guards, package-descriptor guard, no-worker-plan guard, and control-plane checks. The next compatible slice can use this coverage before migrating `Domain/PrReview/LaunchCli.hs` away from the compatibility facade.
