### Squash Commit
- Title: Migrate RuntimeConfig to direct ID owner imports
- Summary: This round moves `src/CodexWatcher/Cli/RuntimeConfig.hs` off the combined `CodexWatcher.Core.Ids` compatibility facade for its existing ID imports. `RequestId` now comes from `CodexWatcher.Workflow.Agent.Ids`, while `IssueNumber` and `RepoName` come from `CodexWatcher.Workflow.GitHub.Ids`; runtime configuration behavior, planner-scope behavior, public facade exposure, and remaining `Core.Ids` users are unchanged.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD` and `codex/workflow-facade-extraction` both resolve to `6d93aa227d59f929b364cbf081843b3dca23a362`, and each is an ancestor of the other.
- Merge ordering satisfied: yes. `review.md` records `APPROVED`, `review-record.json` records `decision: approved`, `orchestrator/state.json` has round-160 in `stage: merge` with `merge_ready: true`, and there are no pending merge rounds.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are empty, and `parallel_group` is `null`.

### Follow-Up Notes
This merge note only prepares the approved one-file import convergence slice for squash merge. It does not claim deprecation, facade deletion, Cabal exposure cleanup, milestone completion, terminal completion, release approval, or public compatibility removal.
