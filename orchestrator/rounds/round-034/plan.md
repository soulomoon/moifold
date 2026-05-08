### Goal

Freeze the framework documentation against the implemented internal API surfaces for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, while clearly separating the stable reusable framework contract from moifold-owned issue/PR lifecycle policy, daemon ownership, compatibility files, repair, healthcheck, and runtime interpretation.

### Approach

Keep this round sequential and docs-only. The selected item is one narrative/API-contract surface under `docs/agentic-workflow-framework/`, and the active controller state has no concurrent batch; worker fan-out is not justified and no `worker-plan.json` should be written.

Use `orchestrator/project-contract.md` as the stable source for repo-wide invariants instead of restating every compatibility rule. Treat the source modules and `moifold.cabal` exposed-module lists as evidence for what is implemented today. The docs should be thesis-first: the reusable contract is a typed workflow protocol around replay, observations, effect plans, permissions, transactions, adapters, and interpreter boundaries. Avoid marketing copy, package-publication language, package-readiness checklists, Cabal cleanup, import-graph reports, compatibility-facade removal plans, or direction-011 readiness-report scope.

### Steps

1. Inspect the implemented surface before editing docs:
   - `moifold.cabal` exposed modules for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`;
   - `agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs`, `Indexed/Spec.hs`, `DSL.hs`, `Codec.hs`, `EventLog/Core.hs`, `EventLog/Commit/Core.hs`, `Execution/Core.hs`, `Permission/Core.hs`, `Transaction/Core.hs`, and `Daemon/Core.hs`;
   - `agent-workflow-codex/src/CodexWatcher/Workflow/Agent*.hs`, `Workflow/Agent/Codex*.hs`, `Workflow/Observation/Agent.hs`, and `CodexWatcher/AppServerProtocol.hs`;
   - `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/{Ids,Remote,Command}.hs`;
   - representative assertions in `test/Main.hs`, `test/AppServerSpec.hs`, and `test/GhGitSpec.hs` that prove the contract and boundary scans.
2. Add or update one thesis-first contract page under `docs/agentic-workflow-framework/` that records the implemented framework API freeze. It should name the current exposed modules and group them by responsibility:
   - core spec and indexed bridge;
   - pure DSL;
   - codec, replay, event commit, permission, execution, transaction, audit, and daemon projection contracts;
   - Codex adapter plans, typed ids, protocol/client/interpreter/transport helpers, turn references, retries, and agent observations;
   - GitHub adapter ids, remote parsers/classifiers, and pure command specs.
3. In the same contract page, explicitly record moifold-owned surfaces that are not part of the reusable framework contract: concrete `WatcherEvent` and `SomeWatcherState`, Aeson event codecs and golden replay policy, issue/PR lifecycle decisions, prompt/schema policy, compatibility snapshots and file names, filesystem writes, process execution, PID/lease/runtime ownership, repair, healthcheck, concrete daemon loops, and publication/deprecation policy.
4. Update `docs/agentic-workflow-framework/README.md` so it no longer reads as only a future design draft. Keep the thesis prominent, link to the new implemented-contract/API-freeze page, and make the document index distinguish implemented contract pages from older design or migration-background pages. Do not turn it into a feature list.
5. Update `docs/agentic-workflow-framework/workflow-spec.md` to align with the actual implemented API:
   - document `WorkflowSpec` as the current associated-type contract with `WorkflowState`, `WorkflowEvent`, `WorkflowObservation`, `WorkflowObservedTick`, `WorkflowEffect`, `WorkflowEffectPlan`, replay/error types, labels, validation, terminal checks, and `PlannedTransition`;
   - document `IndexedWorkflowSpec`, existential wrappers, and `WorkflowSpecIndexedBridge` as the current indexed compatibility surface;
   - clearly label richer domain/phase shapes that remain design direction rather than implemented public contract.
6. Update `docs/agentic-workflow-framework/monad-dsl.md` to describe the implemented pure DSL: `WorkflowM`, `Transition`, `emit`, `failWorkflow`, `advance`, `transitionFromPlan`, and pre/post commit accessors. Keep the no-`liftIO` guarantee and note that permission validation is performed by the workflow spec/transaction path, not by arbitrary IO in the DSL.
7. Update `docs/agentic-workflow-framework/event-log-and-transactions.md` to reflect the implemented core contracts:
   - `WorkflowCodecContract`, stable type labels, schema versions, metadata labels, encoded type-label validation, and round-trip checks;
   - replay summaries/failures, fixture contracts, and transition failure formatting;
   - event commit helpers that encode once and append through a committer;
   - generic execution metadata for capability, commit order, and idempotency;
   - observed dry-run/execute transaction hooks, detailed failure stages, audit output, and daemon projection types.
   Keep filesystem event-log IO, concrete Aeson decoding, old-log replay policy, compatibility writes, and execute ownership in moifold.
8. Update `docs/agentic-workflow-framework/agent-turn-contract.md` to match the implemented Codex adapter boundary. Document typed role ids, `AgentThreadPlan`, `AgentTurnPlan`, `AgentThreadStart`, `AgentTurnStart`, `TurnRef`, `agentTurnStartRef`, retry metadata, side-effect scope metadata, app-server request construction, response parsing, transport ownership, read/interrupt helpers, and generic classified-agent observations. State that moifold still owns role-specific prompts, lifecycle decisions, structured-output evidence requirements, and when a classified agent result becomes a durable event.
9. Document the GitHub adapter surface either in the new contract page or a small linked adapter subsection under the framework docs. Cover `GitHubCommandSpec`, typed GitHub ids, remote issue/PR/check/review-thread parsers, merge-state classification/rendering, git branch/SHA parsing, and pure command rendering helpers. State that moifold still owns when those commands run, which issue/PR lifecycle transitions use them, and irreversible merge/close/review-publication policy.
10. Add only minimal root `README.md` or `docs/correctness-model.md` navigation if it materially improves access to the framework contract. If touched, add a short link rather than duplicating framework details. Do not edit roadmap files, `orchestrator/state.json`, implementation notes, merge notes, reviews, source files, tests, Cabal files, golden fixtures, or compatibility facades.
11. Review the final documentation diff for tense and claims. Replace future-only phrases such as "should provide" or "eventual layering" where they describe implemented modules; keep future/design language only for explicitly deferred ideas. Ensure the docs do not imply external package publication, Cabal readiness, compatibility deprecation, package extraction completion, or lifecycle policy movement into the framework.

### Verification

- `git diff --check`
- `git diff --cached --check` if any files are staged during the round
- Confirm `git diff --name-only` is limited to `docs/agentic-workflow-framework/` plus optional root `README.md` or `docs/correctness-model.md` navigation and the round artifacts expected by the orchestrator.
- Directly review the docs against `orchestrator/project-contract.md` and `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/verification.md`, especially the non-goals around event schema stability, moifold lifecycle ownership, compatibility facades, no package publishing, and docs/readiness rounds distinguishing implemented APIs from design goals.
- Directly compare the documented API surface to `moifold.cabal` and the source modules listed in Step 1. Because this round is docs-only, `cabal test watcher-core-test` and `cabal build all` are not required unless the implementation touches Haskell, Cabal, tests, generated fixtures, or other non-documentation files.
