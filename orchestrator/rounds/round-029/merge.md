### Squash Commit
- Title: Port selected workflow transitions to pure DSL helpers
- Summary: Round 029 ports one DocsMigration draft-produced transition and one moifold issue-planning turn-completed projection through the pure `WorkflowDSL.advance` helper surface. The implementation keeps the ports narrow, preserves the existing event/state/effect behavior, and adds focused parity coverage for replay, permissions, phase/action validation, action ordering, and dry-run reporting.

### Merge Readiness
- Approved decision: approved in `review.md` and `review-record.json`.
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` returned success.
- Merge ordering satisfied: yes. `selection.md` declares no `depends_on_round_ids`, no `merge_after_item_ids`, and no `parallel_group`; `orchestrator/state.json` has `max_parallel_rounds: 1`, active `round-029`, stage `merge`, and `merge_ready: true`.
- Pending dependencies: none.
- Review validations: `cabal build all` passed; `cabal test watcher-core-test` passed, including both new DSL parity tests; `git diff --check` passed; `git diff --cached --check` passed with nothing staged; `git diff --name-status` showed the implementation diff limited to `src/CodexWatcher/Workflow/DocsMigration.hs`, `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`, and `test/Main.hs`, with `orchestrator/state.json` carrying controller metadata; forbidden-import scans over `agent-workflow-core/src` passed; worker-plan absence check passed.

### Follow-Up Notes
Squash only the reviewed round implementation and intended round artifacts. The review notes call out `orchestrator/state.json` as controller activation metadata, so confirm whether that metadata belongs in the squash before final integration. No worker fanout plan exists, and no roadmap, golden fixture, event schema, compatibility facade, daemon transaction, or interpreter behavior changes were part of this approved round.
