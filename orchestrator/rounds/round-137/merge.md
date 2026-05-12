### Squash Commit
- Title: Remove unused Workflow Permission imports from tests
- Summary: This round removes the unused exact `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` import from `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`, and `test/TestSupport/Workflow.hs`. The cleanup is import-only: assertions, fixtures, event schemas, aggregate wiring, helper exports, direct EventLog owner imports, workflow behavior, package descriptors, production code, public facade modules, roadmap files, and the out-of-scope Permission facade use sites are unchanged.

### Merge Readiness
- Base branch freshness: confirmed; local `codex/workflow-facade-extraction` and `orchestrator/round-137-highest-value-cleanup-slice` both resolve to `cc0b3bec05f154e75fa619572b53653bf526da4f`, and the base branch is an ancestor of the round branch.
- Merge ordering satisfied: yes; state has `max_parallel_rounds: 1`, `pending_merge_rounds: []`, no active round dependencies, and no `merge_after_item_ids`.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` approved the round after focused scans, `git diff --check`, `git diff --cached --check`, `cabal test watcher-core-test`, and `cabal build all` passed. The remaining exact `WorkflowPermission` facade imports and use sites in `test/FacadeImportPolicySpec.hs`, `test/WorkflowIndexedSpec.hs`, and `test/WorkflowExecutionSpec.hs` are intentional and remain out of scope for this squash merge.
