### Squash Commit
- Title: Harden workflow core boundary guards
- Summary: Strengthens the workflow-core boundary tests so `agent-workflow-core` is checked recursively for forbidden moifold lifecycle imports, concrete watcher/runtime/app-server/GitHub tokens, and disallowed package dependencies. The round preserves production source, adapter packages, golden fixtures, event schema, daemon result, dry-run, action-ordering, and facade representation behavior while adding the guard coverage needed before the indexed WorkflowSpec API work.

### Merge Readiness
- Base branch freshness: confirmed. The round branch `orchestrator/round-003-boundary-guards` is at local base branch `codex/workflow-facade-extraction` commit `8fc6416`, and `codex/workflow-facade-extraction` is an ancestor of `HEAD`. `origin` does not advertise a `codex/workflow-facade-extraction` head, so freshness is confirmed against the repo-local base.
- Merge ordering satisfied: yes. `item-003-boundary-guards` declares `Merge after: item-002-facade-laws`; the active roadmap marks `item-002-facade-laws` done with completion in `round-002`, and `orchestrator/state.json` records `last_completed_round` as `round-002`. `pending_merge_rounds` is empty.
- Pending dependencies: none.

### Follow-Up Notes
Review is approved in `review.md` and `review-record.json`. Review evidence records passing `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, `git diff --cached --check`, and focused no-output boundary guard commands. After this squash merge, the next dependent roadmap item is `item-004-indexed-spec-api`.
