### Squash Commit
- Title: Route IssueImplement plan and PR setup daemon observations through indexed projection
- Summary: This round routes the seven item-019 live IssueImplement plan-mode and PR setup daemon observations through the moifold-owned indexed adapter in `Daemon.hs`: plan turn start, plan completion, follow-up worker refresh, attempt-branch advancement, PR created, PR reused, and PR body updated. The approved tests prove dry-run and execute daemon ticks match both the compatibility workflow projection and the indexed projection, while source-scan guards keep indexed routing out of loop modules and keep item-020+ daemon projectors off this route.

### Merge Readiness
- Base branch freshness: confirmed locally. `codex/workflow-facade-extraction`, `orchestrator/round-019-indexed-issue-implementation-plan-and-pr-setup-daemon`, and `HEAD` all resolve to `635d20b`, and `git rev-list --left-right --count codex/workflow-facade-extraction...orchestrator/round-019-indexed-issue-implementation-plan-and-pr-setup-daemon` reports `0 0`. No upstream is configured for `codex/workflow-facade-extraction`, so remote freshness was not applicable from this worktree.
- Merge ordering satisfied: yes. Roadmap item `item-019-indexed-issue-implementation-plan-and-pr-setup-daemon` declares `Merge after: item-018-indexed-issue-implementation-policy`; item 018 is completed on base in `9f34a40` and marked done by `635d20b`.
- Pending dependencies: none.

### Follow-Up Notes
Next round `item-020-indexed-issue-implementation-worker-daemon` can route implementation-turn IssueImplement daemon observations through the indexed projection. Keep review handoff, PR merge wait, post-merge review, issue close, child lifecycle, and later observations out of scope until their roadmap items; this round intentionally preserves the existing moifold ownership of PR discovery, branch advancement, GitHub command parsing, issue-plan recording, PR body rendering, compatibility writes, dry-run text, action ordering, and request-id behavior.
