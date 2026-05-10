### Squash Commit
- Title: Extract facade import policy tests
- Summary: Split the selected public-facade import policy checks out of `test/Main.hs` into `test/FacadeImportPolicySpec.hs`, keep `workflowFacadeExtractionTests` as the reachable watcher-core aggregator, and add the focused test module to the `watcher-core-test` Cabal stanza without changing production code, public facade exposure, docs, fixtures, roadmap files, or runtime compatibility files.

### Merge Readiness
- Base branch freshness: confirmed for local base `codex/workflow-facade-extraction`; round HEAD and local base both resolve to `bfcf24d`. No `origin/codex/workflow-facade-extraction` head is present, so the remote freshness check is not applicable for this local-only base.
- Merge ordering satisfied: yes. `orchestrator/state.json` has `merge_ready: true`, `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `pending_merge_rounds: []` for `round-085`.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `orchestrator/rounds/round-085/review.md` and `orchestrator/rounds/round-085/review-record.json`. Verification recorded for this round includes `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. Ready for squash merge into local base `codex/workflow-facade-extraction`; merger did not merge.
