### Squash Commit
- Title: Hold EventLog and Permission facade migration pending split evidence
- Summary: Records the approved artifact-only decision for `round-079-eventlog-permission-readiness-hold`: both `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` remain held because they still carry concrete moifold bridge behavior, public compatibility exposure, and protecting parity/replay/permission evidence that must be split or reviewed before import migration, deprecation, Cabal exposure changes, or removal.

### Merge Readiness
- Base branch freshness: confirmed. Local `orchestrator/round-079-eventlog-permission-readiness` and configured base `codex/workflow-facade-extraction` both resolve to `a0023d8`, and the base is an ancestor of `HEAD`.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `stage: merge`, `merge_ready: true`, no `pending_merge_rounds`, `last_completed_round: round-078`, and this round declares merge-after items for rounds 075 through 078.
- Pending dependencies: none locally observable. The declared dependencies `round-075`, `round-076`, `round-077`, and `round-078` are satisfied by the recorded `last_completed_round: round-078` serial state, and the review artifacts explicitly approve this round.

### Follow-Up Notes
The merge should remain artifact-only. Do not treat this hold as approval to remove, deprecate, migrate imports away from, or change Cabal exposure for either facade. Future work needs a separate reviewed split/migration round with old-log/golden replay evidence for EventLog and permission/phase-validation parity plus public API exposure evidence for Permission.
