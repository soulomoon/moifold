### Squash Commit
- Title: Move AutomaticLoop runner off AppServerClient facade
- Summary: This round moves `src/CodexWatcher/AutomaticLoop/Runner.hs` from the public `CodexWatcher.AppServerClient` compatibility facade to the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport` for exactly `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`. The change is import-only and preserves runner behavior, dry-run safety, execute-mode endpoint-backed interpreter construction, retry/fatal classification, fanout, handoff, protocol, runtime compatibility, package metadata, tests, docs, and public facade exposure.

### Merge Readiness
- Base branch freshness: confirmed locally against `codex/workflow-facade-extraction` at `4d319b3e19ab628880c1b2d8028fa20f8b6d8591`; the round branch starts from the same commit. `origin` does not advertise `codex/workflow-facade-extraction`, so there is no remote base ref to compare in this worktree.
- Merge ordering satisfied: yes. `depends_on_round_ids` and `merge_after_item_ids` are empty, `parallel_group` is null, `pending_merge_rounds` is empty, and `max_parallel_rounds` is 1.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved in `orchestrator/rounds/round-122/review.md` and `review-record.json`. The recorded validation passed the focused `AutomaticLoopRunnerSpec.automaticLoopRunnerTests` REPL gate, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, import scans, forbidden-path guards, no-worker-plan guard, and JSON checks. The only production code diff is the planned import replacement in `src/CodexWatcher/AutomaticLoop/Runner.hs`; control-plane changes are limited to the active round state and round artifacts.
