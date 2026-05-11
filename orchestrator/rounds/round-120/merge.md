### Squash Commit
- Title: Move IssuePlanning loop off AppServerClient facade
- Summary: This round performs the approved import-only migration for `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`: it removes the `CodexWatcher.AppServerClient` facade import and imports `AppServerTurn` directly from `CodexWatcher.Workflow.Agent.Codex.Client`. The review confirmed behavior and non-import code stayed unchanged, including planning systemError retry/blocking behavior and planner app-server request/read handling.

### Merge Readiness
- Base branch freshness: confirmed. The round is based on `codex/workflow-facade-extraction`, and `codex/workflow-facade-extraction` is an ancestor of the current round branch head.
- Merge ordering satisfied: yes. The round branch is `orchestrator/round-120-highest-value-cleanup-slice`; `depends_on_round_ids`, `merge_after_item_ids`, and `pending_merge_rounds` are all empty, so no dependency or pending merge blocks this squash merge.
- Pending dependencies: none.
- Review decision: APPROVED in `orchestrator/rounds/round-120/review.md` and `orchestrator/rounds/round-120/review-record.json`.

### Follow-Up Notes
Remaining `CodexWatcher.AppServerClient` source users are out of scope for this round. This merge readiness note does not approve facade removal, public deprecation, Cabal exposure cleanup, milestone completion, or terminal roadmap completion.
