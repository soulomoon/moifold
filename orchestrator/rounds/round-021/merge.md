### Squash Commit
- Title: Route IssueImplement handoff and merge-wait daemon observations through indexed projection
- Summary: This approved round routes the item-021 IssueImplement review-handoff, reviewer-thread-ready, idempotent completion-after-handoff, and waiting-for-PR-merge daemon observations through the moifold-owned indexed IssueImplement projection, then converts them back to the existing daemon transaction surface. The implementation keeps PR merge polling, reviewer reuse, compatibility writes, request-id behavior, audit labels, event append ordering, and daemon result shapes on the existing runtime path, while focused and full watcher-core coverage verify parity and source-scan boundaries.

### Merge Readiness
- Base branch freshness: confirmed. The round branch is based on `codex/workflow-facade-extraction` at `d4dc54b`, which includes the item-020 merge commit `78e3100` and the roadmap completion mark in `d4dc54b`.
- Merge ordering satisfied: yes. Item 021 declares `Merge after: item-020-indexed-issue-implementation-worker-daemon`; item 020 is completed on base before this round.
- Pending dependencies: none for this round.

### Follow-Up Notes
Item 022 remains the next indexed IssueImplement daemon slice: post-merge reviewer start/outcome and follow-up routing are still intentionally on compatibility fallback. Keep the item-022+ guards in place until that round routes those observations through the indexed projection.
