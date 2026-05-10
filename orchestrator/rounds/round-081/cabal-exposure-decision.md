### Cabal Exposure Decision

Roadmap: `2026-05-10-00-facade-removal-readiness`
Revision: `rev-001`
Extracted item: `round-081-cabal-exposure-decision`
Worktree: `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-081`
Branch: `orchestrator/round-081-cabal-exposure-decision`

This is an artifact-only decision round. The only implementation write is this
file. No `moifold.cabal`, package descriptor, exposed-module list, production
code, test, docs, roadmap, `orchestrator/state.json`, deprecation pragma,
public wording, runtime compatibility file, event schema, healthcheck, repair,
import, or facade module was changed.

The closed `2026-05-09-01-compatibility-surface-cleanup` terminal hold is not
deprecation, migration, Cabal exposure, or removal approval. Internal import
migration and preferred-import guidance are evidence only.

### Command Log

Active inputs and scope:

- `git status --short --branch --untracked-files=all`: branch
  `orchestrator/round-081-cabal-exposure-decision`; before writing this file,
  only `orchestrator/rounds/round-081/plan.md` and
  `orchestrator/rounds/round-081/selection.md` were untracked.
- Loaded `orchestrator/roles/implementer.md`, `orchestrator/state.json`,
  `orchestrator/project-contract.md`, active `verification.md`, active
  `retry-subloop.md`, `orchestrator/rounds/round-081/selection.md`, and
  `orchestrator/rounds/round-081/plan.md`.
- Loaded dependency evidence from rounds 075-080:
  `orchestrator/rounds/round-075/implementation-notes.md`,
  `orchestrator/rounds/round-076/implementation-notes.md`,
  `orchestrator/rounds/round-077/implementation-notes.md`,
  `orchestrator/rounds/round-078/implementation-notes.md`,
  `orchestrator/rounds/round-079/implementation-notes.md`,
  `orchestrator/rounds/round-080/deprecation-readiness-decision.md`, and
  reviews for rounds 077-080.

Focused evidence commands:

- Selected facade import inventory:
  `rg --pcre2 -n "^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(EventLog|Permission))(?!\.)(\b| +as +| *$| +qualified| +\()" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
  plus per-surface scans.
- Replacement import and exposure inventory:
  `rg` scans for `Workflow.Agent.Codex.Client`, `Workflow.Agent.Codex.Transport`,
  `Workflow.Agent.Ids`, `Workflow.GitHub.Ids`, `Workflow.EventLog.Core`,
  `Workflow.EventLog.File.Core`, `Workflow.EventLog.Commit.Core`, and
  `Workflow.Permission.Core`.
- Cabal/package evidence:
  `rg -n "^  exposed-modules:|CodexWatcher\.(...)" moifold.cabal agent-workflow-*/agent-workflow-*.cabal examples/workflow-package-consumer/workflow-package-consumer.cabal`,
  `rg -n "build-depends:|agent-workflow-core|agent-workflow-codex|agent-workflow-github" ...`,
  and `rg -n "^executable|^library|^test-suite|other-modules:|exposed-modules:" moifold.cabal`.
- Facade and replacement definitions were read with the `sed` commands from the
  round plan.
- Docs, public wording, and Haddock:
  `find docs -path '*dist*' -prune -o -type f \( -iname '*.html' -o -iname '*.txt' -o -iname '*haddock*' \) -print | sort`,
  docs/source deprecation scans, and `cabal haddock all`.
- Downstream/operator inventory:
  local `rg` scans over examples, package candidates, root/docs, and Cabal
  files; `gh auth status`; owner-scoped GitHub code search for each selected
  facade.
- Behavior-protection scans:
  app-server protocol/failure formatting, identifier parsing/rendering,
  event-log/golden/replay/repair, and permission/phase-validation scans from
  the plan.

### Dependency Evidence

| Round | Evidence carried forward |
| --- | --- |
| `round-075` | Artifact-only inventory found `AppServerClient` at 28 imports, `Core.Ids` at 65 imports, `Workflow.EventLog` at 3 imports, and `Workflow.Permission` at 1 import. It did not approve migration, deprecation, Cabal changes, or removal. |
| `round-076` | Classified `AppServerClient` and `Core.Ids` as pure reexport facades; classified `Workflow.EventLog` and `Workflow.Permission` as mixed moifold bridge surfaces. |
| `round-077` | Approved a narrow behavior-neutral `AppServerClient` internal import migration. `cabal test watcher-core-test`, `cabal build all`, and `git diff --check` passed. The facade and Cabal exposure stayed live. |
| `round-078` | Approved a narrow behavior-neutral `Core.Ids` split-import migration. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` passed. `app/Main.hs` remained blocked by executable package-boundary concerns. |
| `round-079` | Approved an artifact-only hold for `Workflow.EventLog` and `Workflow.Permission`, carrying forward mixed-surface, old-log/golden, public API, and permission/phase-validation blockers. |
| `round-080` | Approved artifact-only public deprecation `defer` for all four selected facades. It explicitly did not approve deprecation pragmas, public deprecation wording, Cabal exposure changes, or removal. |

