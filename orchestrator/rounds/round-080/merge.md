### Squash Commit
- Title: Defer deprecation for selected public facades
- Summary: Records the approved artifact-only public deprecation readiness decision for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The round concludes that all four selected facades should remain available for now: preferred-import and migration-path evidence exists, but local facade imports, mixed moifold bridge behavior, bounded downstream evidence, and absent public deprecation/Cabal/Haddock alignment leave deprecation deferred.

### Merge Readiness
- Base branch freshness: confirmed locally. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `f47b8e41c14471b7483e5614795c40d3b74f5d7e`; `git log codex/workflow-facade-extraction..HEAD` and `git log HEAD..codex/workflow-facade-extraction` are both empty.
- Merge ordering satisfied: yes. `orchestrator/state.json` lists `round-080-public-deprecation-readiness-decision` at `stage: merge` with `merge_ready: true`, `pending_merge_rounds: []`, and `last_completed_round: round-079`; its declared predecessor item ids are rounds 075 through 079.
- Pending dependencies: none locally observable. The active round depends on `round-075`, `round-076`, `round-077`, `round-078`, and `round-079`, and local state records those predecessors as already completed before round 080 merge preparation.

### Follow-Up Notes
`review.md` and `review-record.json` both approve the round. The merger should squash only the round-local artifacts for round 080; no implementation code, tests, docs, Cabal/package descriptors, roadmap files, `orchestrator/state.json`, deprecation pragmas, exposed modules, runtime compatibility files, event schemas, healthcheck, repair, import migrations, public wording, or facade removals are part of this round. Future rounds should treat missing deprecation gates as blockers, not as approval to add public deprecation signals.
