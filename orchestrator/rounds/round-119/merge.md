### Squash Commit
- Title: Move Observe command off AppServerClient facade
- Summary: Round 119 performs the approved import-only migration for `src/CodexWatcher/Cli/Command/Observe.hs`, replacing its `CodexWatcher.AppServerClient` facade import with direct `CodexWatcher.Workflow.Agent.Codex.Transport` imports for `appServerInterpreterFromEndpoint` and `defaultAppServerClientOptions`. The reviewed diff preserves Observe command behavior, parser/output paths, execute-mode endpoint requirement, dry-run null interpreter fallback, and planner `turn/start` traffic, relying on the accepted round-118 observe coverage gate.

### Merge Readiness
- Base branch freshness: confirmed. The configured base branch is `codex/workflow-facade-extraction`, and it is an ancestor of the round branch `orchestrator/round-119-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, `pending_merge_rounds` is empty, and no pending merge round blocks this approved serial round.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is APPROVED. Remaining `CodexWatcher.AppServerClient` source users are out of scope for this round and still need their own selected cleanup gates. This merge readiness does not approve facade removal, public deprecation, Cabal exposure cleanup, package descriptor changes, milestone completion, or terminal roadmap completion.
