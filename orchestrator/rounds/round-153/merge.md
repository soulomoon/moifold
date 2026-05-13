### Squash Commit
- Title: Migrate IssueFanoutAppServerSpec to GitHub ID owners
- Summary: Round 153 migrates `test/IssueFanoutAppServerSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade for `IssueNumber`, `RepoName`, and `unIssueNumber`, using the direct owner import from `CodexWatcher.Workflow.GitHub.Ids`. The selected test coverage and public compatibility surfaces remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` at `1c0de9308bda8d11be00636a7fe08fae2e541f92`; the round branch has the same base commit and `origin` does not advertise a `codex/workflow-facade-extraction` ref.
- Merge ordering satisfied: yes; `depends_on_round_ids` and `merge_after_item_ids` are empty, `pending_merge_rounds` is empty, and the active round has `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is recorded in `orchestrator/rounds/round-153/review.md` and `orchestrator/rounds/round-153/review-record.json`. Remaining `CodexWatcher.Core.Ids` users, facade exposure, package descriptor cleanup, docs cleanup, runtime compatibility cleanup, milestone completion, release approval, and public compatibility removal remain later roadmap work.
