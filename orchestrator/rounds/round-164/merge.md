### Squash Commit
- Title: Round 164: Migrate EventLogRepair ID imports
- Summary: Migrate `src/CodexWatcher/EventLogRepair.hs` from the `CodexWatcher.Core.Ids` compatibility facade to the direct owner imports `CodexWatcher.Workflow.Agent.Ids (TurnId (..))` and `CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))`. The reviewed diff is import-only for the production file and preserves event-log repair behavior, replay validation, event construction, public facade exposure, and package descriptors.

### Merge Readiness
- Base branch freshness: confirmed. Local `HEAD`, branch `orchestrator/round-164-highest-value-cleanup-slice`, and base branch `codex/workflow-facade-extraction` all point at `d9a5c2f04959c693fcda55308220b01151490ff2`, with the merge base also equal to that commit.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve the round; `state.json` has `last_completed_round` set to `round-163`, `pending_merge_rounds` empty, `max_parallel_rounds` set to `1`, and the active round is `round-164` at stage `merge`.
- Pending dependencies: none. The selected scheduler fields declare `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`.

### Follow-Up Notes
The round is ready for the controller to squash merge after including the approved implementation diff and round artifacts. Keep follow-up cleanup focused on the remaining `CodexWatcher.Core.Ids` users recorded in the implementation and review notes; this round does not remove or deprecate the public compatibility facade.
