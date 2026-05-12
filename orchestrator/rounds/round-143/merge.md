### Squash Commit
- Title: Migrate AutomaticLoopRunnerSpec app-server types to direct owners
- Summary: This round moves only `test/AutomaticLoopRunnerSpec.hs` off the `CodexWatcher.AppServerClient` compatibility facade by importing `AppServerClientFailure (..)` from `CodexWatcher.Workflow.Agent.Codex.Client` and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`. The existing automatic-loop runner test bodies, helpers, fixtures, assertions, package metadata, public facade exposure, and production code remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; `orchestrator/round-143-highest-value-cleanup-slice`, `HEAD`, `codex/workflow-facade-extraction`, and their merge base all resolve to `785e92fefe6f82f88530533a20986f4aaf20aa93`.
- Merge ordering satisfied: yes; `orchestrator/state.json` records `depends_on_round_ids: []`, `merge_after_item_ids: []`, `parallel_group: null`, `merge_ready: true`, and no `pending_merge_rounds`.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `orchestrator/rounds/round-143/review.md` and `review-record.json`. The recorded validation passed: focused import scans, broad facade scan, `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.

This is import-convergence evidence only. It does not approve public facade deprecation or removal, Cabal exposure cleanup, package descriptor cleanup, milestone completion, release approval, or terminal roadmap completion.
