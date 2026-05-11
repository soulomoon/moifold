## Scope

Round: `round-110-runner-guard-appserverclient-gate-evidence`
Roadmap: `2026-05-11-00-highest-value-cleanup`, `rev-001`
Milestone: `milestone-003-import-convergence-package-boundaries`
Direction: `direction-010-appserverclient-import-convergence`

This is artifact-only readiness evidence for the remaining
`src/CodexWatcher/RunnerGuard.hs` importer of
`CodexWatcher.AppServerClient`. It does not change imports, source, tests,
package descriptors, fixtures, docs, public APIs, app-server protocol,
endpoint parsing, session behavior, timeout/fallback behavior, command
rendering, failure formatting, Cabal exposure, facade availability,
release/publication status, milestone status, or terminal completion status.

`CodexWatcher.AppServerClient` remains a public compatibility facade. This
artifact only evaluates whether a later `RunnerGuard.hs` import-only split to
direct owner modules is behaviorally gated enough to select.

## Inputs Reviewed

- `orchestrator/rounds/round-110/selection.md`: selects this serial,
  artifact-only gate-evidence round for `RunnerGuard.hs`.
- `orchestrator/rounds/round-110/plan.md`: requires symbol-to-owner mapping,
  existing behavior coverage inventory, gate matrix, and yes/no
  recommendation.
- `orchestrator/project-contract.md`: preserves public compatibility facades
  until a selected round proves safe removal with import, build, and behavior
  coverage; direct import convergence is not deprecation or removal approval.
- `orchestrator/state.json`: current state is `stage: "implement"`,
  `active_round_id: "round-110"`, `worker_mode: "none"`.
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`:
  direction 010 remains in progress; `RunnerGuard.hs` is one remaining source
  user after rounds 106-109 consumed lower-risk turn-classifier slices.
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`:
  artifact-only rounds may skip package build/test only with changed-path
  evidence proving no production, test, descriptor, runtime, public API,
  fixture, docs, or behavior surface changed.
- `orchestrator/rounds/round-105/appserverclient-import-convergence-readiness.md`:
  classifies `RunnerGuard.hs` as a source blocker requiring endpoint-backed
  thread launch/read, request/response parsing, session handling, fallback,
  turn-start parsing, `threadSystemError`, turn-completion classification,
  failure formatting, and repair prompt command text gates.

## Commands Run

