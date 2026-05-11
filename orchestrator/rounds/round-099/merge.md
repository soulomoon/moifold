### Squash Commit
- Title: Move Workflow.Execution to direct agent ids import
- Summary: Round 099 moves the agent-id-only `src/CodexWatcher/Workflow/Execution.hs` `RequestId` import from the combined `CodexWatcher.Core.Ids` compatibility facade to the direct owner module `CodexWatcher.Workflow.Agent.Ids`. Workflow execution behavior, request-id threading, dry-run conversion, action partitioning, checked execution, package descriptors, and public compatibility facade exposure remain unchanged.

### Merge Readiness
- Base branch freshness: confirmed. `origin/main` was refreshed, and local `codex/workflow-facade-extraction`, round branch `HEAD`, and their merge base are all `1121d9441965ed3c10ae4717d30c40594f732d67`.
- Merge ordering satisfied: yes. `state.json` records `last_completed_round` as `round-098`, this round has no `depends_on_round_ids`, no `merge_after_item_ids`, `pending_merge_rounds` is empty, and the active state is serial with `max_parallel_rounds: 1`.
- Pending dependencies: none.

### Follow-Up Notes
Reviewer approval is recorded in `review.md` and `review-record.json`. The reviewed verification set passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`. Squash merge should include the single `Workflow.Execution` import replacement plus round-099 artifacts and controller state only; no package descriptor, facade exposure, roadmap, constructor, parser, renderer, command-output, dry-run, action-order, runtime compatibility, healthcheck, repair, replay, or restart behavior changes are part of this round.
