### Changes Made
- `orchestrator/rounds/round-076/implementation-notes.md`: recorded the evidence-only behavior-owner classification for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

No production source, app files, tests, Cabal files, docs, README, roadmap files, runtime compatibility files, event schemas, healthcheck behavior, repair behavior, deprecation pragmas, import migrations, facade removals, `worker-plan.json`, `CodexWatcher.Workflow.Types`, or `CodexWatcher.Workflow.Execution` were changed or classified.

### Tests
- No tests were added or changed because this round is artifact-only evidence.
- Artifact verification commands are recorded below. `cabal build all` and `cabal test watcher-core-test` were intentionally not run because the round did not escape the round-local artifact boundary.

### Notes

#### Active Input Confirmation
- Active worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-076`.
- `orchestrator/state.json` confirms active round `round-076`, stage `implement`, branch `orchestrator/round-076-behavior-owner-classification`, roadmap id `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, and roadmap dir `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`.
- `orchestrator/rounds/round-076/selection.md` selects milestone `milestone-001-current-facade-evidence`, direction `direction-002-behavior-owner-classification`, extracted item `round-076-behavior-owner-classification`, depending on `round-075`.
- `orchestrator/project-contract.md` keeps public compatibility facades available until safe removal is proven with import, build, and behavior coverage. The prior `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not deprecation, migration, Cabal exposure, or removal approval.
- Active verification requires this round to stay focused on `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`; it keeps `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Execution`, runtime compatibility files, event JSON `type` values, healthcheck, repair, and release/publication decisions out of scope.

#### Commands Run
- `pwd && git status --short`
- `sed -n '1,220p' orchestrator/roles/implementer.md`
- `sed -n '1,240p' orchestrator/rounds/round-076/selection.md`
- `sed -n '1,260p' orchestrator/rounds/round-076/plan.md`
- `sed -n '1,320p' orchestrator/rounds/round-075/implementation-notes.md`
- `sed -n '1,260p' orchestrator/state.json`
- `sed -n '1,260p' orchestrator/project-contract.md`
- `sed -n '1,320p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
- `sed -n '1,180p' src/CodexWatcher/AppServerClient.hs`
- `sed -n '1,160p' src/CodexWatcher/Core/Ids.hs`
- `sed -n '1,220p' src/CodexWatcher/Workflow/EventLog.hs`
- `sed -n '1,220p' src/CodexWatcher/Workflow/Permission.hs`
- `git diff -- orchestrator/rounds/round-076/plan.md orchestrator/rounds/round-076/implementation-notes.md`
- `git status --short`
- `test ! -e orchestrator/rounds/round-076/worker-plan.json && echo 'no worker-plan.json'`
- `git diff --name-only`
- `git status --short -uall`
- `git diff --no-index -- /dev/null orchestrator/rounds/round-076/implementation-notes.md`
- `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission|Types|Execution))|worker-plan|Out Of Scope|Classification Table|pure reexport|mixed surface" orchestrator/rounds/round-076/implementation-notes.md`
- `git diff --check`

#### Classification Table

| Facade | Classification | Behavior owner evidence | Import/exposure blocker from round 075 |
| --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | pure reexport | Wrapper only reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; app-server protocol behavior belongs to those Codex agent adapter modules. | 28 direct local imports and Cabal exposure at `moifold.cabal:33`; broad moifold runtime, classifier, CLI, healthcheck, runner-guard, daemon-loop, docs-migration, and test imports remain. |
| `CodexWatcher.Core.Ids` | pure reexport | Wrapper only reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; this is adapter-id convenience, not one behavior owner. | 65 direct local imports and Cabal exposure at `moifold.cabal:46`; moifold source, app, runtime rendering, CLI parsing, event replay, state-machine, domain, and tests still import the facade. |
| `CodexWatcher.Workflow.EventLog` | mixed surface | Reexports generic replay/audit helpers, but also defines `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents` tied to concrete moifold event/state/effect/spec types. | 3 selected-facade direct local imports and Cabal exposure at `moifold.cabal:116`; concrete moifold replay/initialization behavior and old-log/event-schema compatibility decisions remain. |
| `CodexWatcher.Workflow.Permission` | mixed surface | Reexports reusable permission core, but also defines `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and `validateWorkflowEffectPlan`; exposes `PhaseActionValidationError` and phase-action formatting from the moifold state machine. | 1 selected-facade direct local import and Cabal exposure at `moifold.cabal:128`; concrete moifold phase-validation behavior and public API/downstream inventory decisions remain. |

#### Per-Facade Evidence

`CodexWatcher.AppServerClient`
- Wrapper-module read: `src/CodexWatcher/AppServerClient.hs` exports only `module CodexWatcher.Workflow.Agent.Codex.Client` and `module CodexWatcher.Workflow.Agent.Codex.Transport`, with matching imports and no local definitions.
- Classification: pure reexport convenience facade.
- Owner rationale: app-server parsing and failure types belong to `CodexWatcher.Workflow.Agent.Codex.Client`; endpoint, transport, request session, options, and websocket operations belong to `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Moifold behavior note: the facade has broad moifold import and compatibility exposure, but the wrapper itself does not own protocol behavior.
- Round-075 blocker notes: removal remains blocked on import migration, app-server protocol behavior checks, failure formatting checks, package-boundary approval, and downstream inventory approval.
- Protecting checks recorded by round 075: `test/AppServerSpec.hs` and app-server portions of `test/Main.hs`, plus focused checks for protocol parsing, endpoint/session rendering, materialization fallback, request id mismatch, JSON-RPC failure formatting, timeout formatting, and healthcheck/runner-guard failure rendering before any behavior-changing round.

