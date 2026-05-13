### Squash Commit
- Title: Migrate observe command spec to direct id owner imports
- Summary: Round 155 migrates only `test/ObserveCommandSpec.hs` away from the combined `CodexWatcher.Core.Ids` compatibility facade for its existing `RepoName`, `ThreadId`, `TurnId`, and `unThreadId` imports. The selected test now imports `RepoName` from `CodexWatcher.Workflow.GitHub.Ids` and agent ids from `CodexWatcher.Workflow.Agent.Ids`, while preserving the observe-command test bodies, helpers, and assertions. The reviewer approved the round after `cabal test watcher-core-test`, `cabal build all`, focused import scans, and diff hygiene checks passed.

### Merge Readiness
- Base branch freshness: confirmed against local base `codex/workflow-facade-extraction` at `dcd500d479ecc8f6f0eee19b4d56dff778135bd9`; the round branch `orchestrator/round-155-highest-value-cleanup-slice` has the same `HEAD` and carries the round as unstaged working-tree changes. `git ls-remote origin refs/heads/codex/workflow-facade-extraction` returned no remote ref, so no remote-tracking comparison was available.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `pending_merge_rounds: []`, `max_parallel_rounds: 1`, active `round-155`, stage `merge`, and `merge_ready: true`.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are both empty for `round-155`.

### Follow-Up Notes
This merge decision is limited to the approved import-convergence slice for `test/ObserveCommandSpec.hs`. It does not approve public facade deletion or deprecation, Cabal exposed-module cleanup, broader `CodexWatcher.Core.Ids` migration, runtime compatibility cleanup, milestone completion, terminal roadmap completion, release approval, or package publication.
