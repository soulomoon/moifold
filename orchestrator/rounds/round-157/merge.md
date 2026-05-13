### Squash Commit
- Title: Migrate RunnerGuardSpec to direct owner id imports
- Summary: This round migrates `test/RunnerGuardSpec.hs` off the `CodexWatcher.Core.Ids` compatibility facade by importing `RepoName` from `CodexWatcher.Workflow.GitHub.Ids` and request/thread/turn identifiers from `CodexWatcher.Workflow.Agent.Ids`. The implementation preserves the existing runner-guard test bodies and assertions, leaves public compatibility facades exposed, and does not touch production code, package descriptors, docs, runtime compatibility files, deprecation policy, or removal gates.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` returned success and `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` reported `0 0`. The round changes are currently unstaged worktree changes on top of that base.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `round-157` at stage `merge` on branch `orchestrator/round-157-highest-value-cleanup-slice`, `merge_ready: true`, `pending_merge_rounds: []`, `roadmap_update: null`, and no round resume error.
- Pending dependencies: none. `depends_on_round_ids` and `merge_after_item_ids` are both empty, and `parallel_group` is `null`.

### Follow-Up Notes
The round is approved in `orchestrator/rounds/round-157/review.md` and `orchestrator/rounds/round-157/review-record.json`. Reviewer evidence records passing `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, focused import scans, and a zero-context diff showing only the intended import replacement in `test/RunnerGuardSpec.hs`.

This merge decision does not approve public facade deprecation or removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal roadmap completion, release approval, or package publication.
