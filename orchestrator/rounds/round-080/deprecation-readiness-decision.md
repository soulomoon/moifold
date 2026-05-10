### Changes Made
- `orchestrator/rounds/round-080/deprecation-readiness-decision.md`: recorded the artifact-only public deprecation readiness decision for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.

No production code, tests, docs, Haddock text, changelog/release-note text, Cabal/package descriptors, roadmap files, `orchestrator/state.json`, deprecation pragmas, public wording, exposed modules, runtime compatibility files, event schemas, healthcheck, repair, import migrations, or facade removals were changed.

### Tests
- No tests were added or changed. This implementation write is round-local evidence only.
- `cabal test watcher-core-test` was not run because no source, test, package descriptor, public API, or behavior surface changed. Focused inventory, Haddock, and artifact-scope checks are recorded below.

### Notes

#### Active Input Confirmation
- Worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-080`.
- Branch: `orchestrator/round-080-deprecation-readiness`.
- Roadmap: `2026-05-10-00-facade-removal-readiness`, revision `rev-001`.
- Selected item: `round-080-public-deprecation-readiness-decision`.
- Artifact boundary: only this file is expected to change.
- Project contract: public compatibility facades stay available until safe removal is proven with import, build, and behavior coverage. The closed `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not deprecation, migration, Cabal exposure, or removal approval.
- Active verification bundle: decisions must stay focused on `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`; `Workflow.Types`, `Workflow.Execution`, runtime compatibility files, event JSON `type` values, healthcheck, repair, and release/publication decisions remain out of scope.

#### Commands Run
- Loaded active inputs:
  - `git status --short --branch`
  - `sed -n '1,220p' orchestrator/roles/implementer.md`
  - `sed -n '1,240p' orchestrator/state.json`
  - `sed -n '1,260p' orchestrator/project-contract.md`
  - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
  - `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/retry-subloop.md`
  - `sed -n '1,260p' orchestrator/rounds/round-080/selection.md`
  - `sed -n '1,320p' orchestrator/rounds/round-080/plan.md`
- Loaded dependency evidence:
  - `sed -n '1,320p' orchestrator/rounds/round-075/implementation-notes.md`
  - `sed -n '1,320p' orchestrator/rounds/round-076/implementation-notes.md`
  - `sed -n '1,260p' orchestrator/rounds/round-077/implementation-notes.md`
  - `sed -n '1,260p' orchestrator/rounds/round-078/implementation-notes.md`
  - `sed -n '1,360p' orchestrator/rounds/round-079/implementation-notes.md`
  - `sed -n '1,260p' orchestrator/rounds/round-077/review.md`
  - `sed -n '1,260p' orchestrator/rounds/round-078/review.md`
  - `sed -n '1,320p' orchestrator/rounds/round-079/review.md`
