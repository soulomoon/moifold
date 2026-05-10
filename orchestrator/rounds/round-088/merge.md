### Squash Commit
- Title: Record planning state compatibility contract
- Summary: This round records the distinct compatibility contract for `planner-state.json` and `planning-state.json`. It adds focused watcher-core tests for the compatibility projection and direct `RecordPlanningGraph` writer, strengthens the healthcheck source-policy assertion that issue planning reads `planner-state.json` and not `planning-state.json`, and updates the compatibility deprecation policy to keep `planner-state.json` as a distinct current surface with future migration/removal blockers.

### Merge Readiness
- Base branch freshness: confirmed. `git merge-base HEAD codex/workflow-facade-extraction`, `git rev-parse HEAD`, and `git rev-parse codex/workflow-facade-extraction` all resolved to `4eac9efb0a1c5904c3a4ba8796fc3b615bb93906`, so the round worktree is based directly on the current base branch tip.
- Merge ordering satisfied: yes. `orchestrator/state.json` has active `round-088` at merge stage, `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and the round is serial under `max_parallel_rounds: 1`.
- Pending dependencies: none. Review approved the round, and the required merger checks passed: `git diff --check` reported no whitespace errors and `git status --short --untracked-files=all` showed only the approved round changes plus round-local artifacts.

### Follow-Up Notes
Squash the approved worktree changes for round-088 with the title above. The branch tip currently matches the base commit, so the squash should include the unstaged approved implementation/review artifacts in this worktree. Do not treat this round as approval for compatibility-file deletion, rename, schema migration, healthcheck reader changes, repair changes, fixture batch expansion, public deprecation, or roadmap completion.
