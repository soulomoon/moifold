### Squash Commit
- Title: Stabilize GitHub adapter API boundaries
- Summary: This round stabilizes the `agent-workflow-github` adapter API around GitHub identifier ordering, remote metadata parsing/classification, and pure GitHub/git command specifications. Moifold integration facades now consume those adapter-owned helpers, and focused parser, command-rendering, healthcheck metadata, and recursive package-boundary tests keep moifold lifecycle, daemon, runtime, healthcheck policy, repair policy, and app-server ownership outside the GitHub adapter package.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD` and the configured base branch both resolve to `7a30d51`, and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0	0`. Remote freshness could not be confirmed because `origin` does not advertise `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve round 033, `orchestrator/state.json` has this round in `merge` with `merge_ready: true`, `pending_merge_rounds` is empty, and the selected scheduler fields declare no `depends_on_round_ids`, no `merge_after_item_ids`, and no parallel group.
- Pending dependencies: none for this round. Milestone 005 remains downstream of completing milestone 004 after this GitHub adapter API stabilization round is merged and recorded.

### Follow-Up Notes
Round 033 is ready for the controller to squash merge from `orchestrator/round-033-next-framework-slice` after any final controller-side guard checks. The current round worktree carries the squash content as unstaged changes on top of `7a30d51`; no files are staged.
