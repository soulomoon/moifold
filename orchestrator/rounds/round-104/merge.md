### Squash Commit
- Title: Record EventLog and Permission bridge readiness
- Summary: Record the approved artifact-only readiness inventory for the mixed `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` compatibility facades. The round captures current live imports, package exposure, mixed export-list classification, per-importer ownership, later verification gates, and explicit non-goals before any import convergence, deprecation, Cabal exposure change, public API change, or facade removal.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of this round branch, and `origin/main` exists and is also an ancestor. No `origin/codex/workflow-facade-extraction` ref is available from the current remote heads, so freshness is confirmed against the local base branch and available `origin/main`.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `round-104` in merge stage with `merge_ready: true`; `depends_on_round_ids` and `merge_after_item_ids` are both empty. The previous completed round is `round-103`, whose Core.Ids blocker-readiness context is incorporated by this readiness-only slice.
- Pending dependencies: none.

### Follow-Up Notes
The review decision is `APPROVED` in both `review.md` and `review-record.json`. Keep the squash limited to round-local orchestrator artifacts plus controller bookkeeping; this merge is not approval for import migration, public deprecation or removal, Cabal exposure changes, package descriptor cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
