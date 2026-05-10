### Squash Commit
- Title: Extract boundary policy tests
- Summary: Splits the package-boundary scanner helpers and boundary-policy assertions out of `test/Main.hs` into focused watcher-core test modules, keeps the existing facade extraction aggregation path reaching the extracted checks, and adds only the required `watcher-core-test` `other-modules` metadata for `BoundaryPolicySpec` and `TestSupport.SourceScan`. The reviewed change preserves package-boundary, Cabal dependency, facade policy, adapter reexport, runtime-render parity, and IssueImplement lifecycle assertions without production, docs, fixture, runtime compatibility, public deprecation, removal, roadmap, or state changes from the implementation scope.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction`, `orchestrator/round-084-highest-value-cleanup-slice`, and their merge-base all resolve to `a0b0f1b1ebfb39d73d3d3f96caf3a1ab25551f56`.
- Merge ordering satisfied: yes. `review.md` records `APPROVED`, `review-record.json` records `"decision": "approved"`, controller state records `"merge_ready": true`, and both `depends_on_round_ids` and `merge_after_item_ids` are empty.
- Pending dependencies: none.

### Follow-Up Notes
This round is ready for a squash merge into local base branch `codex/workflow-facade-extraction`. Keep the squash message focused on extracting boundary policy tests; this merge does not approve production import convergence, public deprecation, facade removal, Cabal exposure removal, runtime compatibility-file removal, or roadmap-update work.
