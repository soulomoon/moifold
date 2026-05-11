### Squash Commit
- Title: Move PR-review launch off AppServerClient facade
- Summary: Round 124 moves `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` off the public `CodexWatcher.AppServerClient` compatibility facade and onto the direct Codex app-server owner imports for the symbols it already uses. The approved diff is import-only in the PR-review launch path; behavior, request ids, launch-plan persistence, failure formatting, facade exposure, package descriptors, tests, docs, fixtures, runtime compatibility files, and `IssueFanout` remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. Current round HEAD, base branch `codex/workflow-facade-extraction`, and their merge-base are all `dc29e029607217c7d8dfd12a5a09c6f52c7dfe5f` before the uncommitted round changes.
- Merge ordering satisfied: yes. `orchestrator/rounds/round-124/selection.md` declares no `depends_on_round_ids`, no `merge_after_item_ids`, no parallel group, and the controller-visible state is serial for this selected round.
- Pending dependencies: none.

### Follow-Up Notes
This merge readiness is for the approved import-convergence slice only. It is not facade removal, facade deprecation, Cabal exposure cleanup, public API cleanup, runtime compatibility cleanup, `IssueFanout` migration, milestone completion, or release/publication approval.
