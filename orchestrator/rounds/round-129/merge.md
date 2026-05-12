### Squash Commit
- Title: Remove unused workflow agent EventLog imports
- Summary: Removes the unused exact `CodexWatcher.Workflow.EventLog qualified as WorkflowEventLog` compatibility-facade imports from `test/WorkflowAgentSpec.hs` and `test/TestSupport/Workflow.hs` while preserving the direct EventLog owner imports and workflow test behavior. The approved review records the selected-file import scan, broad out-of-scope test import scan, focused `workflowAgentTests` REPL preflight, `cabal test watcher-core-test`, `cabal build all`, and diff hygiene checks as passing.

### Merge Readiness
- Base branch freshness: confirmed; `codex/workflow-facade-extraction`, `HEAD`, and their merge base are all `4908816781db5e74de6ba72ebdcd847e2ebaafbc`.
- Merge ordering satisfied: yes; the selection declares no `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and no batch ordering constraints.
- Pending dependencies: none.

### Follow-Up Notes
This round is only the approved internal test/support import-removal slice. It does not approve public facade removal, Cabal exposure cleanup, docs/policy changes, runtime compatibility changes, milestone completion, terminal completion, release approval, or package publication. Remaining exact `WorkflowEventLog` facade imports are still present only in out-of-scope test files. The worktree also shows controller-owned `orchestrator/state.json` changes that were outside this role's write scope.