`CodexWatcher.Core.Ids`
- Wrapper-module read: `src/CodexWatcher/Core/Ids.hs` exports only `module CodexWatcher.Workflow.Agent.Ids` and `module CodexWatcher.Workflow.GitHub.Ids`, with matching imports and no local definitions.
- Classification: pure reexport convenience facade.
- Owner rationale: `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId` belong to the agent id owner `CodexWatcher.Workflow.Agent.Ids`; `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha` belong to the GitHub id owner `CodexWatcher.Workflow.GitHub.Ids`.
- Adapter-id convenience note: this facade groups identifiers from different adapter/package owners for moifold convenience; it is not evidence of a single shared behavior owner.
- Round-075 blocker notes: removal remains blocked until split-import evidence proves each use has the correct agent or GitHub owner and parser/rendering checks cover affected identifiers.
- Protecting checks recorded by round 075: `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, and identifier-heavy `test/Main.hs` workflow assertions; follow-up parser/rendering checks for branch names, commit shas, issue numbers, PR numbers, repo names, request ids, review thread ids, thread ids, turn ids, and request id progression.

`CodexWatcher.Workflow.EventLog`
- Wrapper-module read: `src/CodexWatcher/Workflow/EventLog.hs` reexports generic types and helpers from `CodexWatcher.Workflow.EventLog.Core` and audit helpers from `CodexWatcher.Workflow.Audit`, then locally defines moifold-specific bridge helpers.
- Classification: mixed surface.
- Generic owner rationale: reusable replay/audit contracts belong to `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit`.
- Moifold behavior bridge rationale: `initializeMoifoldWorkflow` specializes `initializeWorkflowEvent @MoifoldSpec id`; `applyMoifoldWorkflowEvent` specializes `applyWorkflowEvent @MoifoldSpec id`; both return concrete `SomeWatcherState` and `EffectPlan` over concrete `WatcherEvent`. `replayMoifoldWorkflowEvents` delegates to `replayEventLog` over `[WatcherEvent]` and returns `EventReplayResult`.
- Round-075 blocker notes: moifold-specific replay and initialization helpers still depend on concrete `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; removal remains blocked on old-log/golden replay evidence, concrete event-schema compatibility, and a reviewed decision for moifold-specific helpers.
- Protecting checks recorded by round 075: `test/Main.hs` replay/golden/event-log cases, event-log repair cases, docs-migration replay fixture checks, package-boundary assertions, old-log fixture replay, golden event `type` field preservation, detailed replay failure formatting, commit abstraction behavior, and audit label parity.

`CodexWatcher.Workflow.Permission`
- Wrapper-module read: `src/CodexWatcher/Workflow/Permission.hs` reexports reusable permission APIs from `CodexWatcher.Workflow.Permission.Core`, imports concrete moifold state-machine validation from `CodexWatcher.StateMachine`, and locally defines moifold/spec convenience validators.
- Classification: mixed surface.
- Generic owner rationale: `WorkflowEffectPermissionCheck`, `WorkflowPermissionPolicy`, `WorkflowPermissionValidationError`, reusable formatting, `validateWorkflowEffectPlanCore`, `validateWorkflowEffectPlanWithPolicy`, `workflowEffectPermissionChecks`, `workflowEffectPermissionChecksWithPolicy`, and `workflowSpecPermissionPolicy` belong to `CodexWatcher.Workflow.Permission.Core`.
- Moifold behavior bridge rationale: `validateMoifoldEffectPlan` is concrete moifold phase validation over `SomeWatcherState` and `EffectPlan` via `validatePhaseActionPlan`; `moifoldPermissionPolicy` specializes `workflowSpecPermissionPolicy @MoifoldSpec`; exported `PhaseActionValidationError` and `formatPhaseActionValidationError` are tied to the moifold state-machine phase-action contract.
- Round-075 blocker notes: concrete moifold phase validation helpers remain tied to `CodexWatcher.StateMachine`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; removal remains blocked on public API decision, downstream-user inventory, and permission/phase-validation behavior evidence.
- Protecting checks recorded by round 075: `test/Main.hs` cases `phaseActionValidationRejectsInvalidCombinations`, `phaseActionValidationAcceptsStateMachineDecisions`, `workflowPermissionFacadeMatchesStateMachine`, `workflowPermissionCoreChecksMatchMoifoldPermission`, and `workflowPermissionPolicyMatchesMoifoldPermission`; follow-up focused phase-validation parity and permission-denial formatting checks.

#### Out Of Scope Confirmation
- No production source, tests, Cabal files, docs, README, roadmap files, runtime compatibility files, event schemas, healthcheck behavior, repair behavior, release metadata, publication decisions, deprecation state, import migration, facade removal, or `worker-plan.json` were edited.
- `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution` were not classified.
- Runtime compatibility files, event JSON `type` values, healthcheck, repair, release, and publication decisions remain untouched and unapproved by this round.
- This classification is descriptive, not prescriptive. It records owner evidence later readiness and policy rounds must respect; it does not recommend or authorize migration, deprecation, Cabal exposure changes, or removal.
