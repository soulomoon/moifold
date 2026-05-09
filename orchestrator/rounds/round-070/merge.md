### Squash Commit
- Title: Record issue-snapshot timing evidence
- Summary: Adds round-local evidence for the live `issue-snapshot.json` writer path and timing contract. The evidence records that execute-mode issue planning writes the snapshot before planner turn start, documents the prompt/path contract and focused timing tests, confirms there is no checked-in live fixture and no current healthcheck/repair/restart/replay reader, and keeps the current classification conservative as `defer` without approving behavior changes.

### Merge Readiness
- Base branch freshness: confirmed. Round worktree HEAD, local base branch HEAD, and merge-base are all `08ec4182d6b8475987b9a99e22683418734d4eae`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0 0`.
- Merge ordering satisfied: yes. `round-070` has no declared `depends_on_round_ids` or `merge_after_item_ids`, no parallel group, and `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
This round is evidence-only. It does not approve filename, schema, event type, write-timing, planner-turn, projection, healthcheck, repair, replay, cleanup, deprecation, removal, publication, upload, or release behavior changes. Remaining blockers are the missing live fixture coverage, missing external/downstream direct-reader inventory, and explicit reviewer approval before any compatibility migration or cleanup.
