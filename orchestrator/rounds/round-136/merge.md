### Squash Commit
- Title: Move DocsMigration permission tests to Permission.Core
- Summary: Round 136 migrates only `test/WorkflowDocsMigrationSpec.hs` from the `CodexWatcher.Workflow.Permission` compatibility facade to the direct `CodexWatcher.Workflow.Permission.Core` owner import for the existing `validateWorkflowEffectPlanCore @DocsMigration.DocsMigrationSpec` assertions. The review confirms the seven selected call heads were updated without changing DocsMigration assertions, fixtures, event schemas, aggregate wiring, indexed permission parity checks, package descriptors, public facades, docs, policy, or runtime compatibility surfaces.

### Merge Readiness
- Base branch freshness: confirmed; local base branch `codex/workflow-facade-extraction` is an ancestor of `HEAD` and currently points at the same commit as `orchestrator/round-136-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes; selection and state declare serial execution with `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is `APPROVED` in `orchestrator/rounds/round-136/review.md` and `review-record.json`. Validation recorded by review passed `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and focused import/diff scans. Remaining `CodexWatcher.Workflow.Permission` facade imports are intentionally out of scope in other test/support files and should be handled by later exact selections.
