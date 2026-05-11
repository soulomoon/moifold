## Scope

Round: `round-105-appserverclient-import-convergence-readiness`
Roadmap: `2026-05-11-00-highest-value-cleanup`, `rev-001`
Milestone: `milestone-003-import-convergence-package-boundaries`
Direction: `direction-010-appserverclient-import-convergence`

This is readiness evidence only. It does not change imports, source, tests,
package descriptors, docs, fixtures, public APIs, app-server protocol,
endpoint parsing, session behavior, timeout behavior, fallback behavior,
command rendering, failure formatting, Cabal exposure, release status,
milestone status, or terminal completion status.

## Coordination Evidence

- `orchestrator/state.json` was re-read and points at active round
  `round-105`, branch
  `orchestrator/round-105-highest-value-cleanup-slice`, roadmap
  `2026-05-11-00-highest-value-cleanup` `rev-001`, and
  `worker_mode: none`.
- `orchestrator/rounds/round-105/selection.md` was re-read and selects
  artifact-only readiness evidence for
  `CodexWatcher.AppServerClient`.
- `orchestrator/project-contract.md` was re-read. The relevant durable
  invariant is that public compatibility facades remain available until a
  selected round proves safe removal with import, build, and behavior
  coverage.
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  was re-read. Artifact-only rounds may skip package build/test only when
  changed-path evidence proves no production, test, descriptor, runtime,
  public API, fixture, docs, or behavior surface changed.
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  records milestone `milestone-003-import-convergence-package-boundaries` as
  `in-progress` and direction
  `direction-010-appserverclient-import-convergence` as requiring a current
  import scan plus focused app-server behavior evidence.
- `orchestrator/rounds/round-097/facade-import-scan-refresh.md` was re-read
  as the prior accepted facade scan. Its `AppServerClient` count was 19
  imports: 12 under `src`, 7 under `test`, none under `app` or standalone
  package candidates.
- Round 104 review and merge artifacts were checked. They approved only the
  `Workflow.EventLog` and `Workflow.Permission` readiness slice and kept
  milestone 003 in progress for later directions.

Starting scope checks:

```sh
git status --short --branch
git diff --name-status
```

Result: tracked diff at start was the pre-existing controller-owned
`orchestrator/state.json`; `orchestrator/rounds/round-105/` was untracked.
This implementation writes only round-local artifacts in that directory.

## Compatibility Facade Shape

Command:

```sh
sed -n '1,120p' src/CodexWatcher/AppServerClient.hs
```

Result:

```haskell
module CodexWatcher.AppServerClient
  ( module CodexWatcher.Workflow.Agent.Codex.Client
  , module CodexWatcher.Workflow.Agent.Codex.Transport
  ) where

import CodexWatcher.Workflow.Agent.Codex.Client
import CodexWatcher.Workflow.Agent.Codex.Transport
```

`CodexWatcher.AppServerClient` remains a public compatibility reexport of
`CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport`. The facade was not edited.

## Scan Commands

Exact facade import scan:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github
```

Broader reference scan:

```sh
rg -n 'CodexWatcher\.AppServerClient([[:space:]]|$|\.|\(|")' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  docs examples scripts moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Direct-owner exposure and import scan:

