### Squash Commit
- Title: Stabilize workflow DSL laws and failure helper
- Summary: This round tightens the pure workflow DSL surface by adding `failWorkflow` as an explicit pure failure constructor and expands focused `watcher-core-test` coverage for `WorkflowM` effect ordering, failure short-circuiting, phase-changing `advance`, and planned pre/post commit projection parity for both moifold and DocsMigration specs. It does not move concrete transitions into the DSL, change package ownership, or touch event schemas, golden fixtures, codecs, daemon/runtime/transaction logic, adapters, or compatibility facades.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; both the round worktree `HEAD` and local base resolve to `77df640243199623f902edbb5e9c243304841703`, and `git rev-list --left-right --count HEAD...codex/workflow-facade-extraction` reports `0	0`. Remote freshness could not be checked because `origin` does not advertise `refs/heads/codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. `selection.md` declares `depends_on_round_ids: []`, `merge_after_item_ids: []`, and `parallel_group: null`; current controller metadata also has no pending merge rounds and marks round 028 merge-ready after approval.
- Pending dependencies: none.

### Follow-Up Notes
The reviewer approved the round after `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, and manual package-boundary inspection passed. The only implementation files in the approved diff are `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs` and `test/Main.hs`; `orchestrator/state.json` contains controller active-round/merge metadata and should be handled by the controller rather than squashed as implementation code unless that is the orchestrator convention for this round.
