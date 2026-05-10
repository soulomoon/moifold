### Changes Made
- `orchestrator/rounds/round-075/implementation-notes.md`: recorded the round-075 evidence-only facade inventory for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

No production source, app, tests, Cabal files, docs, README, roadmap files, runtime compatibility files, event schemas, healthcheck behavior, repair behavior, deprecation pragmas, import migrations, facade removals, or `worker-plan.json` were changed.

### Tests
- No tests were added or changed because this round is artifact-only evidence.
- Focused protecting checks recorded below for later behavior-changing rounds.

### Notes

#### Active Input Confirmation
- Active worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-075`.
- `orchestrator/state.json` confirms active round `round-075`, stage `implement`, branch `orchestrator/round-075-current-facade-evidence`.
- Roadmap lineage remains `2026-05-10-00-facade-removal-readiness` revision `rev-001`, with roadmap dir `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001`.
- `orchestrator/project-contract.md` keeps public compatibility facades available until safe removal is proven with import, build, and behavior coverage. The previous `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not removal, deprecation, migration, or Cabal exposure approval.

#### Commands Run
- `pwd && git status --short`
- `sed -n '1,240p' orchestrator/roles/implementer.md`
- `sed -n '1,240p' orchestrator/rounds/round-075/selection.md`
- `sed -n '1,260p' orchestrator/rounds/round-075/plan.md`
- `sed -n '1,260p' orchestrator/state.json`
- `sed -n '1,260p' orchestrator/project-contract.md`
- `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
- `find . -maxdepth 2 \( -name '*.cabal' -o -name 'README.md' \) -print && find . -maxdepth 1 -type d \( -name 'src' -o -name 'app' -o -name 'test' -o -name 'docs' -o -name 'agent-workflow-*' -o -name 'examples' \) -print`
- `rg -n "^module CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))\b|import (qualified )?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))\b|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "CodexWatcher\.(Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Audit|Workflow\.Permission\.Core)" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "AppServerClient|Core\.Ids|Workflow\.EventLog|Workflow\.Permission|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Audit|Workflow\.Permission\.Core" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "^module CodexWatcher\.AppServerClient\b|import (qualified )?CodexWatcher\.AppServerClient\b|CodexWatcher\.AppServerClient" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "^module CodexWatcher\.Core\.Ids\b|import (qualified )?CodexWatcher\.Core\.Ids\b|CodexWatcher\.Core\.Ids" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "^module CodexWatcher\.Workflow\.EventLog\b|import (qualified )?CodexWatcher\.Workflow\.EventLog\b|CodexWatcher\.Workflow\.EventLog" src app test docs README.md *.cabal agent-workflow-* examples`
- `rg -n "^module CodexWatcher\.Workflow\.Permission\b|import (qualified )?CodexWatcher\.Workflow\.Permission\b|CodexWatcher\.Workflow\.Permission" src app test docs README.md *.cabal agent-workflow-* examples`
- `sed -n '1,120p' src/CodexWatcher/AppServerClient.hs`
- `sed -n '1,100p' src/CodexWatcher/Core/Ids.hs`
- `sed -n '1,140p' src/CodexWatcher/Workflow/EventLog.hs`
- `sed -n '1,120p' src/CodexWatcher/Workflow/Permission.hs`
- `rg -n "^import (qualified )?CodexWatcher\.AppServerClient\b" src app test agent-workflow-* examples`
- `rg -n "^import (qualified )?CodexWatcher\.Core\.Ids\b" src app test agent-workflow-* examples`
- `rg -n "^import (qualified )?CodexWatcher\.Workflow\.EventLog\b" src app test agent-workflow-* examples`
- `rg -n "^import (qualified )?CodexWatcher\.Workflow\.Permission\b" src app test agent-workflow-* examples`
- `rg -n "^import (qualified )?CodexWatcher\.AppServerClient\b" src app test agent-workflow-* examples | wc -l`
- `rg -n "^import (qualified )?CodexWatcher\.Core\.Ids\b" src app test agent-workflow-* examples | wc -l`
- `rg -n "^import (qualified )?CodexWatcher\.Workflow\.EventLog(\s|$)" src app test agent-workflow-* examples | wc -l`
- `rg -n "^import (qualified )?CodexWatcher\.Workflow\.Permission(\s|$)" src app test agent-workflow-* examples | wc -l`
- `rg -n "^import (qualified )?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))(\s|$)" agent-workflow-* examples`
- `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" README.md docs agent-workflow-*/README.md`
- `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" *.cabal agent-workflow-*/*.cabal`
- `sed -n '7600,8050p' test/Main.hs`
- `rg -n "AppServer|app-server|formatAppServerClientFailure|decodeAppServerIncoming|parseThread|sendOneAppServerRequest" test agent-workflow-codex/src src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Failure.hs src/CodexWatcher/Healthcheck.hs src/CodexWatcher/RunnerGuard.hs`
- `rg -n "EventLog|event log|replay|Replay|golden|Golden|WorkflowEventLog" test src/CodexWatcher/EventLog src/CodexWatcher/GoldenReplay.hs src/CodexWatcher/Workflow/EventLog.hs`
- `rg -n "Permission|permission|validateMoifoldEffectPlan|phase|PhaseAction|validatePhaseActionPlan" test src/CodexWatcher/Workflow/Permission.hs src/CodexWatcher/StateMachine.hs agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs`
- `rg -n "BranchName|CommitSha|IssueNumber|PrNumber|RepoName|RequestId|ReviewThreadId|ThreadId|TurnId|parse|render" test/*Spec.hs test/Main.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`

