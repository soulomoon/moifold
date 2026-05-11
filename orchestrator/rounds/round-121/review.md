### Checks Run
- Command: `printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `AutomaticLoopRunnerSpec` and the aggregate returned `True`; the focused output showed PASS lines for execute endpoint traffic, default initialization, planner `thread/start`/`turn/start`, dry-run no endpoint traffic, app-server transport retryability, decode/replay fatality, event replay fatality, and unexpected start plan fatality.
- Command: `cabal test watcher-core-test`
  Result: pass. `Test suite watcher-core-test: PASS`; 1 of 1 test suites passed. The new automatic-loop assertions were reached in the full aggregate.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.
- Command: `git diff -- src/CodexWatcher/AutomaticLoop/Runner.hs | rg 'CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.Client|Workflow\\.Agent\\.Codex\\.Transport|Workflow\\.Agent\\.Codex\\.Interpreter' || true`
  Result: pass. No output; `Runner.hs` has no diff and no production import migration happened.
- Command: `git diff --name-only && git ls-files --others --exclude-standard`
  Result: pass. Changed tracked paths were `moifold.cabal`, `orchestrator/state.json`, and `test/Main.hs`; untracked paths were `orchestrator/rounds/round-121/implementation-notes.md`, `orchestrator/rounds/round-121/plan.md`, `orchestrator/rounds/round-121/selection.md`, and `test/AutomaticLoopRunnerSpec.hs`. The implementation code surface is limited to the new test module, watcher-core test wiring, and watcher-core cabal metadata. The `orchestrator/state.json` diff records the active controller state for round-121 review and was not an implementation change.
- Command: `test ! -e orchestrator/rounds/round-121/worker-plan.json`
  Result: pass. No worker plan exists.
- Command: `git diff -- moifold.cabal`
  Result: pass. The only cabal change is adding `AutomaticLoopRunnerSpec` to `watcher-core-test` `other-modules`.
- Command: `git diff --name-only | rg '^(docs/|fixtures/|app/|src/CodexWatcher/AppServerClient.hs|src/CodexWatcher/AppServerProtocol.hs|src/CodexWatcher/Workflow/Agent/Codex|src/CodexWatcher/Runtime/Compatibility|src/CodexWatcher/Runtime/Owner|src/CodexWatcher/Domain/PrReview/LaunchCli.hs|src/CodexWatcher/Cli/Command/IssueFanout.hs)' && exit 1 || true`
  Result: pass. No forbidden docs, fixtures, app code, app-server owner/protocol, runtime compatibility/owner, PR-review launch, or issue-fanout paths changed.
- Command: `jq -e '.contract_version == "orchestrator-v2" and .roadmap_style == "strategy-backlog" and .roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-121" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and .roadmap_update == null' orchestrator/state.json`
  Result: pass. Output was `true`.

### Plan Compliance
- Add a focused test module exporting an aggregate: met. `test/AutomaticLoopRunnerSpec.hs` exports `automaticLoopRunnerTests`.
- Execute-mode endpoint-backed coverage through `runAutomaticLoop`: met. The test starts `TestSupport.AppServer.withEndpointBackedAppServer`, builds a one-shot executable `LoopCli`, runs `runAutomaticLoop`, and asserts the captured JSON-RPC methods and ids include default `initialize`/`initialized` traffic plus planner `thread/start` and `turn/start` on the returned planner thread.
- Dry-run no live endpoint traffic for planned app-server effects: met. The dry-run test uses the same runner path with `loopCliExecute = False`, asserts success, and asserts the fake endpoint captured no requests.
- Retry/fallback classification coverage: met. The aggregate asserts app-server transport failures are retryable and app-server decode/replay, event-log replay decode, and unexpected start plan failures remain fatal.
- Wire the aggregate into watcher-core tests: met. `test/Main.hs` imports `AutomaticLoopRunnerSpec` and includes `automaticLoopRunnerOk` in the final success conjunction; `moifold.cabal` lists the module under `watcher-core-test` `other-modules`.
- Keep the round coverage-only and avoid production migration: met. `src/CodexWatcher/AutomaticLoop/Runner.hs` has no diff, and no direct owner client/transport/interpreter imports were introduced.
- Avoid worker fan-out: met. `orchestrator/rounds/round-121/worker-plan.json` does not exist.

### Decision
**APPROVED**

### Evidence
The implementation satisfies the selected coverage gate before a later `CodexWatcher.AppServerClient` import migration. The focused tests exercise the production `runAutomaticLoop` path rather than an isolated helper. Execute mode proves endpoint-backed app-server traffic is sent through the configured `AppServerEndpoint` and includes the default client initialization handshake before planner thread and turn starts. Dry-run mode proves the same planned start scenario completes without live endpoint traffic. Retry/fallback classification remains explicit and preserves transient transport failures as retryable while keeping decode/replay and unexpected start-plan failures fatal.

Scope is acceptable for a coverage-only round. No production files were changed, `Runner.hs` was not touched, `CodexWatcher.AppServerClient` was not migrated, forbidden owner/protocol/runtime/docs/fixture/app paths were untouched, and `moifold.cabal` changed only watcher-core test metadata. I did not find a flaky or invalid test assumption that undermines this gate: the fake endpoint is loopback-scoped per test, the temporary fixture path is process-scoped and cleaned, and the assertions target the deterministic one-shot planner start path used by this runner scenario.
