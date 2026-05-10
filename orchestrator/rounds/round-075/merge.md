### Squash Commit
- Title: Refresh selected facade import evidence
- Summary: Refreshes the scan-backed evidence base for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The round records current local import counts, Cabal and documentation references, preferred replacement modules, protecting checks, downstream inventory limits, and remaining blocker classes without changing production code, package descriptors, docs, roadmap files, runtime compatibility files, event schemas, healthcheck behavior, repair behavior, deprecation pragmas, import migrations, or facade exposure.

### Merge Readiness
- Base branch freshness: confirmed. Controller state names base branch `codex/workflow-facade-extraction`; the local base branch and round branch `orchestrator/round-075-current-facade-evidence` both resolve to `7750312ed71c3f15e7505ebdfc4598316f3a93e7`, and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0	0`.
- Merge ordering satisfied: yes. Controller-visible state has `max_parallel_rounds` set to 1, active round `round-075`, no `pending_merge_rounds`, and selection/state declare no `depends_on_round_ids`, no `merge_after_item_ids`, and no `parallel_group`.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approved the artifact-only round and `review-record.json` records decision `approved`; controller state marks `merge_ready` true. `cabal build all` and `cabal test watcher-core-test` were intentionally not run because the round changed only round-local orchestrator evidence artifacts under the plan's artifact-only verification rule.

Later rounds must continue treating the prior `2026-05-09-01-compatibility-surface-cleanup` terminal hold as non-approval for deprecation, migration, Cabal exposure, or removal. External downstream repositories, published package tarballs, Hackage metadata, GitHub code search, deployed operator environments, and generated source distributions remain outside the inspected evidence scope.