### Current Import Inventory

Exact selected-facade imports at current HEAD:

| Surface | Count | Current import sites |
| --- | ---: | --- |
| `CodexWatcher.AppServerClient` | 13 | `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `test/Main.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Turn/Classifier/Common.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`, `src/CodexWatcher/Cli/Command/Observe.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` |
| `CodexWatcher.Core.Ids` | 35 | `app/Main.hs`, `test/RuntimeSpec.hs`, `test/CliSpec.hs`, `test/Main.hs`, `src/CodexWatcher/StateMachine.hs`, `src/CodexWatcher/EffectInterpreter.hs`, `src/CodexWatcher/GoldenReplay.hs`, `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/Effects.hs`, `src/CodexWatcher/Cli/RuntimeConfig.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Core/State.hs`, `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Domain/PrReview/Protocol.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/PrReview/Watcher.hs`, `src/CodexWatcher/Cli/Command/RunnerGuard.hs`, `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, `src/CodexWatcher/Cli/Parser/Observe.hs`, `src/CodexWatcher/Domain/IssueImplement/Loop.hs`, `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`, `src/CodexWatcher/Domain/PrReview/Loop.hs`, `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Workflow/Moifold/PrReview.hs`, `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`, `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`, `src/CodexWatcher/EventLog/Types.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`, `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/EventLog/Replay.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`, `src/CodexWatcher/EventLogRepair.hs` |
| `CodexWatcher.Workflow.EventLog` | 3 | `src/CodexWatcher/Daemon.hs`, `test/Main.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs` |
| `CodexWatcher.Workflow.Permission` | 1 | `test/Main.hs` |

No exact selected-facade imports were found under `examples`,
`agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github`.

### Replacement And Cabal Exposure Evidence

Replacement import counts at current HEAD:

| Replacement area | Count | Evidence |
| --- | ---: | --- |
| `Workflow.Agent.Codex.Client` / `Transport` | 22 | Direct imports exist in `agent-workflow-codex`, migrated moifold source/test files, and the `AppServerClient` compatibility facade. |
| `Workflow.Agent.Ids` / `Workflow.GitHub.Ids` | 42 | Direct imports exist in package candidates, examples, migrated moifold source/test files, and the `Core.Ids` compatibility facade. |
| `Workflow.EventLog.Core` / `File.Core` / `Commit.Core` | 8 | Direct imports exist in `agent-workflow-core`, `test/Main.hs`, `src/CodexWatcher/Daemon.hs`, `src/CodexWatcher/EventLog/File.hs`, `src/CodexWatcher/Workflow/DocsMigration.hs`, and the `Workflow.EventLog` facade. |
| `Workflow.Permission.Core` | 1 | The direct import is the `Workflow.Permission` facade itself. |

Cabal exposure at current HEAD:

