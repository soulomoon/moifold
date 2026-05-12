### Squash Commit
- Title: Move WorkflowIndexedSpec permission check to Permission.Core
- Summary: This round migrates only `test/WorkflowIndexedSpec.hs` from the `CodexWatcher.Workflow.Permission` compatibility facade to the direct `CodexWatcher.Workflow.Permission.Core` owner import for its single `validateWorkflowEffectPlanCore @MoifoldSpec` assertion. The indexed workflow assertions, fixtures, permission-error expectations, public facade modules, package descriptors, docs, and the explicitly out-of-scope Permission facade users remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; local `orchestrator/round-138-highest-value-cleanup-slice` and `codex/workflow-facade-extraction` both point at `d881bbb`, with the approved round diff applied on top as working-tree changes.
- Merge ordering satisfied: yes; `orchestrator/state.json` is at stage `merge` for active `round-138`, `last_completed_round` is `round-137`, `pending_merge_rounds` is empty, `max_parallel_rounds` is `1`, and this round declares no `depends_on_round_ids` or `merge_after_item_ids`.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` approved the round after focused scans, broad remaining-use scans, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed. The remaining `CodexWatcher.Workflow.Permission qualified as WorkflowPermission` imports/use in `test/FacadeImportPolicySpec.hs` and `test/WorkflowExecutionSpec.hs` are intentionally out of scope for this squash merge.