```sh
pwd && git status --short && git rev-parse --show-toplevel
sed -n '1,220p' orchestrator/roles/implementer.md
sed -n '1,260p' orchestrator/rounds/round-110/selection.md
sed -n '1,320p' orchestrator/rounds/round-110/plan.md
sed -n '1,220p' orchestrator/project-contract.md
sed -n '1,180p' orchestrator/state.json
sed -n '760,930p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md
sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md
sed -n '1,260p' orchestrator/rounds/round-105/appserverclient-import-convergence-readiness.md
git diff --name-status
git ls-files --others --exclude-standard orchestrator/rounds/round-110
sed -n '1,120p' src/CodexWatcher/AppServerClient.hs
sed -n '1,320p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs
sed -n '1,320p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport)|exposed-modules:' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal
rg -n '^import[[:space:]]+CodexWatcher\.AppServerClient|AppServerEndpoint|AppServerTurn|defaultAppServerClientOptions|formatAppServerClientFailure|latestTurnById|parseThreadReadTurns|parseTurnStartTurnId|sendOneAppServerRequest|startThreadWithEndpoint|threadReadMaterializationPending|threadSystemError' src/CodexWatcher/RunnerGuard.hs
sed -n '1,260p' src/CodexWatcher/RunnerGuard.hs
sed -n '260,620p' src/CodexWatcher/RunnerGuard.hs
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.AppServerClient([[:space:]]|$|\()' src app test agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'RunnerGuard|runner guard|runner-guard|repair thread|thread-name/set|turn/start|stale|materialization|formatAppServerClientFailure|latestTurnById|threadSystemError' src test docs orchestrator/rounds/round-105
rg -n 'RunnerGuard|runner guard|runner-guard|runRunnerGuard|repair|stale|thread-name/set|turn/start|materialization|threadSystemError|latestTurnById|formatAppServerClientFailure' test src
rg -n 'describe|it|testCase|assert|shouldBe|shouldContain|shouldSatisfy|golden|fixture|AppServerTurn|parseThreadReadTurns|parseTurnStartTurnId' test
sed -n '3020,3180p' test/Main.hs
sed -n '1,180p' test/AppServerSpec.hs
sed -n '180,330p' test/AppServerSpec.hs
sed -n '680,730p' test/TestSupport/Workflow.hs
rg -n 'runnerGuardIgnoresMissingPidForCompletePlanning|runnerGuardRestartsMissingPidForIncompletePlanning|runnerGuardRestartsMissingPidForWaitingPlanning|runnerGuardRepairsInvalidPlanningEventLog|prop_appServerClient|threadNameSetRequest|thread-name/set|formatAppServerClientFailure|startRunnerGuardRepairThread' test/Main.hs test/AppServerSpec.hs test/TestSupport/Workflow.hs src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerProtocol.hs
rg --files | rg 'AppServerProtocol'
sed -n '7048,7070p' test/Main.hs
rg -n 'threadNameSetRequest|thread-name/set|threadReadRequest|turnStartRequest|threadStartRequest' agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs test/AppServerSpec.hs test/Main.hs
sed -n '1,170p' agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs
rg -n 'formatAppServerClientFailure|AppServerDecodeFailure|app-server JSON decode failed|app-server response id mismatch|app-server JSON-RPC error' test src agent-workflow-codex
nl -ba src/CodexWatcher/RunnerGuard.hs | sed -n '20,175p'
nl -ba src/CodexWatcher/RunnerGuard.hs | sed -n '318,370p'
nl -ba test/Main.hs | sed -n '3039,3168p'
nl -ba test/AppServerSpec.hs | sed -n '134,320p'
```

One command intentionally named a stale path from older source layout:
`src/CodexWatcher/AppServerProtocol.hs` does not exist. The live file is
`agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`; the follow-up
`rg --files | rg 'AppServerProtocol'` and source read used the live path.

## RunnerGuard Import And Symbol Map

Current import in `src/CodexWatcher/RunnerGuard.hs:23-35`:

| Imported symbol | RunnerGuard use sites | Behavior gates |
| --- | --- | --- |
| `AppServerEndpoint` | Config field `guardAppServerEndpoint` at lines 71-81; consumed by repair launch lines 149-151 and active-thread read line 320. | repair-thread launch; active-thread read. |
| `AppServerTurn (..)` | `checkTurn` argument and record fields at lines 347-360. | turn-completion classification; stale-turn decisions. |
| `defaultAppServerClientOptions` | Repair launch lines 149-151; `sendOrFail` lines 166-168; active-thread read line 320. | repair-thread launch; `thread-name/set`; `turn/start`; active-thread read; request/session behavior. |
| `formatAppServerClientFailure` | Repair launch failure line 148; turn-start parse line 163; request failure line 168; active-thread read failure line 323; parse failure line 331. | failure text; repair-thread launch; active-thread read; parse diagnostics. |
| `latestTurnById` | Active-turn lookup at line 333. | latest-turn lookup; stale/missing/materializing turn decisions. |
| `parseThreadReadTurns` | Thread-read parse at lines 329-331. | thread-read parsing; active-turn read; latest-turn lookup. |
| `parseTurnStartTurnId` | Repair turn id parse at line 163. | `turn/start`; repair-thread launch. |
| `sendOneAppServerRequest` | `sendOrFail` lines 166-168; active-thread read line 320. | `thread-name/set`; `turn/start`; active-thread read; request id progression; session/fallback behavior. |
| `startThreadWithEndpoint` | Repair thread start lines 147-153. | repair-thread launch; thread-start request/parse/session behavior. |
| `threadReadMaterializationPending` | Missing turn fallback branch at lines 334-341. | thread-read materialization pending; stale-turn decisions. |
| `threadSystemError` | Thread status check at lines 325-327. | `threadSystemError`; active-thread read. |

