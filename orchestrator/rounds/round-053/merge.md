### Squash Commit
- Title: Inventory runtime compatibility file surfaces
- Summary: Adds the evidence-only round 053 runtime compatibility-file inventory for `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR URL/state files, block state, repair state, runtime owner files, and compatibility snapshots. The approved artifact records source-backed producers, consumers, write timing, healthcheck and repair behavior, old-log and golden fixture assumptions, protecting tests, and explicit unknowns without changing production code, tests, schemas, roadmap state, runtime behavior, compatibility files, or removal/deprecation policy.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-053-compatibility-cleanup-slice` and `codex/workflow-facade-extraction` both point at `ee97b42` (`Mark import facade inventory complete`), with 0/0 committed divergence.
- Merge ordering satisfied: yes. Selection requires merge after `round-052-import-facade-inventory`; base contains round 052 payload commit `2179bb4` and roadmap update `ee97b42`.
- Pending dependencies: none. `depends_on_round_ids` is empty, and no active concurrent rounds are declared.

### Follow-Up Notes
The round is explicitly approved in `review.md` and `review-record.json`. Keep the squash merge artifact-only: round-local selection, plan, implementation notes, runtime compatibility-file inventory, review artifacts, and this merge note. This merge does not approve runtime compatibility-file renames, migrations, removals, schema changes, write-timing changes, policy changes, or roadmap completion.
