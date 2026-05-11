### Checks Run
- Command: `jq . orchestrator/state.json`
  Result: pass; state is `stage: "review"` with active `round-111`, roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, direction `direction-010-appserverclient-import-convergence`, extracted item `round-111-runner-guard-active-turn-inspection-coverage`.
- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass; package/module boundary and compatibility-facade invariants require preserving production AppServerClient/RunnerGuard behavior and public compatibility modules.
- Command: `sed -n '1,240p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline gates are `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`; AppServerClient-adjacent work requires protocol/client/failure-formatting verification as applicable.
- Command: `sed -n '1,240p' orchestrator/rounds/round-111/selection.md`
  Result: pass; selected scope is focused RunnerGuard active app-server turn inspection test coverage, with production behavior changes out of scope.
- Command: `sed -n '1,260p' orchestrator/rounds/round-111/plan.md`
  Result: pass; plan requires endpoint-backed fake app-server coverage, request-shape assertions, materialization fallback threshold coverage, active-turn mapping coverage, formatted failure details, suite wiring, no production changes, and no `worker-plan.json`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-111/implementation-notes.md`
  Result: pass; notes claim only test/support/Cabal wiring changes and all required checks green.
- Command: `git status --porcelain=v1`
  Result: pass; changed paths are `moifold.cabal`, `orchestrator/state.json`, `test/Main.hs`, `orchestrator/rounds/round-111/`, `test/RunnerGuardSpec.hs`, and `test/TestSupport/AppServer.hs`, all within selected scope once reviewer artifacts are included.
- Command: `git diff -- moifold.cabal test/Main.hs`
  Result: pass; only `RunnerGuardSpec`/`TestSupport.AppServer` are added to `watcher-core-test`, `network`/`websockets` are added as test-suite dependencies, and `runnerGuardActiveTurnInspectionTests` is wired into the existing aggregate.
- Command: `sed -n '1,620p' test/RunnerGuardSpec.hs`
  Result: pass; tests call `checkRunnerGuard` through a real endpoint-backed fake app-server and assert active `thread/read` request id `1`, `threadId = planner-thread`, and `includeTurns = True`.
- Command: `sed -n '1,260p' test/TestSupport/AppServer.hs`
  Result: pass; support module is test-only, starts a localhost websocket endpoint, records decoded JSON requests, handles initialize traffic, and returns scripted JSON-RPC result/error responses.
- Command: `git diff -- src/CodexWatcher/RunnerGuard.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs`
  Result: pass; empty diff, so production RunnerGuard/AppServerClient/client/transport/protocol behavior and imports are unchanged.
- Command: `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass; aggregate returned `True` and printed PASS lines for request shape, materialization fallback, all active-turn mappings, JSON-RPC failure formatting, and decode failure formatting.
- Command: `cabal test watcher-core-test`
  Result: pass; full watcher-core test suite passed, including the new RunnerGuard active-turn assertions.
- Command: `cabal build all`
  Result: pass; build was up to date and exited successfully.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `test ! -e orchestrator/rounds/round-111/worker-plan.json`
  Result: pass; no worker fan-out artifact exists.

### Plan Compliance
- Add focused RunnerGuard test entry point: met; `test/RunnerGuardSpec.hs` exports `runnerGuardActiveTurnInspectionTests`, and `test/Main.hs` includes it in the final aggregate.
- Add endpoint-backed fake app-server support: met; `test/TestSupport/AppServer.hs` provides a real localhost websocket endpoint, request recording, initialize handling, and scripted JSON-RPC result/error responses.
- Add deterministic RunnerGuard fixture helpers: met; tests write issue-planning events, a live `watcher.pid`, fresh/stale event-log timestamps, and a `RunnerGuardConfig 'IssuePlanning` pointed at the fake endpoint.
- Assert active `thread/read` request shape: met; the focused test asserts exactly one active read with request id `1`, `threadId = planner-thread`, and `includeTurns = True`.
- Cover materialization-pending fallback across stale threshold: met; fresh materialization returns `Nothing`, stale materialization maps to `"active planner turn is still materializing"`, and both the active and fallback reads are asserted.
- Cover active-turn problem mappings: met; tests cover `threadSystemError`, missing active turn, failed turn, completed without output, blank output, and completed-but-unobserved output, all with `LaunchRepairThread` assertions.
- Cover app-server read and parse failure details: met; JSON-RPC failure includes the stable `formatAppServerClientFailure` text for request id `1`, and parse failure includes the JSON decode prefix.
- Wire test suite metadata: met; `moifold.cabal` registers the new modules and adds only test-suite `network` and `websockets` dependencies needed for the fake server.
- Preserve selected boundaries: met; production RunnerGuard, AppServerClient facade, app-server client, transport, and protocol modules have an empty diff; no roadmap, docs, fixture, public API, deprecation, removal, or behavior changes were introduced.

### Decision
**APPROVED**

### Evidence
The integrated result satisfies the selected test-only scope. The new tests exercise `checkRunnerGuard` through actual app-server websocket requests rather than a pure mock, and the focused REPL run confirmed all requested assertions with explicit PASS output. The full `watcher-core-test` suite and `cabal build all` passed. The production diff guard is empty for `src/CodexWatcher/RunnerGuard.hs`, `src/CodexWatcher/AppServerClient.hs`, and the app-server client/transport/protocol modules, preserving the AppServerClient compatibility facade and production behavior. No `worker-plan.json` exists.