Adjacent protocol constructors are direct `CodexWatcher.AppServerProtocol`
imports, not `CodexWatcher.AppServerClient` imports, but they are relevant to
the selected gates:

- `threadNameSetRequest` at `RunnerGuard.hs:156` creates the repair thread
  name request with `RequestId 2`.
- `turnStartRequest` at `RunnerGuard.hs:159-162` creates the repair turn
  request with `RequestId 3`.
- `threadReadRequest` at `RunnerGuard.hs:320` creates the active-thread read
  with `RequestId 1` and `includeTurns = True`.

## Direct Owner Map

The compatibility facade is unchanged:

```haskell
module CodexWatcher.AppServerClient
  ( module CodexWatcher.Workflow.Agent.Codex.Client
  , module CodexWatcher.Workflow.Agent.Codex.Transport
  ) where
```

Package exposure is unchanged: `moifold.cabal` exposes
`CodexWatcher.AppServerClient`; `agent-workflow-codex.cabal` exposes
`CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport`.

| RunnerGuard symbol | Direct owner module |
| --- | --- |
| `AppServerTurn (..)` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `formatAppServerClientFailure` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `latestTurnById` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseThreadReadTurns` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseTurnStartTurnId` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `threadReadMaterializationPending` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `threadSystemError` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `AppServerEndpoint` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `defaultAppServerClientOptions` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `sendOneAppServerRequest` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `startThreadWithEndpoint` | `CodexWatcher.Workflow.Agent.Codex.Transport` |

The later mechanical split, if selected after coverage, would need both direct
owner imports. It is not a client-only move because `RunnerGuard.hs` consumes
endpoint/session/transport functions directly.

## Existing Behavior Coverage

Focused existing `RunnerGuard` assertions in `test/Main.hs`:

- `runnerGuardIgnoresMissingPidForCompletePlanning` at lines 3039-3068:
  verifies terminal planning event logs short-circuit before missing PID.
- `runnerGuardRestartsMissingPidForIncompletePlanning` at lines 3070-3098:
  verifies incomplete planning plus missing PID returns `RestartWatcher`.
- `runnerGuardRestartsMissingPidForWaitingPlanning` at lines 3100-3132:
  verifies waiting-for-ready-issues planning plus missing PID returns
  `RestartWatcher`.
- `runnerGuardRepairsInvalidPlanningEventLog` at lines 3134-3166: verifies an
  invalid planning event log returns `LaunchRepairThread`.

Those tests exercise runner-guard state/action selection, but they do not
reach `startRunnerGuardRepairThread`, do not send app-server requests, do not
read active app-server turns, and do not assert app-server failure text in
runner-guard problem details.

Generic app-server/client assertions in `test/AppServerSpec.hs`:

- Session/request id coverage: `prop_appServerClientInitializesSingleRequestSessions`
  checks `thread/read` request `RequestId 4` is wrapped after initialize
  `RequestId 0` at lines 134-140.
- `threadSystemError`: `prop_appServerClientDetectsSystemErrorThreadStatus`
  checks nested `thread.status.type = systemError` at lines 142-158.
- JSON-RPC success/notification/mismatch/error parsing at lines 160-197.
- Materialization fallback request and marker coverage at lines 199-216.
- Thread-read parsing, latest-turn selection, and structured output extraction
  at lines 224-276.
- `parseTurnStartTurnId` and malformed turn-start coverage at lines 278-287.
- `parseThreadStartThreadId` and malformed thread-start coverage at lines
  289-298.
- `startThreadWithInterpreter` thread-start request shape and parse coverage
  at lines 300-313.
- Nested thread-read parse coverage begins at lines 315-320.

Protocol assertions in `test/AppServerSpec.hs` also check generic
`thread/start`, `turn/start`, and `thread/read` request construction, but no
test asserts `RunnerGuard` sends its exact repair sequence:
`thread/start` with `RequestId 1`, `thread/name/set` with `RequestId 2`,
`turn/start` with `RequestId 3`, then parses and returns the repair thread and
turn ids.

No direct focused test was found for:

- `startRunnerGuardRepairThread` request ordering, request ids, thread name,
  repair prompt, or formatted failure propagation.
