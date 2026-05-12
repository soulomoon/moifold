### Squash Commit
- Title: Migrate DocsMigration spec off EventLog facade
- Summary: Moves only `test/WorkflowDocsMigrationSpec.hs` away from the exact `CodexWatcher.Workflow.EventLog` compatibility-facade import by using direct `Workflow.Audit` and `Workflow.EventLog.Core` owner imports for existing audit, replay, fixture, and replay-failure helpers. The reviewed diff is import/qualifier-only, preserves the DocsMigration assertions and fixtures, and leaves public facade exposure plus out-of-scope test and policy references for later rounds.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction`, `HEAD`, and their merge base all resolved to `2ee5ee74c4f2744a0f361ecdab4579b9c38d6c53`.
- Merge ordering satisfied: yes. The selection declares no `depends_on_round_ids`, no `merge_after_item_ids`, no `parallel_group`, and no `worker-plan.json` exists for this round.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer decision is APPROVED in both `review.md` and `review-record.json`. Focused DocsMigration aggregate, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, selected-file facade scans, broad facade scans, diff review, and no-worker-plan checks are recorded as passed. Remaining exact EventLog facade references are intentionally out of scope: public exposure/facade, Cabal exposure, docs/policy, and other behavior or policy tests.
