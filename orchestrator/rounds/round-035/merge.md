### Squash Commit
- Title: Document workflow package extraction readiness
- Summary: Round 035 adds a source-backed package extraction readiness report for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, then links it from the framework README for discoverability. The report records import-graph evidence, Cabal dependency ownership, compatibility-facade mapping, validation commands, and remaining moifold-owned blockers without changing code, Cabal sections, package-boundary tests, publication state, or compatibility policy.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-035-next-framework-slice` and local `codex/workflow-facade-extraction` both resolve to `5229400`, with `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reporting `0 0`. `origin` does not advertise `codex/workflow-facade-extraction`, so freshness is confirmed against the controller's local base branch.
- Merge ordering satisfied: yes. `review.md` and `review-record.json` approve `item-035-package-readiness-report`; `depends_on_round_ids` and `merge_after_item_ids` are empty; `pending_merge_rounds` is empty; `last_completed_round` is `round-034`; and this round is the active merge-stage round.
- Pending dependencies: none. Direction `direction-011-package-readiness-report` only required the API-freeze direction to be complete or explicitly scoped, and round 034 is already recorded as complete on the local base branch.

### Follow-Up Notes
Squash merge is ready for the approved artifact-only round payload: the package extraction readiness report, the narrow README link, and the round artifacts. Keep package publishing, Cabal/package-boundary cleanup, compatibility-facade removal, roadmap edits, and controller state edits out of this round merge.
