### Squash Commit
- Title: Move app Main to direct GitHub ids import
- Summary: Moves the `app/Main.hs` `RepoName (unRepoName)` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.GitHub.Ids`, preserving `healthcheckOptionsFromCli` behavior. The round also adds the compile-proven executable-only `agent-workflow-github >=0.1 && <0.2` dependency required for the `moifold` executable to import the direct owner package.

### Merge Readiness
- Base branch freshness: confirmed. After `git fetch origin main`, `origin/main` is an ancestor of `orchestrator/round-101-highest-value-cleanup-slice`, and the round branch is based on the current local integration head `codex/workflow-facade-extraction` at `af72a8c`.
- Merge ordering satisfied: yes. Round 101 is the active serial round, `max_parallel_rounds` is effectively one for this selection, prior direction-011 rounds 098, 099, and 100 are already represented in the branch history, and this round declares no `merge_after_item_ids`.
- Pending dependencies: none. `depends_on_round_ids` is empty, `merge_after_item_ids` is empty, and `review.md` / `review-record.json` approve the round.

### Follow-Up Notes
The compatibility facade `CodexWatcher.Core.Ids` remains exposed and unchanged. This merge prepares only the app `RepoName` import convergence slice plus the executable dependency proven necessary by `cabal build all`; it does not approve facade deprecation, Cabal exposure removal, release, milestone completion, or terminal cleanup completion. Verification recorded by the approved review includes `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
