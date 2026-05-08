### Changes Made
- `docs/agentic-workflow-framework/implemented-api-freeze.md`: added the round-034 API freeze page naming the implemented `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` exposed modules, grouping their stable reusable surfaces, and explicitly listing moifold-owned lifecycle, runtime, healthcheck, repair, compatibility, and publication policy.
- `docs/agentic-workflow-framework/README.md`: updated the framework index from future-only design draft to implemented internal contract plus migration background, linking the API-freeze page and distinguishing implemented contract docs from the historical extraction plan.
- `docs/agentic-workflow-framework/workflow-spec.md`: rewrote the spec page around the current associated-type `WorkflowSpec`, `PlannedTransition`, `IndexedWorkflowSpec`, existential wrappers, `WorkflowSpecIndexedBridge`, implemented laws, and deferred richer domain/phase design.
- `docs/agentic-workflow-framework/monad-dsl.md`: aligned the DSL docs with the implemented pure `WorkflowM`, `Transition`, `emit`, `failWorkflow`, `advance`, `transitionFromPlan`, and transition accessor surface, including the no-`liftIO` and permission-validation boundaries.
- `docs/agentic-workflow-framework/event-log-and-transactions.md`: aligned codec, event-line decoding, replay, commit, execution metadata, permission, transaction, audit, and daemon projection docs with the implemented core modules while keeping concrete event-log IO and repair policy moifold-owned.
- `docs/agentic-workflow-framework/agent-turn-contract.md`: aligned the Codex adapter docs with typed ids, agent plans, retries, side-effect scopes, app-server protocol/client/interpreter/transport helpers, turn refs, and observation bridging.
- `docs/agentic-workflow-framework/extraction-plan.md`: marked the older plan as historical migration background and pointed readers to the implemented API freeze.
- `docs/correctness-model.md`: added a short navigation link from the correctness model to the implemented framework API freeze.

### Tests
- `git diff --check`: whitespace verification for tracked docs changes; additional `git diff --no-index --check /dev/null <new-file>` checks covered the new API-freeze page and implementation notes because they are intentionally left untracked.
- `git diff --cached --check`: skipped by guard because no files are staged.
- Name-only scope review: expected changes are limited to `docs/agentic-workflow-framework/`, optional `docs/correctness-model.md` navigation, pre-existing orchestrator artifacts, and this implementation notes file; no Haskell source, Cabal files, tests, roadmap files, production code, or state edits were introduced by this implementation.
- Direct docs/source comparison: checked that every exposed module from the three workflow sublibraries in `moifold.cabal` is named in the framework docs, that all plan-listed source module paths exist, and that key implemented API tokens from the core, Codex, and GitHub surfaces are documented.

### Notes
The worktree already had `orchestrator/state.json` modified and `orchestrator/rounds/round-034/{selection.md,plan.md}` untracked before these edits. I did not edit `orchestrator/state.json`, Haskell source, Cabal files, tests, roadmap files, production code, or compatibility fixtures.