```sh
rg -n 'CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)|CodexWatcher\.AppServerClient|exposed-modules:' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

## Exact Import Counts

| Area | Exact imports | Importing files |
| --- | ---: | ---: |
| `src` | 12 | 12 |
| `app` | 0 | 0 |
| `test` | 7 | 7 |
| `agent-workflow-core` | 0 | 0 |
| `agent-workflow-codex` | 0 | 0 |
| `agent-workflow-github` | 0 | 0 |

Every live exact import:

| File | Import list |
| --- | --- |
| `src/CodexWatcher/RunnerGuard.hs` | Explicit list: `AppServerEndpoint`, `AppServerTurn (..)`, `defaultAppServerClientOptions`, `formatAppServerClientFailure`, `latestTurnById`, `parseThreadReadTurns`, `parseTurnStartTurnId`, `sendOneAppServerRequest`, `startThreadWithEndpoint`, `threadReadMaterializationPending`, `threadSystemError`. |
| `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` | Open import. Observed use is `AppServerTurn` with turn-completion classification helpers. |
| `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` | Open import. Observed use includes `AppServerEndpoint`, `startThreadWithEndpoint`, `defaultAppServerClientOptions`, thread-start options, and `formatAppServerClientFailure`. |
| `src/CodexWatcher/Healthcheck.hs` | Open import. Observed use includes `AppServerEndpoint`, `sendOneAppServerRequest`, timeout options, thread-read parsing, `AppServerTurn` fields, and `formatAppServerClientFailure`. |
| `src/CodexWatcher/AutomaticLoop/Runner.hs` | Open import. Observed use is `appServerInterpreterFromEndpoint` with `defaultAppServerClientOptions` for loop execution. |
| `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` | Open import. Observed use is `AppServerTurn` with shared turn-completion classification. |
| `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` | Open import. Observed use is app-server turn classification and request/result handling through planned app-server actions. |
| `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` | Open import. Observed use is `AppServerTurn` with plan, implementation, and final-review turn classification. |
| `src/CodexWatcher/Turn/Classifier/Common.hs` | Open import. Observed use is `AppServerTurn` and `appServerTurnStatus` / `appServerTurnOutput`. |
| `src/CodexWatcher/Cli/Command/AppServerProbe.hs` | Explicit list: `AppServerClientOptions (..)`, `defaultAppServerClientOptions`, `formatAppServerClientFailure`, `parseThreadStartThreadId`, `parseTurnStartTurnId`, `sendOneAppServerRequest`. |
| `src/CodexWatcher/Cli/Command/IssueFanout.hs` | Open import. Observed use includes `AppServerEndpoint`, `startThreadWithEndpoint`, `defaultAppServerClientOptions`, and `formatAppServerClientFailure` for child launch preparation. |
| `src/CodexWatcher/Cli/Command/Observe.hs` | Open import. Observed use is `appServerInterpreterFromEndpoint`, `defaultAppServerClientOptions`, and `AppServerInterpreter` fallback for dry-run observation. |
| `test/Main.hs` | Open import. Broad watcher-core assertions cover app-server protocol, client parsing, fallback, turn classification, workflow execution, and automatic-loop behavior. |
| `test/TestSupport/Workflow.hs` | Open import. Shared workflow test support for fake app-server/interpreter behavior. |
| `test/WorkflowAgentSpec.hs` | Open import. Workflow-agent and import-topology coverage. |
| `test/WorkflowDocsMigrationSpec.hs` | Open import. DocsMigration workflow and agent-role classification coverage. |
| `test/WorkflowEventLogSpec.hs` | Open import. Event-log, app-server protocol/client, and turn-classifier coverage. |
| `test/WorkflowExecutionSpec.hs` | Open import. Workflow execution and app-server interpreter coverage. |
| `test/WorkflowIndexedSpec.hs` | Open import. Indexed workflow and agent-turn evidence. |

## Broader Reference Classification

- Live imports: the 19 import lines listed above.
- Package exposure: `moifold.cabal:33` exposes
  `CodexWatcher.AppServerClient`.
- Facade module declaration: `src/CodexWatcher/AppServerClient.hs` declares
  the compatibility module and imports the two direct-owner modules.
- Test import-policy assertions: `test/BoundaryPolicySpec.hs` references
  `CodexWatcher.AppServerClient` in the moifold module inventory, standalone
  package boundary forbidden-import lists, and compatibility facade shape
  checks.
- Standalone package candidates: no `CodexWatcher.AppServerClient` references
  were found under `agent-workflow-core`, `agent-workflow-codex`, or
  `agent-workflow-github`.
- Documentation/policy references:
  `docs/agentic-workflow-framework/package-extraction-readiness.md`,
  `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
  `docs/agentic-workflow-framework/release-candidate-bundle.md`,
  `docs/agentic-workflow-framework/release-notes.md`, and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
  These references describe compatibility, package-boundary readiness, release
  bundle status, or deprecation policy; they do not approve migration,
  deprecation, Cabal exposure removal, facade removal, release/publication,
  milestone completion, or terminal completion.