- `checkRunnerGuard` on an active-turn replay state with live app-server
  `thread/read` response branches.
- RunnerGuard-specific handling of materialization-pending reads,
  `threadSystemError`, missing active turn, failed turn, completed-without
  output, blank output, or completed-but-unobserved output.
- User-visible `formatAppServerClientFailure` text embedded in RunnerGuard
  problem details.

## Gate Matrix

| Gate | RunnerGuard evidence | AppServerClient symbols | Direct owners | Existing coverage | Status | Risk before later split |
| --- | --- | --- | --- | --- | --- | --- |
| repair-thread launch | `startRunnerGuardRepairThread` calls `startThreadWithEndpoint` with endpoint, defaults, `RequestId 1`, and thread-start options at `RunnerGuard.hs:145-153`. | `AppServerEndpoint`, `defaultAppServerClientOptions`, `formatAppServerClientFailure`, `startThreadWithEndpoint` | Transport plus Client formatting | Generic `startThreadWithInterpreter` coverage exists in `test/AppServerSpec.hs:300-313`; no endpoint-backed or RunnerGuard-specific launch test. | incidental | A split could compile while losing the intended transport owner import or masking request/session assumptions for the actual RunnerGuard launch path. |
| `thread-name/set` | `threadNameSetRequest (RequestId 2)` is sent through `sendOrFail` at `RunnerGuard.hs:154-168`. | `sendOneAppServerRequest`, `defaultAppServerClientOptions`, `formatAppServerClientFailure` | Transport plus Client formatting | Protocol source defines `thread/name/set`; no test match for `threadNameSetRequest` beyond source scan, and no RunnerGuard sequence test. | missing | The only RunnerGuard-specific named-thread behavior is unprotected; import split would not prove the repair worker remains discoverable by name. |
| `turn/start` | `turnStartRequest (RequestId 3)` starts the repair turn, then `parseTurnStartTurnId` extracts the returned turn id at `RunnerGuard.hs:157-164`. | `sendOneAppServerRequest`, `parseTurnStartTurnId`, `formatAppServerClientFailure`, defaults | Transport plus Client | Generic request construction and parse coverage exists in `test/AppServerSpec.hs:97-123` and `278-287`; no RunnerGuard repair prompt or request-id test. | incidental | A split could leave repair prompt/request behavior apparently unchanged without a focused assertion on the actual repair turn. |
| request id progression | Repair path uses request ids 1, 2, 3 at `RunnerGuard.hs:152`, `156`, `160`; active-thread read uses `RequestId 1` at `RunnerGuard.hs:320`. | `startThreadWithEndpoint`, `sendOneAppServerRequest` | Transport | Generic session test covers initialize id 0 plus request id preservation at `test/AppServerSpec.hs:134-140`; no RunnerGuard request-id progression test. | missing | Request ordering/id regressions in RunnerGuard could pass generic app-server tests. |
| active-thread read | `checkActiveTurn` sends `threadReadRequest (RequestId 1) activeThreadId True` via `sendOneAppServerRequest` at `RunnerGuard.hs:318-323`. | `AppServerEndpoint`, `defaultAppServerClientOptions`, `sendOneAppServerRequest`, `formatAppServerClientFailure` | Transport plus Client formatting | Generic thread-read request construction and session coverage exists; no `checkRunnerGuard` active-turn test with fake/live app-server response. | missing | The highest-risk RunnerGuard behavior path is untested; later import-only split would rely only on parser unit tests, not guard policy. |
| thread-read materialization pending | Missing active turn plus `threadReadMaterializationPending value` triggers a stale-problem branch at `RunnerGuard.hs:333-341`. | `threadReadMaterializationPending`, `latestTurnById`, `parseThreadReadTurns` | Client | Generic marker detection and fallback request coverage exists at `test/AppServerSpec.hs:199-216`; no RunnerGuard branch assertion. | incidental | RunnerGuard could change materializing/missing-turn classification without generic fallback tests failing. |
| `threadSystemError` | `checkActiveTurn` converts systemError status to a repair problem at `RunnerGuard.hs:325-327`. | `threadSystemError` | Client | Generic nested status parsing coverage at `test/AppServerSpec.hs:142-158`; no RunnerGuard repair-problem details assertion. | incidental | Generic parser stays covered, but RunnerGuard action/summary/detail contract is not protected. |
| latest-turn lookup | `latestTurnById activeTurn.activeTurnId turns` selects the active turn at `RunnerGuard.hs:333-345`. | `latestTurnById`, `parseThreadReadTurns`, `AppServerTurn (..)` | Client | Generic latest duplicate-turn parse coverage at `test/AppServerSpec.hs:224-276`; no active-turn replay-state integration test. | incidental | Parser behavior is covered, but the guard's missing/materializing/found turn policy is not. |
| turn-completion classification | `checkTurn` delegates to `classifyTurnCompletion` and maps running, failed, missing output, blank output, and completed output at `RunnerGuard.hs:347-360`. | `AppServerTurn (..)` | Client for data type; classifier module for policy | Turn-classifier tests exist elsewhere, but no RunnerGuard `checkTurn` surface assertion was found. | incidental | A later split would not prove RunnerGuard still maps classifications to the intended repair/stale actions and messages. |
| stale-turn decisions | `staleProblem` gates running/materializing/completed-unobserved problems by event-log age at `RunnerGuard.hs:336-341`, `350-351`, `359-367`. | `AppServerTurn (..)`, `threadReadMaterializationPending` | Client for data type/marker | Existing RunnerGuard tests use huge stale thresholds and no app-server active-turn path; no stale active-turn assertion was found. | missing | Guard could over-report or under-report active-turn staleness without current tests catching it. |
| `formatAppServerClientFailure` text | Failure formatting feeds `fail` in repair launch and problem details in active-thread read/parse paths at `RunnerGuard.hs:148`, `163`, `168`, `323`, `331`. | `formatAppServerClientFailure` | Client | Search found production uses and generic failure constructors, but no direct test asserting `formatAppServerClientFailure` text or RunnerGuard detail text. | missing | User-visible diagnostics could drift, and import split would not provide evidence for failure-formatting stability. |

