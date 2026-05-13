### Squash Commit
- Title: Round 188: Migrate workflow event-log spec ID imports
- Summary: This round migrates `test/WorkflowEventLogSpec.hs` away from the `CodexWatcher.Core.Ids` facade by importing agent ids directly from `CodexWatcher.Workflow.Agent.Ids` and GitHub ids directly from `CodexWatcher.Workflow.GitHub.Ids`. The approved diff is import-only and preserves event-log assertions, fixture checks, PASS labels, aggregate wiring, and event JSON expectations.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` HEAD `9c904c5`; the round branch HEAD and merge-base are the same commit, so the approved worktree diff is based on the currently observed base HEAD.
- Merge ordering satisfied: yes. The controller state is in merge stage for `round-188`, `merge_ready` is true, `pending_merge_rounds` is empty, and the selected scheduler fields have no `parallel_group` or ordered predecessors.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are empty for `direction-011h-workflow-eventlog-spec-core-ids-import`.

### Follow-Up Notes
Reviewer approval is recorded in `review.md` and `review-record.json`; the reviewer validated `cabal build all`, `cabal test watcher-core-test`, diff checks, and the selected-file `CodexWatcher.Core.Ids` no-match scan. Remaining `Core.Ids` users are classified as later test, policy, docs, Cabal, or public facade work and are outside this round's scope.
