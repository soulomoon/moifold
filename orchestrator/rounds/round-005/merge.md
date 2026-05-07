### Squash Commit
- Title: Port DocsMigration to indexed workflow spec
- Summary: Round-005 ports `DocsMigrationSpec` as the first concrete DocsMigration proof over the indexed workflow API while keeping the existing compatibility facade intact. The implementation adds DocsMigration-owned indexed wrapper/index types, delegates indexed behavior to the current DocsMigration `WorkflowSpec` paths, and adds focused parity coverage for draft production, validation and blocked transitions, permissions, fixture codec replay, dry-run output, daemon execute output, audit labels, and effect/action ordering.

### Merge Readiness
- Base branch freshness: confirmed. The round worktree is on `orchestrator/round-005-indexed-docs-migration`; `HEAD`, the merge base, and local base branch `codex/workflow-facade-extraction` all resolve to `6e3b22e0da8cfb3b821b15cfb8eea4e19d817bc8`. No remote-tracking ref exists for `origin/codex/workflow-facade-extraction`, so the local configured base is the freshness authority for this round.
- Merge ordering satisfied: yes. `selection.md`, `state.json`, and the active roadmap agree on `item-005-indexed-docs-migration`; its `Merge after:` item is `item-004-indexed-spec-api`, which the active roadmap records as `[done]` with completion in round-004. `state.json` also records `last_completed_round` as `round-004` and has no `pending_merge_rounds`.
- Pending dependencies: none. Review is explicitly approved, baseline checks passed, task-specific indexed DocsMigration parity checks passed, and the item-004/round-004 dependency is already complete.

### Follow-Up Notes
After squash merge, the controller can advance to update-roadmap for `item-005-indexed-docs-migration`. The next roadmap item, `item-006-indexed-pr-review-slice`, depends on this DocsMigration proof, so it should wait until this round is merged and the roadmap marks item-005 done.
