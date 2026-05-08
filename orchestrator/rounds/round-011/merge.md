### Squash Commit
- Title: Route mergeability-clean daemon observations through indexed PR-review planning
- Summary: Routes the live `PrWaitingForMergeability` plus `ObservedMergeabilityClean` daemon observation path through the indexed PR-review mergeability adapter while projecting back to the existing moifold daemon transaction surface. The round also adds focused parity coverage for dry-run, execute, pre-commit failure, invalid observations, compatibility writes, action ordering, request-id stability, and unchanged daemon result/failure reporting.

### Merge Readiness
- Base branch freshness: confirmed against `codex/workflow-facade-extraction`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reported `0 0` in the round worktree before this merge note was authored.
- Merge ordering satisfied: yes. `item-011-indexed-pr-review-daemon-path` declares `Merge after: item-010-indexed-pr-review-mergeability-complete`; the active roadmap marks item 010 done and `orchestrator/state.json` records `last_completed_round` as `round-010`.
- Pending dependencies: none. The active round has no `depends_on_round_ids`, and the roadmap dependency on `item-010-indexed-pr-review-mergeability-complete` is satisfied.

### Follow-Up Notes
Round 011 is explicitly approved in `orchestrator/rounds/round-011/review.md` and `review-record.json`. Reviewer evidence includes passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`. Keep the squash focused on item 011 only; item 012 remains pending and depends on this merge.