- Refreshed selected-facade import inventory:
  - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- Refreshed replacement-module import inventory:
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission\.Core(\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- Inspected facade and replacement definitions with the `sed` commands listed in the round plan.
- Refreshed Cabal/package-boundary evidence:
  - `rg -n "^  exposed-modules:|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.(Agent|GitHub)\.Ids|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Permission\.Core)" moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`
  - `rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|exposed module|package boundary|agent-workflow-core|agent-workflow-codex|agent-workflow-github" test/Main.hs`
- Refreshed docs/Haddock/release evidence:
  - `find docs -path '*dist*' -prune -o -type f \( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \) -print | sort`
  - `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" README.md docs agent-workflow-*/README.md examples/workflow-package-consumer/README.md`
  - `rg -n "deprecat|deprecated|DEPRECATED|remove-later|preferred import|preferred-import|compatibility facade|compatibility-only" README.md docs agent-workflow-*/README.md docs/agentic-workflow-framework/changelog.md docs/agentic-workflow-framework/release-notes.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  - `rg -n -e "\{-# DEPRECATED" -e "Deprecated:" -e "DEPRECATED" -e "deprecat" -e "compatibility-only" -e "preferred import" -e "preferred-import" src/CodexWatcher/AppServerClient.hs src/CodexWatcher/Core/Ids.hs src/CodexWatcher/Workflow/EventLog.hs src/CodexWatcher/Workflow/Permission.hs`
  - `cabal haddock all`
- Refreshed downstream inventory:
  - `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs`
  - `rg -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  - `rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))" *.cabal agent-workflow-*/*.cabal examples/workflow-package-consumer/*.cabal`
  - `gh auth status`
  - `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100`
  - `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100`
  - `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100`
  - `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100`
- Refreshed focused behavior-protection scans:
  - `rg -n "AppServer|app-server|formatAppServerClientFailure|decodeAppServerIncoming|parseThread|sendOneAppServerRequest|request-id|timeout" test src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src`
  - `rg -n "BranchName|CommitSha|IssueNumber|PrNumber|RepoName|RequestId|ReviewThreadId|ThreadId|TurnId|parse|render|nextRequestId" test src app agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`
  - `rg -n "workflowEventLog|workflow event-log|goldenEventLog|golden event|eventLogRepair|replayEventLog|WorkflowTransitionFailure|WorkflowReplayFailure" test/Main.hs test/*Spec.hs`
  - `rg -n "workflowPermission|workflow permission|phaseActionValidation|phase action|validateMoifoldEffectPlan|moifoldPermissionPolicy|Permission" test/Main.hs test/*Spec.hs`

#### Dependency Evidence From Rounds 075-079
- Round 075 refreshed selected-facade inventory. It found `AppServerClient` as a reexport-only wrapper with 28 local imports, `Core.Ids` as a reexport-only wrapper with 65 local imports, `Workflow.EventLog` as a mixed surface with 3 imports, and `Workflow.Permission` as a mixed surface with 1 import. It did not run package baselines because it was artifact-only.
- Round 076 classified behavior ownership. `AppServerClient` and `Core.Ids` were pure reexport facades. `Workflow.EventLog` and `Workflow.Permission` were mixed moifold bridge surfaces.
- Round 077 migrated a narrow `AppServerClient` internal import slice. Review approved the behavior-neutral import migration, with `cabal test watcher-core-test`, `cabal build all`, and `git diff --check` passing. The facade remained live and unchanged.
- Round 078 migrated a narrow `Core.Ids` internal split-import slice. Review approved the behavior-neutral import migration, with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passing. The facade remained live and unchanged.
- Round 079 recorded an approved hold for `Workflow.EventLog` and `Workflow.Permission`. Review approved the hold artifact and explicitly accepted that `cabal test watcher-core-test` was unnecessary for that artifact-only round.
- None of rounds 075-079 approved public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, or facade removal.

#### Current Import Inventory At HEAD
Exact selected-facade imports across `src`, `app`, `test`, `examples`, and package candidates:

| Surface | Current count | Current import sites |
| --- | ---: | --- |
| `CodexWatcher.AppServerClient` | 13 | `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/Turn/Classifier/Common.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`, `test/Main.hs`, `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Cli/Command/Observe.hs`, `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` |
| `CodexWatcher.Core.Ids` | 35 | `app/Main.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/GoldenReplay.hs`, `src/CodexWatcher/Effects.hs`, `src/CodexWatcher/Core/State.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/Domain/PrReview/Protocol.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/StateMachine.hs`, `src/CodexWatcher/EventLogRepair.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/EventLog/Replay.hs`, `test/Main.hs`, `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Domain/PrReview/Watcher.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Cli/Command/RunnerGuard.hs`, `src/CodexWatcher/Domain/PrReview/Loop.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Cli/RuntimeConfig.hs`, `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`, `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview.hs`, `src/CodexWatcher/Cli/Parser/Observe.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, `src/CodexWatcher/Cli/Parser/Common.hs` |
| `CodexWatcher.Workflow.EventLog` | 3 | `src/CodexWatcher/Daemon.hs`, `test/Main.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs` |
| `CodexWatcher.Workflow.Permission` | 1 | `test/Main.hs` |

No exact selected-facade imports were found under `examples`, `agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github`. Those directories do contain replacement-module imports such as `Workflow.EventLog.Core` and `Workflow.EventLog.Commit.Core`.

#### Replacement-Module And Migration-Path Evidence
- `CodexWatcher.Workflow.Agent.Codex.Client` / `Transport`: 22 import lines. These cover the direct Codex app-server protocol/client/transport path now used by the migrated slice and package candidate code.
- `CodexWatcher.Workflow.Agent.Ids` / `GitHub.Ids`: 42 import lines. These cover split agent-id and GitHub-id ownership for migrated callers and package candidates.
- `CodexWatcher.Workflow.EventLog.Core` / `File.Core` / `Commit.Core`: 8 import lines. These prove generic replay/file/commit pieces have direct import paths, but not that the moifold bridge facade can be deprecated.
- `CodexWatcher.Workflow.Permission.Core`: 1 import line, from the `Workflow.Permission` facade itself. This proves a reusable permission core exists, but not that concrete moifold phase-validation imports can be deprecated.

#### Facade Definition And Behavior Owner Classification
- `CodexWatcher.AppServerClient`: pure reexport facade only. The module reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` and has no local definitions.
- `CodexWatcher.Core.Ids`: pure reexport facade only. The module reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` and has no local definitions.
- `CodexWatcher.Workflow.EventLog`: mixed moifold bridge. It reexports generic replay/audit APIs, but locally defines `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents` over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`.
- `CodexWatcher.Workflow.Permission`: mixed moifold bridge. It reexports reusable permission core APIs, but also exposes concrete `PhaseActionValidationError`, `formatPhaseActionValidationError`, `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and `validateWorkflowEffectPlan` over moifold state/effect/spec validation.

#### Cabal And Package-Boundary Evidence
- `moifold.cabal` still exposes all four selected facades:
  - `CodexWatcher.AppServerClient`
  - `CodexWatcher.Core.Ids`
  - `CodexWatcher.Workflow.EventLog`
  - `CodexWatcher.Workflow.Permission`
- Replacement modules are exposed by package candidates:
  - `agent-workflow-codex.cabal`: `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Transport`, `CodexWatcher.Workflow.Agent.Ids`
  - `agent-workflow-github.cabal`: `CodexWatcher.Workflow.GitHub.Ids`
  - `agent-workflow-core.cabal`: `CodexWatcher.Workflow.EventLog.Commit.Core`, `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.Permission.Core`
- `test/Main.hs` still includes package-boundary and exposed-module inventory tests for `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, and `workflowMoifoldCabalLibraryDoesNotReexportAdapters`.
- The `app/Main.hs` executable still imports `CodexWatcher.Core.Ids`; round 078 recorded that direct `Workflow.GitHub.Ids` import would require a package descriptor dependency change, which is out of scope here.

#### Docs, Haddock, Changelog, And Release Notes Evidence
- `find docs ... '*haddock*'` found no checked-in docs HTML/text/Haddock files under `docs`.
- Source facades contain no `DEPRECATED`, deprecation, `compatibility-only`, `preferred import`, or `preferred-import` text.
- Docs and release material describe compatibility status and preferred imports, especially `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, but the policy explicitly says preferred-import policy is not a deprecation pragma, warning policy, Cabal descriptor migration, or removal approval.
- `docs/agentic-workflow-framework/release-notes.md` keeps the selected surfaces as moifold-owned facades and says the bundle does not add deprecation pragmas, require import migration, remove facades, or migrate lifecycle behavior.
- `cabal haddock all`: passed and generated Haddock for `agent-workflow-github`, `agent-workflow-core`, `agent-workflow-codex`, and `moifold`. It emitted existing missing-documentation and unresolved-link warnings, including missing module headers for `CodexWatcher.AppServerClient` and `CodexWatcher.Core.Ids`. Because Haddock has warnings and no selected surface has source deprecation wording, generated Haddock is not evidence that any public deprecation signal is already aligned.

#### Downstream Inventory
- Local in-repo/package-candidate downstream inventory:
  - No exact selected-facade imports under `examples`, `agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github`.
  - `*.cabal` scan shows selected facades only in `moifold.cabal`; package candidates expose replacement modules.
  - Docs mention selected facades as compatibility surfaces and replacement modules as preferred imports.
- GitHub code search was available and authenticated as `soulomoon`.
  - `CodexWatcher.AppServerClient`: 31 results, all in `soulomoon/moifold` at the current indexed public surface, including source/test imports and Cabal/module definition entries.
  - `CodexWatcher.Core.Ids`: 61 results, all in `soulomoon/moifold` at the current indexed public surface, including source/test imports and Cabal/module definition entries.
  - `CodexWatcher.Workflow.EventLog`: 0 results from `gh search code`.
  - `CodexWatcher.Workflow.Permission`: 0 results from `gh search code`.
- GitHub code search did not prove absence of external downstream consumers outside the `soulomoon` owner scope, and the indexed `soulomoon/moifold` results are not synchronized with this local branch's partial migrations. This is useful inventory evidence, not public deprecation approval.

#### Protecting Behavior-Test Evidence
- `AppServerClient`: `test/AppServerSpec.hs` covers app-server request rendering, initialized/session behavior, response matching, request-id mismatch, JSON-RPC failures, materialization fallback, thread system-error parsing, thread/turn id parsing, thread read turn parsing, and interpreter-backed thread start. `test/CliSpec.hs` covers endpoint CLI parsing. `test/Main.hs` still covers app-server classified turn flows and daemon workflow integration.
- `Core.Ids`: `test/AppServerSpec.hs` covers request/thread/turn ids and request-id/session behavior; `test/CliSpec.hs` covers CLI parsing; `test/GhGitSpec.hs` covers GitHub id parsing/rendering surfaces; `test/RuntimeSpec.hs` covers runtime command rendering with repo, branch, issue, PR, review-thread, commit, and thread identifiers; `test/Main.hs` covers identifier-heavy workflow transitions.
- `Workflow.EventLog`: `test/Main.hs` covers golden event-log `type` field preservation, golden replay fixtures, event-log repair behavior, commit-core append ordering, file-core line numbering and malformed-line formatting, detailed replay parity, transition/facade parity, DocsMigration event-log parity, and failure audit retry recommendations.
- `Workflow.Permission`: `test/Main.hs` covers phase-action validation acceptance/rejection, facade/state-machine parity, permission core checks matching moifold permission, policy parity, DocsMigration permissions, PR-review indexed permissions, and mergeability permission parity.
- These tests are behavior-protection evidence. Because no behavior was changed in this round, they were not rerun except through the focused scans and Haddock build.

#### Decision Table
| Surface | Status | Evidence supporting status | Missing gates before public deprecation wording, pragma, Cabal change, or removal |
| --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | `defer` | Pure reexport facade; direct replacement modules exist and are exposed; round 077 reduced local imports from 28 to 13 and was build/test approved; docs already identify preferred direct Codex adapter imports. | 13 local facade imports remain; GitHub code search still finds indexed `soulomoon/moifold` facade users; no reviewer approval names this surface ready for public deprecation; Haddock/source/release/Cabal surfaces are not aligned for a deprecation signal; downstream inventory is owner-scoped only. |
| `CodexWatcher.Core.Ids` | `defer` | Pure reexport facade; direct agent-id and GitHub-id owner modules exist and are exposed; round 078 reduced local imports from 65 to 35 and was build/test approved; docs identify preferred split imports for reusable consumers. | 35 local facade imports remain, including executable/package-boundary and mixed agent/GitHub users; `app/Main.hs` direct import is blocked without package descriptor change; GitHub code search still finds indexed `soulomoon/moifold` facade users; no public deprecation approval; parser/rendering behavior coverage has not been rerun for a public deprecation slice. |
| `CodexWatcher.Workflow.EventLog` | `defer` | Generic replacement modules exist and are exposed; current exact selected-facade import count is only 3; round 079 approved a hold with current mixed-surface evidence; old-log/golden/replay tests exist. | The facade still locally owns moifold bridge helpers over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; old-log/golden/replay behavior was not rerun for a deprecation slice; docs/Haddock/Cabal do not align on a public deprecation signal; no reviewed split plan or deprecation approval names this surface. |
| `CodexWatcher.Workflow.Permission` | `defer` | Reusable permission core exists and is exposed; current exact selected-facade import count is 1; round 079 approved a hold with current mixed-surface evidence; phase-validation and permission parity tests exist. | The facade still exposes concrete moifold phase-validation helpers and state-machine error formatting; no reviewed public API/downstream decision proves those names can be deprecated; docs/Haddock/Cabal do not align on a public deprecation signal; permission behavior was not rerun for a deprecation slice. |

#### Final Decision
No selected facade is ready for public deprecation now.

All four selected surfaces are `defer`. The current evidence supports preferred-import guidance and continued internal migration work for pure reexport users, but it does not satisfy the policy gates for public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, or removal. Missing evidence remains blockers, not approval.
