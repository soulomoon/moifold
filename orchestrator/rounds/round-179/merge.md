### Squash Commit
- Title: Round 179: Migrate CLI parser ID imports
- Summary: Migrates `src/CodexWatcher/Cli/Parser/Common.hs` off the `CodexWatcher.Core.Ids` compatibility facade and onto direct owner imports from `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. The implementation is import-only and preserves parser helpers, constructors, field accessors, parser behavior, option text, defaults, command rendering, dry-run text, child args, manifests, tests, docs, Cabal files, runtime compatibility files, and the public facade.

### Merge Readiness
- Base branch freshness: confirmed. `codex/workflow-facade-extraction` is an ancestor of `HEAD`; both currently resolve to `0605eb4` in the round worktree.
- Merge ordering satisfied: yes. `depends_on_round_ids` is empty and `merge_after_item_ids` is empty for `round-179`.
- Pending dependencies: none.

### Follow-Up Notes
Review decision is approved for `round-179-cli-parser-common-core-ids-split-import-migration`. Verification recorded in `review.md` passed `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, selected-file Core.Ids scans, direct-owner import scans, and broad remaining-user classification; cached diff check was skipped because no changes were staged.

This round is production import convergence only. It does not approve public facade deprecation or removal, Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, release approval, milestone completion, or terminal completion.
