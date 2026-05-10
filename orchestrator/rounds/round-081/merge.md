### Squash Commit
- Title: Defer Cabal exposure removal for selected public facades
- Summary: Records the approved artifact-only Cabal exposure decision for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. The round keeps all four selected facades exposed in `moifold.cabal`: replacement modules and migration-path evidence exist, but remaining local imports, mixed moifold bridge ownership, bounded downstream evidence, absent public deprecation/removal alignment, and focused behavior-validation gaps make exposed-module removal deferred rather than approved.

### Merge Readiness
- Base branch freshness: confirmed locally. `HEAD`, `codex/workflow-facade-extraction`, and their merge-base are all `06e6478e007daa5f6456d49d5c52032bd93fdaa2`; `git log codex/workflow-facade-extraction..HEAD` and `git log HEAD..codex/workflow-facade-extraction` are both empty.
- Merge ordering satisfied: yes. `orchestrator/state.json` lists `round-081-cabal-exposure-decision` at `stage: merge` with `merge_ready: true`, `pending_merge_rounds: []`, and `last_completed_round: round-080`; its declared predecessor item ids are rounds 075 through 080.
- Pending dependencies: none locally observable. The active round depends on `round-075`, `round-076`, `round-077`, `round-078`, `round-079`, and `round-080`, and local state records those predecessors as completed before round 081 merge preparation.

### Follow-Up Notes
`review.md` approves the round and `review-record.json` records `decision: approved`. The merger should squash only the round-local artifacts for round 081; no implementation code, tests, docs, Cabal/package descriptors, roadmap files, `orchestrator/state.json`, exposed-module removals, public API changes, runtime compatibility files, event schemas, healthcheck, repair, import migrations, or facade removals are part of this round. Future Cabal exposure work should carry forward the explicit `defer` decisions and treat missing downstream, behavior, docs/Haddock, package-boundary, deprecation-readiness, or reviewer evidence as blockers rather than removal approval.
