### Terminal Decision Report

Roadmap: `2026-05-10-00-facade-removal-readiness`
Revision: `rev-001`
Selected item: `round-082-terminal-decision-report`
Worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-082`
Branch: `orchestrator/round-082-terminal-decision-report`

This is a round-local artifact-only terminal decision report for the selected
facades:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

No production source, tests, docs, README, Cabal/package descriptors, exposed
module lists, roadmap files, `orchestrator/state.json`, runtime compatibility
files, event schemas, healthcheck, repair, import migrations, deprecation
pragmas, public wording, facade deletions, release decisions, or publication
decisions are approved or changed by this report.

The closed `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not
deprecation, migration, Cabal exposure, or removal approval. Preferred-import
guidance, internal import migration, local import reduction, and owner-scoped
downstream scans are evidence only.

### Command Log

Inputs and dependency evidence read:

- `pwd && git status --short --branch`
- `rg -n "" orchestrator/roles/implementer.md orchestrator/rounds/round-082/plan.md orchestrator/rounds/round-082/selection.md orchestrator/project-contract.md orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
- `rg --files orchestrator/rounds/round-075 orchestrator/rounds/round-076 orchestrator/rounds/round-077 orchestrator/rounds/round-078 orchestrator/rounds/round-079 orchestrator/rounds/round-080 orchestrator/rounds/round-081`
- `rg -n "(defer|deferred|hold|remove|removed|deprecated|approved|blocked|CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.(EventLog|Permission)))" orchestrator/rounds/round-075 orchestrator/rounds/round-076 orchestrator/rounds/round-077 orchestrator/rounds/round-078 orchestrator/rounds/round-079 orchestrator/rounds/round-080 orchestrator/rounds/round-081`
- `sed -n '1,220p' orchestrator/rounds/round-075/implementation-notes.md`
- `sed -n '1,220p' orchestrator/rounds/round-076/implementation-notes.md`
- `sed -n '1,180p' orchestrator/rounds/round-077/implementation-notes.md`
- `sed -n '1,180p' orchestrator/rounds/round-078/implementation-notes.md`
- `sed -n '1,220p' orchestrator/rounds/round-079/implementation-notes.md`
- `sed -n '1,220p' orchestrator/rounds/round-080/deprecation-readiness-decision.md`
- `sed -n '1,220p' orchestrator/rounds/round-081/cabal-exposure-decision.md`
- `sed -n '220,340p' orchestrator/rounds/round-081/cabal-exposure-decision.md`

Artifact verification commands are recorded in
`orchestrator/rounds/round-082/implementation-notes.md`.

### Dependency Evidence

| Round | Reviewed evidence carried forward |
| --- | --- |
| `round-075` | Current facade inventory: `CodexWatcher.AppServerClient` had 28 local imports, `CodexWatcher.Core.Ids` had 65, `CodexWatcher.Workflow.EventLog` had 3, and `CodexWatcher.Workflow.Permission` had 1. The round was evidence-only and did not approve migration, deprecation, Cabal exposure changes, or removal. |
| `round-076` | Behavior-owner classification: `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids` are pure reexport facades; `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` are mixed moifold bridge surfaces. |
| `round-077` | Approved a narrow behavior-neutral internal `CodexWatcher.AppServerClient` import migration. `cabal test watcher-core-test`, `cabal build all`, and `git diff --check` passed. The facade stayed live and unchanged. |
| `round-078` | Approved a narrow behavior-neutral `CodexWatcher.Core.Ids` split-import migration. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed. The facade stayed live and unchanged. |
| `round-079` | Approved artifact-only `hold` decisions for `CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission`, preserving mixed-surface, old-log/golden, public API, downstream, and permission/phase-validation blockers. |
| `round-080` | Approved artifact-only public deprecation `defer` decisions for all four selected facades. It approved no public deprecation signal, `DEPRECATED` pragma, public wording, Cabal exposure change, public API change, facade deletion, or removal. |
| `round-081` | Approved artifact-only Cabal exposure `defer` decisions for all four selected facades. It approved no exposed-module removal, package descriptor change, public API change, code/test/docs/roadmap/state change, or future exact removal by implication. |

### Final Surface Sets

Kept surface set:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

These surfaces are kept available and exposed for now as compatibility facades
because the current approved decision is `defer`. This is not a permanent keep
decision and is not release or publication approval.

Deferred surface set:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

Deprecated surface set:

- Empty. No reviewed evidence names an exact approved public deprecation signal,
  `DEPRECATED` pragma, public deprecation wording, or documentation/Haddock/Cabal
  alignment for any selected facade.

Removed surface set:

- Empty. No exact removal surface is currently approved. No pre-selection
  reviewed evidence was found that names an exact selected facade, module, or
  exposed-module entry as approved for removal.

Blocked surface set:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

The blocked set is identical to the deferred set because each selected facade
still lacks at least one required gate for public deprecation, Cabal exposure
removal, facade deletion, or exact removal.

### Per-Surface Decisions

| Surface | Current approved status | Kept-available rationale | Blockers | Not approved |
| --- | --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | `defer`; kept available for now. | Pure reexport facade over `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. Round 077 approved a narrow internal import migration and left the facade live and unchanged. | 13 local facade imports remained in round-080/081 evidence; owner-scoped GitHub search still found indexed `soulomoon/moifold` facade users; downstream proof is owner-scoped only; public deprecation/Cabal/docs/Haddock alignment is missing; focused app-server protocol, endpoint/session, command rendering, and failure-formatting validation would be required for a future exact slice. | No public deprecation signal, `DEPRECATED` pragma, public wording, Cabal exposure removal, package descriptor edit, import migration, facade deletion, public API change, runtime compatibility change, event schema change, healthcheck/repair change, release, or publication. |
| `CodexWatcher.Core.Ids` | `defer`; kept available for now. | Pure reexport facade over `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`. Round 078 approved a narrow internal split-import migration and left the facade live and unchanged. | 35 local facade imports remained in round-080/081 evidence, including `app/Main.hs`, tests, mixed users, runtime compatibility, event-log/repair, healthcheck, and `Workflow.Execution`; `app/Main.hs` had an executable/package descriptor blocker; owner-scoped GitHub search still found indexed `soulomoon/moifold` facade users; downstream proof is owner-scoped only; parser/rendering behavior coverage and public deprecation/Cabal/docs/Haddock alignment are missing for an exact removal slice. | No public deprecation signal, `DEPRECATED` pragma, public wording, Cabal exposure removal, package descriptor edit, import migration, facade deletion, public API change, runtime compatibility change, event schema change, healthcheck/repair change, release, or publication. |
| `CodexWatcher.Workflow.EventLog` | `defer`; kept available for now. | Mixed moifold bridge. Generic replacement modules are available in `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit`, but the selected facade still carries concrete moifold helpers. Round 079 approved hold; round 080/081 converted public deprecation and Cabal exposure decisions to `defer`. | The facade still locally defines or exposes moifold bridge helpers over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; 3 exact local imports remained in round-080/081 evidence; exact removal would need a reviewed split plan, old-log/golden/replay behavior proof, concrete event schema/type-field stability, downstream/public API inventory, docs/Haddock alignment, and Cabal exposure approval. | No public deprecation signal, `DEPRECATED` pragma, public wording, Cabal exposure removal, package descriptor edit, import migration, facade deletion, public API change, runtime compatibility change, event schema change, healthcheck/repair change, release, or publication. |
| `CodexWatcher.Workflow.Permission` | `defer`; kept available for now. | Mixed moifold bridge. Reusable permission core exists in `CodexWatcher.Workflow.Permission.Core`, but the selected facade still exposes concrete moifold phase-validation and state-machine formatting names. Round 079 approved hold; round 080/081 converted public deprecation and Cabal exposure decisions to `defer`. | The facade still exposes `PhaseActionValidationError`, `formatPhaseActionValidationError`, `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and `validateWorkflowEffectPlan` over concrete moifold state/effect/spec validation; 1 exact local import remained in round-080/081 evidence; exact removal would need reviewed public API/downstream decisions, permission/phase-validation behavior proof, docs/Haddock alignment, and Cabal exposure approval. | No public deprecation signal, `DEPRECATED` pragma, public wording, Cabal exposure removal, package descriptor edit, import migration, facade deletion, public API change, runtime compatibility change, event schema change, healthcheck/repair change, release, or publication. |

### Terminal Decision

No selected facade is approved for deprecation or removal.

All four selected facades are terminally recorded for this roadmap family as:

- kept available for now as compatibility facades;
- deferred for public deprecation;
- deferred for Cabal exposure removal;
- blocked from exact removal by the named evidence gaps above.

The removed-surface set is empty and the deprecated-surface set is empty.
Future work would require a new reviewed selection that names the exact surface,
records current import scans, behavior evidence, package-boundary evidence,
documentation/Cabal evidence where relevant, downstream scope, and reviewer
approval. This report itself authorizes no externally visible change.
