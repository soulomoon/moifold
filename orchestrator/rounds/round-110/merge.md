### Squash Commit
- Title: Record RunnerGuard AppServerClient gate evidence
- Summary: Records artifact-only readiness evidence for the remaining `src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` importer. The round maps each RunnerGuard facade symbol to its direct owner module, inventories current RunnerGuard and generic app-server coverage, and records a gate matrix concluding that a later import-only split is not ready until focused RunnerGuard active app-server turn inspection coverage lands.

### Merge Readiness
- Base branch freshness: confirmed; local `codex/workflow-facade-extraction` and `HEAD` both resolve to `39984d1c72d42a9bb3b223e59ba3462c1e1b2d9f`, and the base branch is an ancestor of the round branch.
- Merge ordering satisfied: yes; `orchestrator/state.json` is at `stage: "merge"` for `round-110`, `merge_ready` is `true`, `pending_merge_rounds` is empty, `depends_on_round_ids` is empty, and `merge_after_item_ids` is empty.
- Pending dependencies: none.

### Follow-Up Notes
`review.md` is explicitly `APPROVED`, `review-record.json` has decision `approved`, and `worker-plan.json` is absent. Changed-path scope is limited to controller-owned `orchestrator/state.json` plus round-local artifacts under `orchestrator/rounds/round-110/`; no production, test, package, docs, reusable package, public API, fixture, or behavior surface changed.

This round does not approve import migration, public deprecation, Cabal exposure removal, facade removal, behavior change, release/publication, milestone completion, or terminal completion. The next implementation blocker named by the evidence is the focused `RunnerGuard active app-server turn inspection` test slice.
