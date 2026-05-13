### Squash Commit
- Title: Migrate IssuePlanning watcher off Core.Ids imports
- Summary: This round updates only `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` to replace the combined `CodexWatcher.Core.Ids` import with direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only and preserves issue-planning observation, planning-graph validation, issue-number rendering, `selectIssueImplementationStarts`, public compatibility facade exposure, and all existing behavior.

### Merge Readiness
- Base branch freshness: confirmed. The round branch `orchestrator/round-162-highest-value-cleanup-slice` and local base branch `codex/workflow-facade-extraction` are both at `5709124296e5345bc2b87d4f735fa381e311dd51` (`Clear roadmap update after round-161`), and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0`. No `origin/codex/workflow-facade-extraction` remote head is published, so remote freshness is not applicable for this local base.
- Merge ordering satisfied: yes. `depends_on_round_ids` is `[]`, `merge_after_item_ids` is `[]`, `parallel_group` is `null`, `pending_merge_rounds` is `[]`, the controller state records `merge_ready: true`, and the review decision is `APPROVED`.
- Pending dependencies: none.

### Follow-Up Notes
The round is ready for squash merge. The approval covers only the one-file IssuePlanning watcher import migration; it does not approve `CodexWatcher.Core.Ids` deprecation or removal, Cabal exposure cleanup, public compatibility removal, broader import convergence, milestone completion, terminal roadmap completion, release approval, or package publication.
