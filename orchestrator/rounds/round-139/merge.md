### Squash Commit
- Title: Move WorkflowExecutionSpec permission checks to direct owners
- Summary: This round removes the concrete `CodexWatcher.Workflow.Permission` compatibility-facade dependency from `test/WorkflowExecutionSpec.hs`. The selected Moifold permission assertions now use direct `validatePhaseActionPlan` checks, and the selected core permission assertions now call `WorkflowPermissionCore.validateWorkflowEffectPlanCore @MoifoldSpec`. `test/FacadeImportPolicySpec.hs` remains the intentional out-of-scope Permission facade policy/parity coverage owner.

### Merge Readiness
- Base branch freshness: confirmed; local `orchestrator/round-139-highest-value-cleanup-slice`, `codex/workflow-facade-extraction`, and their merge-base are all `35aa55ddadd3f581d1d8476c8f841ed419864d8d`.
- Merge ordering satisfied: yes; `orchestrator/state.json` lists active `round-139`, no `pending_merge_rounds`, no `depends_on_round_ids`, and no `merge_after_item_ids`.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved. Focused and broad scans recorded in `review.md` leave no `WorkflowPermission.` use or exact old Permission facade import in `test/WorkflowExecutionSpec.hs`, with the remaining exact Permission facade import/use only in `test/FacadeImportPolicySpec.hs` by design. Verification recorded by review passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