## Recommendation

No: a later `RunnerGuard.hs` import-only split from
`CodexWatcher.AppServerClient` to the direct owner modules is not safe to
select yet.

The direct owners are clear, and the import split would be mechanically small,
but several selected RunnerGuard gates are missing focused behavior assertions.
The most important gap is the active-turn read policy path, because it combines
transport, parser, materialization marker, system-error detection, latest-turn
lookup, turn-completion classification, stale-threshold decisions, and
formatted failure text in one user-visible guard decision.

Single focused behavior test slice that must land first:

`RunnerGuard active app-server turn inspection`: add one focused RunnerGuard
test group that drives `checkRunnerGuard` from event logs containing active
turn states and a controlled app-server response source, asserting:

- `thread/read` is requested for the active thread with `RequestId 1` and
  `includeTurns = True`;
- materialization-pending missing turns produce the stale/materializing branch
  only past the configured stale threshold;
- `threadSystemError`, missing active turn, failed turn, completed-without
  output, blank output, and completed-but-unobserved output map to the intended
  `LaunchRepairThread` summaries/details;
- app-server read/parse failures include stable
  `formatAppServerClientFailure` text in `runnerGuardProblemDetails`.

After that slice, a smaller follow-up may still add a repair-launch request
sequence assertion for `startRunnerGuardRepairThread` (`thread/start` id 1,
`thread/name/set` id 2, `turn/start` id 3). However, the active-turn inspection
slice is the single first blocker because it covers the densest behavior
surface currently hidden behind the facade import.

This recommendation does not approve import migration, public deprecation,
Cabal exposure removal, facade removal, behavior change, release/publication,
milestone completion, or terminal completion.

## Changed-Path Evidence

Starting tracked diff was controller-owned `orchestrator/state.json`; the
round directory already contained untracked `selection.md` and `plan.md`.
Implementer-owned changes for this round are limited to this evidence artifact
and optional implementation notes.

Final validation commands and changed-path proof are recorded in
`orchestrator/rounds/round-110/implementation-notes.md`.
