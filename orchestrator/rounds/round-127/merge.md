### Squash Commit
- Title: Move DocsMigration off EventLog facade
- Summary: Move `src/CodexWatcher/Workflow/DocsMigration.hs` from the mixed `CodexWatcher.Workflow.EventLog` compatibility facade to direct owner imports from `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit`. The round preserves DocsMigration behavior, event/schema/export surfaces, package exposure, and the existing out-of-scope facade users while applying only the required direct audit type spelling.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction`, `HEAD`, and their merge-base all resolve to `8f015bff1d9bd650d5d426dba51f0b786b240c0c` in the round worktree.
- Merge ordering satisfied: yes. The selection declares no `depends_on_round_ids` and no `merge_after_item_ids`; no worker fan-out or merge-order blocker is present for this serial round.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer decision is approved in both `review.md` and `review-record.json`. Remaining exact `CodexWatcher.Workflow.EventLog` facade users are intentionally out of scope for this round, including the public facade/exposure, `src/CodexWatcher/Daemon.hs`, tests/test support, and docs/policy references.
