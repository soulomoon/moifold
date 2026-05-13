### Squash Commit
- Title: Migrate TurnClassifier to direct workflow ID imports
- Summary: Round 166 migrates `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing `ThreadId` from `CodexWatcher.Workflow.Agent.Ids` and `CommitSha (..), PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`. The reviewed diff is import-only for the selected production file and preserves the classifier behavior and public compatibility surfaces.

### Merge Readiness
- Base branch freshness: confirmed; local `orchestrator/round-166-highest-value-cleanup-slice` HEAD and `codex/workflow-facade-extraction` both resolve to `886cd3a1e331e1634a7aa6c1679465600cff40ed`, and the base is an ancestor of HEAD.
- Merge ordering satisfied: yes; `merge_after_item_ids` is empty, `pending_merge_rounds` is empty, `max_parallel_rounds` is 1, and round 166 is the active merge-stage round after `last_completed_round` round 165.
- Pending dependencies: none; `depends_on_round_ids` is empty and `review-record.json` records the round as approved.

### Follow-Up Notes
Review approval is explicit in `review.md` with decision `APPROVED`. The controller can squash merge this round when ready; no implementation code, state, roadmap, package descriptor, facade, or public exposure follow-up is part of this merge artifact.
