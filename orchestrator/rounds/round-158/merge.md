### Squash Commit
- Title: Migrate observe parser Core.Ids imports to direct owners
- Summary: Round 158 migrates only `src/CodexWatcher/Cli/Parser/Observe.hs` from the combined `CodexWatcher.Core.Ids` compatibility facade to direct owner imports: `CommitSha` and `PrNumber` from `CodexWatcher.Workflow.GitHub.Ids`, and `TurnId` from `CodexWatcher.Workflow.Agent.Ids`. The parser body, observe CLI option surface, package descriptors, public compatibility facades, docs, runtime compatibility files, and broader `Core.Ids` migration scope remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed; local `HEAD` and `codex/workflow-facade-extraction` both resolve to `bffee4b7facc23faa27f0278aa8b32b9279880d1`, and the base is an ancestor of the round branch.
- Merge ordering satisfied: yes; `state.json` shows round `round-158` at stage `merge`, `merge_ready=true`, `pending_merge_rounds=[]`, and no active roadmap update.
- Pending dependencies: none; `depends_on_round_ids=[]`, `merge_after_item_ids=[]`, `parallel_group=null`, and `resume_error=null`.

### Follow-Up Notes
Reviewer approval is recorded in `orchestrator/rounds/round-158/review.md` and `review-record.json`. Required validation passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, focused import scans, and production scope checks. This merge decision does not approve public facade deprecation or removal, Cabal exposure cleanup, runtime compatibility cleanup, milestone completion, terminal completion, or release approval.
