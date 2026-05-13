### Squash Commit
- Title: Round 185: Migrate issue planning loop ID imports
- Summary: This round migrates the issue-planning loop away from the `CodexWatcher.Core.Ids` compatibility facade by importing agent IDs directly from `CodexWatcher.Workflow.Agent.Ids` and GitHub IDs directly from `CodexWatcher.Workflow.GitHub.Ids`. The change is import-only in `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, preserves the focused planning-loop behavior covered by `watcher-core-test`, and leaves `src/CodexWatcher/Domain/IssueImplement/Loop.hs` as the expected later production `Core.Ids` user.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction` is an ancestor of the round branch, and both currently resolve to `6c8a4d2`; the approved round diff is worktree-local on top of that base.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids` and no `merge_after_item_ids`; `state.json` keeps `max_parallel_rounds` at `1`, the active round is in `merge`, and `review.md` approved the round.
- Pending dependencies: none.

### Follow-Up Notes
No source, test, docs, Cabal, roadmap, runtime compatibility, or public facade cleanup is approved beyond this round's import-only issue-planning loop migration. The remaining production `CodexWatcher.Core.Ids` import is `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, which is intentionally left for a later round.
