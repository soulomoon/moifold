### Squash Commit
- Title: Freeze workflow framework docs against implemented APIs
- Summary: Round 034 documents the implemented internal API freeze for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, then aligns the framework README, workflow spec, DSL, event-log/transaction, Codex adapter, extraction-plan, and correctness-model links with the current code-backed surfaces. The docs keep lifecycle policy, runtime ownership, healthcheck, repair, compatibility files, and publication/deprecation decisions owned by moifold.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-034-next-framework-slice` and local `codex/workflow-facade-extraction` both resolve to `e7921a0`, with `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reporting `0 0`. `origin` does not advertise `codex/workflow-facade-extraction`, so freshness is confirmed against the controller's local base branch.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve `item-034-api-freeze-docs`; `depends_on_round_ids` and `merge_after_item_ids` are empty; `pending_merge_rounds` is empty; `last_completed_round` is `round-033`; and this round is the active merge-stage round.
- Pending dependencies: none. Direction `direction-011-package-readiness-report` depends on this API-freeze direction being complete or explicitly scoped, so it should remain after this squash merge.

### Follow-Up Notes
Squash merge is ready for the approved docs-only round diff plus its expected round artifacts. Do not include package publishing, Cabal/package-boundary cleanup, compatibility-facade removal, roadmap edits, or controller state edits in this merge.
