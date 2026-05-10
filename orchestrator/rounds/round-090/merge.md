### Squash Commit
- Title: Add planner/planning compatibility fixtures
- Summary: This round adds focused fixture evidence for the distinct issue-planning `planner-state.json` and `planning-state.json` compatibility surfaces. The reviewed diff adds the five selected golden fixtures, wires `RuntimeCompatibilityFixtureSpec` into `watcher-core-test`, and asserts the current compatibility projection, direct `RecordPlanningGraph` writer, and healthcheck reader boundary without approving runtime behavior changes, compatibility-file rename/deletion, deprecation, or broader cleanup.

### Merge Readiness
- Base branch freshness: confirmed. `orchestrator/round-090-highest-value-cleanup-slice` is based on local `codex/workflow-facade-extraction` at `acf7f66c20258ca99f7e2f3e0b019c5ec0906f3a`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0`. `origin` does not advertise `codex/workflow-facade-extraction`, so freshness is confirmed against the configured local base branch.
- Merge ordering satisfied: yes. State is in `merge` for active `round-090`, `review.md` and `review-record.json` approve the selected extraction `round-090-planner-planning-compatibility-fixtures`, `merge_ready` is `true`, and `pending_merge_rounds` is empty.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are both empty for this active round.

### Follow-Up Notes
Squash only the approved round slice and keep the commit scoped to the fixture/test evidence plus round artifacts. The review explicitly does not approve planner/planning compatibility migration, rename, deletion, healthcheck reader changes, repair behavior changes, broader fixture batches, facade removal, Cabal exposure removal, release approval, or terminal roadmap completion.
