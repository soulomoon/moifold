### Squash Commit
- Title: Introduce indexed workflow spec API
- Summary: Adds `CodexWatcher.Workflow.Indexed.Spec` as a parallel indexed workflow contract in `agent-workflow-core`, exposes it from `moifold.cabal`, and covers indexed state/event/observation/effect-plan/replay types, typed planned transitions, and existential wrappers. The round also extends `watcher-core-test` coverage for core-boundary isolation, existential labels and projections, typed transition boundaries, and PR-review mergeability parity while leaving the compatibility facade, event schema, daemon paths, dry-run/action ordering, and golden fixtures unchanged.

### Merge Readiness
- Base branch freshness: confirmed locally; `codex/workflow-facade-extraction` and `orchestrator/round-004-indexed-spec-api` both point at `d0f71d2` (`Mark workflow roadmap round 003 complete`), and the round worktree applies directly on top of that local base.
- Merge ordering satisfied: yes; `item-004-indexed-spec-api` declares `Merge after: item-003-boundary-guards`, and the active roadmap records `item-003-boundary-guards` as done in `round-003`. `orchestrator/state.json` also records `last_completed_round` as `round-003` and no pending merge rounds.
- Pending dependencies: none; review decision is approved, state records `merge_ready: true`, and the review evidence records passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.

### Follow-Up Notes
Ready for squash merge. No merge-order, dependency, review, or local base-freshness blockers were found. The base branch has no upstream tracking ref in this worktree, so freshness was confirmed against the local base branch recorded in `orchestrator/state.json`.
