### Squash Commit
- Title: Document release metadata policy for workflow packages
- Summary: Adds the source-backed release metadata policy for the future `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, covering required descriptor metadata, package-specific wording constraints, changelog and release-note gates, metadata truth rules, and descriptor-time checks. Links the new policy from the framework documentation without changing Cabal descriptors, source layout, source code, tests, changelogs, release notes, package artifacts, upload state, or publication approval.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD...codex/workflow-facade-extraction` is `0 0` after fetching `origin`. No `origin/codex/workflow-facade-extraction` or `origin/orchestrator/round-037-external-package-slice` ref exists for an additional remote comparison.
- Merge ordering satisfied: yes. `round-037` has no `depends_on_round_ids`, no `merge_after_item_ids`, no `parallel_group`, and `pending_merge_rounds` is empty; `round-036` is recorded as the last completed round.
- Pending dependencies: none.

### Follow-Up Notes
The approved round is merge-ready as an artifact-only policy update. `orchestrator/state.json` contains controller bookkeeping for the active merge stage and was not edited during merge preparation.