| Package descriptor | Selected/replacement modules exposed |
| --- | --- |
| `moifold.cabal` | Exposes all four selected facades: `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`. |
| `agent-workflow-codex/agent-workflow-codex.cabal` | Exposes `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Transport`, and `CodexWatcher.Workflow.Agent.Ids`. |
| `agent-workflow-github/agent-workflow-github.cabal` | Exposes `CodexWatcher.Workflow.GitHub.Ids`. |
| `agent-workflow-core/agent-workflow-core.cabal` | Exposes `CodexWatcher.Workflow.EventLog.Commit.Core`, `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, and `CodexWatcher.Workflow.Permission.Core`. |

`moifold.cabal` has a main `library`, an `executable moifold`, and a
`watcher-core-test` test suite. `moifold` depends on the split packages, but
round-078 already showed `app/Main.hs` cannot switch from `Core.Ids` to
`Workflow.GitHub.Ids` without a package descriptor change, which remains out of
scope for this round.

`test/Main.hs` still contains package-boundary and exposed-module inventory
checks, including `workflowMoifoldCabalLibraryDoesNotReexportAdapters`.

### Facade Definitions And Owners

| Surface | Current shape | Behavior owner evidence |
| --- | --- | --- |
| `CodexWatcher.AppServerClient` | Pure reexport facade. | Reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; owns no local definitions. App-server parsing/failure behavior is in `Client`; websocket transport, endpoint sessions, timeouts, and endpoint-backed interpreters are in `Transport`. |
| `CodexWatcher.Core.Ids` | Pure reexport facade. | Reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; owns no local definitions. Agent ids cover `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId`; GitHub ids cover repo, issue, PR, branch, review-thread, and commit identifiers. |
| `CodexWatcher.Workflow.EventLog` | Mixed moifold bridge. | Reexports generic replay/audit helpers, but locally defines `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents` over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`. |
| `CodexWatcher.Workflow.Permission` | Mixed moifold bridge. | Reexports reusable permission core APIs, but also exposes concrete `PhaseActionValidationError`, `formatPhaseActionValidationError`, `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and `validateWorkflowEffectPlan` over moifold state/effect/spec validation. |

### Docs, Haddock, And Public Wording

- No checked-in generated docs/Haddock HTML or text files were found under
  `docs`.
- Selected facade source files contain no `DEPRECATED` pragma, `Deprecated:`
  note, `compatibility-only` wording, or preferred-import wording.
- Existing docs describe the facades as compatibility surfaces and document
  preferred replacement imports. `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  explicitly says preferred-import policy is not a deprecation pragma, warning
  policy, Cabal descriptor migration, or removal approval.
- Some policy tables still mention older round-056 counts. Current round-081
  evidence supersedes those counts for this decision: 13, 35, 3, and 1 exact
  selected-facade imports.
- `cabal haddock all`: passed. Haddock generated docs for
  `agent-workflow-github`, `agent-workflow-core`, `agent-workflow-codex`, and
  `moifold` under `dist-newstyle`. Existing missing-documentation and
  unresolved-link warnings remain, including selected-surface-adjacent
  packages/modules. Passing Haddock proves the current exposed modules generate,
  but it is not removal approval and does not create public deprecation
  alignment.

### Downstream And Operator Inventory

Local inventory:

- No exact selected-facade imports under `examples`,
  `agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github`.
- Broad local scans over examples/package candidates/docs report replacement
  modules such as `Workflow.EventLog.Core`, `Workflow.EventLog.File.Core`,
  `Workflow.EventLog.Commit.Core`, and `Workflow.Permission.Core`.
- Cabal scans show selected facades only in `moifold.cabal`; package candidates
  expose replacement modules.

GitHub owner-scoped code search:

- `gh auth status`: authenticated as `soulomoon`.
- `gh search code "CodexWatcher.AppServerClient" --owner soulomoon --limit 100 --json repository,path --jq 'length'`: 31.
- `gh search code "CodexWatcher.Core.Ids" --owner soulomoon --limit 100 --json repository,path --jq 'length'`: 61.
- `gh search code "CodexWatcher.Workflow.EventLog" --owner soulomoon --limit 100 --json repository,path --jq 'length'`: 0.
- `gh search code "CodexWatcher.Workflow.Permission" --owner soulomoon --limit 100 --json repository,path --jq 'length'`: 0.
- Sample `AppServerClient` and `Core.Ids` results are in `soulomoon/moifold`.

This search is useful current owner-scoped evidence. It is not complete external
downstream proof, and the indexed public repo can lag or differ from this local
round worktree.

