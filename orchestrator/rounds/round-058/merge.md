### Squash Commit
- Title: Record follow-up cleanup discovery
- Summary: Adds an evidence-only follow-up discovery report for the
  compatibility-surface cleanup family. The report summarizes source-backed
  import-facade and runtime compatibility-file candidates, preserves current
  `keep`/`defer` classifications, records blockers and missing evidence, and
  hands candidate placement to a later roadmap-update round without approving
  migration, removal, publication, or roadmap revision changes.

### Merge Readiness
- Base branch freshness: confirmed. `HEAD`,
  `codex/workflow-facade-extraction`, and their merge base all resolve to
  `fde75a354c08ea532443aa628ee81992126785e0` before the staged round payload.
- Merge ordering satisfied: yes. `round-058` has no
  `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and
  the controller state records `last_completed_round` as `round-057` with no
  pending merge rounds.
- Pending dependencies: none.
- Review status: approved. `orchestrator/rounds/round-058/review-record.json`
  records `decision: approved`, and `review.md` approves the artifact-only
  discovery result after focused readback, import/runtime evidence scans,
  boundary checks, whitespace checks, and banned-claim checks.

### Follow-Up Notes
This merge is artifact-only. It adds round-local discovery, implementation,
review, and merge artifacts for `round-058`; it does not change source, tests,
fixtures, scripts, docs policy, project contract, Cabal descriptors, runtime
compatibility files, import surfaces, roadmap files, deprecation state,
publication state, migration state, or removal approval state. The candidate
list is ready for squash merge as input to the later roadmap expansion role.
