### Squash Commit
- Title: Migrate PR-review protocol to direct ID owner imports
- Summary: Round 163 migrates `src/CodexWatcher/Domain/PrReview/Protocol.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing `ThreadId` and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`, and `CommitSha` and `ReviewThreadId` from `CodexWatcher.Workflow.GitHub.Ids`. The reviewed diff is import-only and preserves PR-review protocol session types, outcomes, runner functions, turn helpers, and event construction.

### Merge Readiness
- Base branch freshness: confirmed. The round branch `orchestrator/round-163-highest-value-cleanup-slice` and base branch `codex/workflow-facade-extraction` both point at local commit `bff291c35d3a4d0f4eecf37d27e1237bacadd0af`; the merge-base is the same commit, so the local branch/head relationship is fresh against the configured base.
- Merge ordering satisfied: yes. State has `max_parallel_rounds: 1`, `last_completed_round: round-162`, active round `round-163`, `pending_merge_rounds: []`, and the selected item declares `merge_after_item_ids: []`.
- Pending dependencies: none. The selected item declares `depends_on_round_ids: []`, and the review decision is `APPROVED`.

### Follow-Up Notes
The round is ready for squash merge from the merger role perspective. Suggested squash title: `Migrate PR-review protocol to direct ID owner imports`.
