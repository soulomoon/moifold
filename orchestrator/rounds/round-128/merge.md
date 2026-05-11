### Squash Commit
- Title: Move Daemon audit off EventLog facade
- Summary: This round removes `src/CodexWatcher/Daemon.hs` from exact `CodexWatcher.Workflow.EventLog` compatibility facade usage for daemon audit helpers and switches those audit type/helper references to the existing direct owner import, `CodexWatcher.Workflow.Audit`. Direct `CodexWatcher.Workflow.EventLog.Commit.Core` ownership remains unchanged, preserving daemon observed-tick, audit, transaction, replay, event-commit, compatibility-write, and public-export behavior.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction`, `HEAD`, and their merge base all resolve to `08242af3b11053dd9569ba7a277f00941db3004f` in the round worktree.
- Merge ordering satisfied: yes; `selection.md` declares no `depends_on_round_ids` and no `merge_after_item_ids`, and no additional ordering blocker is recorded for this serial round.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is recorded in both `review.md` and `review-record.json`. Local merge-prep checks confirmed the live diff is limited to the Daemon audit import/type/qualifier convergence, `git diff --check` passes, the exact Daemon `CodexWatcher.Workflow.EventLog` facade import is absent, the direct `CodexWatcher.Workflow.Audit` and `CodexWatcher.Workflow.EventLog.Commit.Core` imports remain, and no stale `WorkflowEventLog.` daemon qualifiers remain. Implementation and review artifacts record passed focused daemon/workflow REPL probes, `cabal build all`, `cabal test watcher-core-test`, diff checks, and facade/import scans.

Remaining exact EventLog facade references in tests, test support, docs/policy, public facade/exposure, and Cabal exposure are intentionally out of scope for this round.