- `examples` and `scripts`: no `CodexWatcher.AppServerClient` references were
  found.

## Direct-Owner Exposure And Imports

- `moifold.cabal` still exposes `CodexWatcher.AppServerClient`.
- `agent-workflow-codex/agent-workflow-codex.cabal` exposes
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex.hs`,
  `agent-workflow-codex/src/CodexWatcher/Workflow/Agent.hs`, and
  `agent-workflow-codex/src/CodexWatcher/Workflow/Observation/Agent.hs`
  import the direct owner client module.
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  imports the direct owner client module and defines the direct owner transport
  module.
- `agent-workflow-codex/README.md` documents the direct owner client and
  transport modules.
- Direct-owner imports also exist in the main package and tests:
  `src/CodexWatcher/DaemonLoop/Types.hs`, `src/CodexWatcher/Failure.hs`,
  `src/CodexWatcher/Healthcheck/Types.hs`, `src/CodexWatcher/DaemonLoop.hs`,
  `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`,
  `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`,
  `src/CodexWatcher/Cli/Parser/Common.hs`,
  `src/CodexWatcher/Workflow/DocsMigration.hs`,
  `src/CodexWatcher/Cli/Command/Service.hs`,
  `src/CodexWatcher/Cli/Types.hs`,
  `src/CodexWatcher/Cli/Command/RunnerGuard.hs`,
  `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`,
  `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`,
  `test/CliSpec.hs`, and `test/AppServerSpec.hs`.

This proves the direct owner modules are available and already used, but it
does not prove any remaining facade importer is safe to migrate without the
focused gates below.

## Source Importer Classification

| File | Classification | Required gates before later migration | Smallest later candidate |
| --- | --- | --- | --- |
| `src/CodexWatcher/RunnerGuard.hs` | `source blocker` | Endpoint-backed thread launch/read, app-server request/response parsing, session handling through `sendOneAppServerRequest`, thread-read materialization fallback, turn-start parsing, `threadSystemError`, turn-completion classification, failure formatting, repair prompt command text. | Narrow explicit import-list split is possible, but no migration until runner-guard repair and active-turn behavior checks are selected. |
| `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` | `turn-classifier source candidate` | `AppServerTurn` success, failure, incomplete, missing/blank output, structured reviewer JSON, and prior/new findings classification. | Whole-file import can later move to `Client (AppServerTurn)` only after PR-review turn-classifier assertions are preserved. |
| `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` | `endpoint/session source candidate` plus `command-rendering/failure-formatting source candidate` | Endpoint launch, two-thread session initialization, request ids, thread-start parsing, dry-run child command rendering, runtime status manifest, and `formatAppServerClientFailure`. | Narrow import-list change only after launch lifecycle, dry-run command text, and failure text gates. |
| `src/CodexWatcher/Healthcheck.hs` | `timeout/fallback source candidate` plus `endpoint/session source candidate` | Healthcheck endpoint optionality, fixed 5s response timeout, thread-read request shape, parseThreadReadTurns, system-error/latest-turn fields, skipped/fallback healthcheck output, and failure formatting. | No migration until healthcheck thread inspection, timeout, skipped-output, and failure-format checks are selected. |
| `src/CodexWatcher/AutomaticLoop/Runner.hs` | `timeout/fallback source candidate` | Loop interpreter construction from endpoint, default client options, automatic-loop retry/fallback policy, startup-thread refresh interactions, and failure classification. | Whole-file import may be small, but only after automatic-loop execute/dry-run and retry/fallback assertions. |
| `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` | `turn-classifier source candidate` | Planning turn running, failed, completed-without-output, structured complete/blocked/incomplete, planning graph, and issue/subissue request parsing. | Whole-file import can later move to `Client (AppServerTurn)` after issue-planning classifier coverage. |
| `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` | `endpoint/session source candidate` plus `turn-classifier source candidate` | Planner-thread initialization, request id progression, dry-run synthetic planner thread, planned app-server request/result behavior, active-turn reads, systemError retry, and command failure formatting for snapshot commands. | No migration until planning loop app-server action and retry behavior gates are selected. |
| `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` | `turn-classifier source candidate` | Plan, implementation, and final-review `AppServerTurn` classifications for complete, incomplete, failed, missing-output, malformed JSON, expected commit, PR, and reviewer-thread cases. | Whole-file import can later move to `Client (AppServerTurn)` after issue-implement classifier assertions. |
| `src/CodexWatcher/Turn/Classifier/Common.hs` | `turn-classifier source candidate` | `AppServerTurn` status normalization, output propagation, failure reason fallback, running/completed/failed status sets, structured outcome parsing, and missing-output behavior. | Smallest and safest candidate: whole-file import to `Client (AppServerTurn)` after common turn-classifier tests. |
| `src/CodexWatcher/Cli/Command/AppServerProbe.hs` | `endpoint/session source candidate` plus `timeout/fallback source candidate` | Initialize, thread/read, thread/start, turn/start request/response parsing, fixed 5s timeout, endpoint options, smoke-thread behavior, smoke-turn behavior, and failure formatting. | Narrow explicit import-list change after probe CLI parser and live/request-shape tests. |
| `src/CodexWatcher/Cli/Command/IssueFanout.hs` | `endpoint/session source candidate` plus `command-rendering/failure-formatting source candidate` | Child implementer thread launch, request ids, optional endpoint behavior, dry-run child command rendering, runtime command retries, ready/completion detection, and app-server failure formatting. | No migration until issue fanout launch lifecycle and dry-run command text gates. |
| `src/CodexWatcher/Cli/Command/Observe.hs` | `timeout/fallback source candidate` | Execute-mode endpoint requirement, interpreter construction from endpoint/default options, dry-run `AppServerInterpreter` fallback, and daemon failure formatting through observation execution. | Whole-file import may be small after observe execute/dry-run interpreter coverage. |

## Test Importer Classification

| File | Classification | Keep reason / later gate |
| --- | --- | --- |
| `test/Main.hs` | `test-policy evidence` | Preserves broad app-server protocol/client parsing, materialization fallback, turn-classifier, effect-interpreter, automatic-loop, runner-guard, healthcheck-adjacent, command rendering, and workflow execution coverage. Later migration requires assertion-preservation over the named properties, not import cleanup alone. |
| `test/TestSupport/Workflow.hs` | `test-policy evidence` | Shared workflow fake executor/interpreter support. It should remain stable while later source migrations use it as evidence for app-server request and workflow execution behavior. |
| `test/WorkflowAgentSpec.hs` | `test-policy evidence` | Workflow-agent and import-topology evidence; later cleanup can only move imports after confirming no assertion depends on the compatibility facade import. |
| `test/WorkflowDocsMigrationSpec.hs` | `test-policy evidence` | DocsMigration workflow coverage, including `AppServerTurn` classification of docs-migration agent-role behavior and indexed workflow evidence. |
| `test/WorkflowEventLogSpec.hs` | `test-policy evidence` | Event-log workflow coverage plus app-server protocol/client, turn-classifier, fallback, failure-classification, and runtime command evidence. |
| `test/WorkflowExecutionSpec.hs` | `test-policy evidence` | Workflow execution coverage around app-server interpreter actions and effect execution. |
| `test/WorkflowIndexedSpec.hs` | `test-policy evidence` | Indexed workflow coverage with agent turn references and transition/effect evidence. |

These tests may contain later direct-owner import candidates, but only under a
focused assertion-preservation gate. They should not be mechanically migrated
as part of source convergence.

## Public Exposure And Policy Evidence

- `moifold.cabal` exposes `CodexWatcher.AppServerClient`.
- `test/BoundaryPolicySpec.hs` asserts the facade remains in the moifold
  module inventory, forbids standalone package candidates from importing it,
  lists direct owner modules in the codex standalone package exposure
  inventory, and checks that the compatibility source imports both direct
  owner modules without owning transport internals.
- `agent-workflow-codex` exposes and documents the direct owner modules.
- No standalone package candidate imports the compatibility facade.
- Documentation currently treats `CodexWatcher.AppServerClient` as a
  supported compatibility facade and says direct owner imports are preferred
  for reusable Codex adapter users.

This evidence does not approve public deprecation, Cabal exposure removal,
facade removal, release/publication, milestone completion, or terminal
completion.

## Smallest Later Migration Candidates

- Smallest turn-classifier candidates:
  `src/CodexWatcher/Turn/Classifier/Common.hs`,
  `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`,
  `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`, and
  `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`. Each appears centered
  on `AppServerTurn`, but still needs focused classifier tests before import
  movement.
- Smallest explicit-import candidates:
  `src/CodexWatcher/Cli/Command/AppServerProbe.hs` and
  `src/CodexWatcher/RunnerGuard.hs` have explicit import lists, but both touch
  protocol parsing, endpoint/session behavior, timeout or fallback behavior,
  and failure formatting, so they are not safe mechanical cleanups.
- Higher-risk source candidates:
  `src/CodexWatcher/Healthcheck.hs`,
  `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`,
  `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`,
  `src/CodexWatcher/Cli/Command/IssueFanout.hs`,
  `src/CodexWatcher/AutomaticLoop/Runner.hs`, and
  `src/CodexWatcher/Cli/Command/Observe.hs` should wait for selected behavior
  slices because they sit on endpoint/session initialization, fallback,
  command rendering, retry policy, or user-visible failure paths.

## Later Verification Gates

Before any later convergence, public exposure, Cabal exposure, deprecation, or
removal work, require the exact gates for the touched surface:

- Endpoint parser coverage for affected endpoint strings, host/port/path
  behavior, and thread ids.
- App-server protocol request/response parsing and rendering coverage for
  initialize, thread/read, thread/start, turn/start, and thread-name requests
  as applicable.
- Session initialization and existing-session handling coverage, including
  request id progression and synthetic dry-run thread ids.
- Command rendering and dry-run/request text stability for PR-review handoff,
  issue fanout, runner guard, and observe/probe paths as applicable.
- Timeout behavior coverage for probe, healthcheck, loop, and fallback paths.
- Fallback behavior coverage for unavailable app-server, materialization
  pending, failed turn reads, skipped healthcheck reports, dry-run
  interpreters, and loop retry policy.
- Failure-formatting coverage for user-visible
  `formatAppServerClientFailure`, daemon failure, command failure, and
  healthcheck failure text.
- Turn-classifier coverage for `AppServerTurn` success, failure, incomplete,
  still-running, unknown status, missing output, blank output, structured
  blocked/incomplete/complete output, and domain-specific JSON reports.
- Package descriptor, public API, docs/Haddock, downstream import, and
  test-policy evidence for any exact surface later moved, deprecated, or
  removed.

## Final Scope And Verification

Required checks:

```sh
test ! -e orchestrator/rounds/round-105/worker-plan.json
git diff -- src app test moifold.cabal cabal.project \
  agent-workflow-core agent-workflow-codex agent-workflow-github
git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
git diff --check
git diff --cached --check
git diff --no-index --check /dev/null orchestrator/rounds/round-105/appserverclient-import-convergence-readiness.md
git diff --no-index --check /dev/null orchestrator/rounds/round-105/implementation-notes.md
```

Package build/test was skipped because changed-path evidence is limited to
round-local orchestrator artifacts plus pre-existing controller-owned
`orchestrator/state.json`; there is no diff under `src`, `app`, `test`, package
descriptors, standalone package candidates, docs, fixtures, runtime files, or
public API surfaces.
