### Squash Commit
- Title: Classify selected facade behavior ownership
- Summary: Records evidence-backed behavior-owner classifications for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The round distinguishes pure reexport convenience facades from mixed moifold behavior bridge surfaces, preserves the project-contract rule that compatibility facades remain available until later removal-readiness proof, and makes no production, package, docs, roadmap, compatibility-file, event-schema, healthcheck, repair, deprecation, migration, or removal changes.

### Merge Readiness
- Base branch freshness: confirmed against the declared local base. `orchestrator/state.json` names base branch `codex/workflow-facade-extraction`; the local base branch and round branch `orchestrator/round-076-behavior-owner-classification` both resolve to `9ba2ce8`, and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0	0`. A same-named remote ref could not be fetched from `origin`, so no remote-base update was available to compare.
- Merge ordering satisfied: yes. `review.md` approves the round, `review-record.json` records decision `approved`, controller state marks `merge_ready` true, `pending_merge_rounds` is empty, and the required round-075 import-scan evidence is already integrated as an ancestor of `HEAD`.
- Pending dependencies: none. Declared dependencies are `depends_on_round_ids: ["round-075"]` and `merge_after_item_ids: ["round-075-import-scan-refresh"]`; state records `last_completed_round` as `round-075`, and round-075 evidence is present in branch history.

### Follow-Up Notes
This is an artifact-only evidence round. The reviewer intentionally did not require `cabal build all` or `cabal test watcher-core-test` because the implementation stayed inside round-local orchestrator artifacts.

Later rounds must treat this classification as descriptive evidence only. It does not authorize import migration, deprecation, Cabal exposure changes, facade removal, event-schema changes, healthcheck or repair changes, release, or publication.