### Behavior Protection Evidence

- `AppServerClient`: scans found app-server protocol/client/transport code,
  app-server failure formatting, JSON-RPC decode/match handling, request-id
  mismatch handling, fallback materialization, timeouts, and tests in
  `test/AppServerSpec.hs`, `test/CliSpec.hs`, and `test/Main.hs`.
- `Core.Ids`: scans found parser/rendering and runtime-command protection for
  repo, branch, issue, PR, review-thread, commit, request, thread, and turn ids
  in `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`,
  `test/RuntimeSpec.hs`, and identifier-heavy `test/Main.hs`.
- `Workflow.EventLog`: scans found golden event-log type-field checks, golden
  replay fixtures, event-log repair properties, file-core line numbering and
  malformed-line formatting, detailed replay parity, transition/facade parity,
  DocsMigration replay parity, and failure-audit retry checks in
  `test/Main.hs`.
- `Workflow.Permission`: scans found phase-action validation acceptance and
  rejection, facade/state-machine parity, permission core checks,
  `moifoldPermissionPolicy` parity, DocsMigration permissions, PR-review indexed
  permissions, and mergeability permission parity in `test/Main.hs`.

These are protection points for later behavior-changing or exposure-changing
rounds. They were not rerun as `watcher-core-test` in this implementation pass
because no behavior, API, source, test, docs, or Cabal surface was changed.

### Decision Table

| Surface | Status | Cabal exposure decision | Blockers before any later exposed-module removal |
| --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | `defer` | Keep exposed for now. It is a pure reexport facade and direct replacement modules are exposed, but Cabal removal is not approved. | 13 local facade imports remain; owner-scoped GitHub search still finds 31 hits; downstream proof is owner-scoped only; no reviewer approval names this surface ready for exposed-module removal; docs/Haddock/source/Cabal do not carry a public deprecation/removal signal; app-server protocol/failure behavior would need a focused rerun in the exact removal slice. |
| `CodexWatcher.Core.Ids` | `defer` | Keep exposed for now. It is a pure reexport facade and split owner id modules are exposed, but Cabal removal is not approved. | 35 local facade imports remain, including `app/Main.hs`, tests, mixed users, runtime compatibility, event-log/repair, healthcheck, and `Workflow.Execution`; `app/Main.hs` has an executable/package descriptor blocker; owner-scoped GitHub search still finds 61 hits; parser/rendering behavior coverage has not been rerun for a Cabal removal slice; no reviewer approval names this surface ready for exposed-module removal. |
| `CodexWatcher.Workflow.EventLog` | `defer` | Keep exposed for now. Generic event-log replacement modules are exposed, but the selected facade remains a mixed moifold bridge. | The facade still owns concrete moifold helpers over `WatcherEvent`, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; 3 exact local imports remain; old-log/golden/replay behavior has not been rerun for an exposure-removal slice; docs/Haddock/Cabal do not align on removal; no reviewed split plan or exposed-module removal approval names this surface. |
| `CodexWatcher.Workflow.Permission` | `defer` | Keep exposed for now. `Workflow.Permission.Core` is exposed, but the selected facade remains a mixed moifold bridge. | The facade still exposes concrete moifold phase-validation helpers and state-machine error formatting; 1 exact local import remains in `test/Main.hs`; no reviewed public API/downstream decision proves those names can leave the exposed module set; permission/phase-validation behavior has not been rerun for a Cabal removal slice; no reviewer approval names this surface ready for exposed-module removal. |

### Final Decision

No selected facade is eligible for a later exact Cabal exposed-module removal
round on the evidence currently available in round 081.

All four selected surfaces are `defer`. The lawful current action is to keep
them exposed in `moifold.cabal` and carry the named blockers forward. Missing
downstream, behavior, docs/Haddock, package-boundary, deprecation-readiness, or
reviewer evidence remains a blocker, not removal approval.

`cabal test watcher-core-test` and `cabal build all` were not run in this round
because the only implementation write is this round-local evidence artifact and
no source, test, package descriptor, public API, Cabal exposure, docs, behavior,
runtime compatibility, roadmap, or state surface changed. `cabal haddock all`
was run because the round plan required Haddock-facing evidence.
