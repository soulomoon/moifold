### Squash Commit
- Title: docs(workflow): define package compatibility deprecation policy
- Summary: Adds the artifact-only compatibility and deprecation policy for the future `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates. The round documents preferred imports, classifies moifold-owned compatibility facades, preserves wrapper and compatibility-file availability, and records explicit gates before any deprecation pragma, import migration, wrapper removal, descriptor change, release note, package artifact, or publication claim can be approved.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction` at `ce1ec8a` (`Mark release metadata policy round complete`). The round branch and local base branch currently point to the same base commit before the working-tree diff, and `codex/workflow-facade-extraction...HEAD` is `0 0`. `origin` does not advertise a `codex/workflow-facade-extraction` ref, so there is no remote base ref to compare.
- Merge ordering satisfied: yes. `review.md` explicitly approves `round-038`; `review-record.json` records `"decision": "approved"`; `depends_on_round_ids` and `merge_after_item_ids` are empty; `pending_merge_rounds` is empty; the active roadmap lane is serial with only `round-038` active.
- Pending dependencies: none.

### Follow-Up Notes
The approved diff is documentation/artifact-only: the new compatibility policy, the README index link, round artifacts, and controller-owned active-round bookkeeping in `orchestrator/state.json`. Do not treat this merge as approval for package upload, source-distribution generation, descriptor migration, deprecation pragmas, import migration, compatibility facade removal, compatibility-file migration, event schema changes, or release-note claims.