#### Scan Scope
- Inspected surfaces: `src`, `app`, `test`, `docs`, root `README.md`, root `*.cabal`, `agent-workflow-*` package candidate directories, package-candidate README files, package-candidate Cabal files, and `examples`.
- Not inspected: external downstream repositories, published package tarballs, Hackage metadata, GitHub code search, deployed operator environments, and generated source distributions. Local absence of imports outside the inspected worktree surfaces is therefore incomplete downstream evidence.

#### Facade Results

`CodexWatcher.AppServerClient`
- Module definition: `src/CodexWatcher/AppServerClient.hs`.
- Current facade shape: reexport-only wrapper for `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Direct import count in local code/tests/examples/package candidates: 28.
- Import sites are in moifold `src` and `test`; none were found under `app`, `agent-workflow-*`, or `examples`.
- Cabal exposure: `moifold.cabal:33`.
- Non-import references: `test/Main.hs` package-boundary and compatibility assertions, plus docs in `docs/agentic-workflow-framework/package-extraction-readiness.md`, `package-identity-versioning-contract.md`, `release-notes.md`, `release-candidate-bundle.md`, and `compatibility-deprecation-policy.md`.
- Replacement mapping: import reusable app-server parsing and failure types from `CodexWatcher.Workflow.Agent.Codex.Client`; import endpoint, transport, request session, options, and websocket operations from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Blocker class: broad moifold runtime, classifier, CLI, healthcheck, runner-guard, daemon-loop, docs-migration, and test imports still depend on the facade. Removal remains blocked on import migration, app-server protocol behavior checks, failure formatting checks, package-boundary approval, and downstream inventory approval.

`CodexWatcher.Core.Ids`
- Module definition: `src/CodexWatcher/Core/Ids.hs`.
- Current facade shape: reexport-only wrapper for `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`.
- Direct import count in local code/tests/examples/package candidates: 65.
- Import sites are in moifold `src`, `app/Main.hs`, and tests; none were found under `agent-workflow-*` or `examples`.
- Cabal exposure: `moifold.cabal:46`.
- Non-import references: docs in `docs/agentic-workflow-framework/release-candidate-bundle.md`, `release-notes.md`, and `compatibility-deprecation-policy.md`.
- Replacement mapping: `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId` map to `CodexWatcher.Workflow.Agent.Ids`; `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha` map to `CodexWatcher.Workflow.GitHub.Ids`.
- Blocker class: mixed agent and GitHub identifier imports are still widespread across moifold source, app, runtime rendering, CLI parsing, event replay, state-machine, domain, and tests. Removal remains blocked until split-import evidence proves each use has the correct agent or GitHub owner and parser/rendering checks cover the affected identifiers.

`CodexWatcher.Workflow.EventLog`
- Module definition: `src/CodexWatcher/Workflow/EventLog.hs`.
- Current facade shape: mixed facade. It reexports generic replay/audit helpers from `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.Audit`, but also exposes moifold-specific `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`.
- Direct selected-facade import count in local code/tests/examples/package candidates: 3 (`src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, and `test/Main.hs`).
- Additional replacement-module imports already exist for `CodexWatcher.Workflow.EventLog.Commit.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, and `CodexWatcher.Workflow.EventLog.Core`.
- Cabal exposure: `moifold.cabal:116`; replacement core exposures: `agent-workflow-core/agent-workflow-core.cabal:51-53`.
- Non-import references: `test/Main.hs` exposed-module/package-boundary assertions; docs in `agent-workflow-core/README.md`, `docs/agentic-workflow-framework/moifold-consumer-validation.md`, `release-notes.md`, `implemented-api-freeze.md`, `compatibility-deprecation-policy.md`, `extraction-plan.md`, `event-log-and-transactions.md`, and `package-consumer-guide.md`.
- Replacement mapping: generic replay helpers to `CodexWatcher.Workflow.EventLog.Core`; line decoding helpers to `CodexWatcher.Workflow.EventLog.File.Core`; commit abstraction to `CodexWatcher.Workflow.EventLog.Commit.Core`; audit values/helpers to `CodexWatcher.Workflow.Audit`.
- Blocker class: moifold-specific replay and initialization helpers still depend on concrete `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`. Removal remains blocked on old-log/golden replay evidence, concrete event-schema compatibility, and a reviewed decision for the moifold-specific helpers.

`CodexWatcher.Workflow.Permission`
- Module definition: `src/CodexWatcher/Workflow/Permission.hs`.
- Current facade shape: mixed facade. It reexports reusable permission checks from `CodexWatcher.Workflow.Permission.Core`, but also exposes concrete moifold phase validation via `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, `PhaseActionValidationError`, and phase-action formatting.
- Direct selected-facade import count in local code/tests/examples/package candidates: 1 (`test/Main.hs`).
- Cabal exposure: `moifold.cabal:128`; replacement core exposure: `agent-workflow-core/agent-workflow-core.cabal:57`.
- Non-import references: `test/Main.hs` exposed-module/package-boundary assertions; docs in `agent-workflow-core/README.md`, `docs/agentic-workflow-framework/workflow-spec.md`, `package-consumer-guide.md`, `moifold-consumer-validation.md`, `release-notes.md`, `implemented-api-freeze.md`, `extraction-plan.md`, `event-log-and-transactions.md`, `monad-dsl.md`, and `compatibility-deprecation-policy.md`.
- Replacement mapping: reusable policy/check/formatting APIs map to `CodexWatcher.Workflow.Permission.Core`.
- Blocker class: concrete moifold phase validation helpers remain tied to `CodexWatcher.StateMachine`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`. Removal remains blocked on public API decision, downstream-user inventory, and permission/phase-validation behavior evidence.

#### Protecting Tests And Follow-Up Checks
- `CodexWatcher.AppServerClient`: protect with `test/AppServerSpec.hs` and the app-server portions of `test/Main.hs`; follow up with focused checks for app-server protocol parsing, endpoint/session rendering, materialization fallback, request id mismatch, JSON-RPC failure formatting, timeout formatting, and healthcheck/runner-guard failure rendering before any migration or removal.
- `CodexWatcher.Core.Ids`: protect with `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, and identifier-heavy `test/Main.hs` workflow assertions; follow up with parser/rendering checks for branch names, commit shas, issue numbers, PR numbers, repo names, request ids, review thread ids, thread ids, turn ids, and request id progression when split imports are introduced.
- `CodexWatcher.Workflow.EventLog`: protect with `test/Main.hs` replay/golden/event-log cases, event-log repair cases, docs-migration replay fixture checks, and package-boundary assertions; follow up with old-log fixture replay, golden event `type` field preservation, detailed replay failure formatting, commit abstraction behavior, and audit label parity before touching facade behavior.
- `CodexWatcher.Workflow.Permission`: protect with `test/Main.hs` `phaseActionValidationRejectsInvalidCombinations`, `phaseActionValidationAcceptsStateMachineDecisions`, `workflowPermissionFacadeMatchesStateMachine`, `workflowPermissionCoreChecksMatchMoifoldPermission`, and `workflowPermissionPolicyMatchesMoifoldPermission`; follow up with focused phase-validation parity and permission-denial formatting checks before migration or removal.

#### Verification
- Artifact review target is this file only, plus the preexisting planner artifacts already present under `orchestrator/rounds/round-075/`.
- `cabal build all` and `cabal test watcher-core-test` were intentionally not run because the plan says not to run them for artifact-only evidence edits unless code, package descriptors, exposed modules, README/Haddock wording, or source-distribution metadata are touched.
