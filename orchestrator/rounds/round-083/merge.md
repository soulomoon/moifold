### Squash Commit
- Title: Record round-083 cleanup inventory evidence
- Summary: Adds the round-local cleanup inventory evidence for the highest-value cleanup roadmap, covering compatibility facades, runtime compatibility files, test topology and helper clusters, large behavior modules, fixture gaps, policy references, downstream/operator scope, and follow-up gates. The reviewed change is artifact-only and does not alter production code, tests, Cabal files, docs, fixtures, runtime compatibility files, public APIs, or behavior surfaces.

### Merge Readiness
- Base branch freshness: confirmed. Local `codex/workflow-facade-extraction`, `orchestrator/round-083-highest-value-cleanup-slice`, and their merge-base all resolve to `2f4e7b519a6410f2664d7e86c3f04f9d85a4481f`.
- Merge ordering satisfied: yes. `review.md` records `APPROVED`, `review-record.json` records `"decision": "approved"`, controller state records `"merge_ready": true`, and both `depends_on_round_ids` and `merge_after_item_ids` are empty.
- Pending dependencies: none.

### Follow-Up Notes
This round is ready for a squash merge into local base branch `codex/workflow-facade-extraction`. Keep the squash message focused on the inventory evidence; this merge does not approve deprecation, migration, Cabal exposure changes, facade removal, runtime compatibility-file removal, or roadmap-update work.
