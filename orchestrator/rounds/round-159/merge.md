### Squash Commit
- Title: Migrate RunnerGuard CLI command off Core.Ids
- Summary: This round migrates the single selected production module, `src/CodexWatcher/Cli/Command/RunnerGuard.hs`, away from the combined `CodexWatcher.Core.Ids` compatibility facade by importing `RepoName` from `CodexWatcher.Workflow.GitHub.Ids` and `ThreadId`/`TurnId` from `CodexWatcher.Workflow.Agent.Ids`. The source diff is import-only: runner-guard command rendering, repair-thread reporting, function bodies, public facade exposure, package descriptors, tests, docs, and compatibility policy remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; current branch `orchestrator/round-159-highest-value-cleanup-slice` and base branch `codex/workflow-facade-extraction` both resolve to `ec5aefdcebd6f12d04f095597a8f3549c5e29419`, `codex/workflow-facade-extraction` is an ancestor of `HEAD`, and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reports `0 0`.
- Merge ordering satisfied: yes; `depends_on_round_ids` is `[]`, `merge_after_item_ids` is `[]`, `parallel_group` is `null`, `pending_merge_rounds` is empty, and the active round record has `merge_ready: true`.
- Pending dependencies: none.

### Follow-Up Notes
Review approved the round in `orchestrator/rounds/round-159/review.md`, and `orchestrator/rounds/round-159/review-record.json` records `decision: approved`. The recorded evidence passed `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, focused import scans, scope checks, and facade availability checks. This merge note does not claim deprecation, Cabal exposure removal, facade deletion, milestone completion, terminal completion, release approval, or public compatibility removal; broader `CodexWatcher.Core.Ids` compatibility usage remains for later reviewed gates.
