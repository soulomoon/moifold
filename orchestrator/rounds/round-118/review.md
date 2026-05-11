### Checks Run
- Command: `printf 'ObserveCommandSpec.observeCommandTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `ObserveCommandSpec` and the aggregate returned `True`; the focused output included PASS lines for execute-without-endpoint failure, dry-run-without-endpoint success, execute-with-endpoint fake app-server traffic, planner thread id, and empty stderr on success paths.

- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` passed, including the existing observe parser checks and the new observe command assertions at the end of the suite.

- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.

- Command: `git diff --check`
  Result: pass. No whitespace or conflict-marker issues.

- Command: `git diff --cached --check`
  Result: pass. No staged diff issues.

- Command: `git diff --name-only -- src/CodexWatcher/Cli/Command/Observe.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs src/CodexWatcher/AppServerProtocol.hs src/CodexWatcher/Domain/PrReview/LaunchCli.hs src/CodexWatcher/Domain/IssuePlanning/Loop.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/Cli/Command/IssueFanout.hs docs runtime fixtures app`
  Result: pass. Printed no changed forbidden paths.

- Command: `git diff --name-only -- '*.cabal' 'package.yaml' 'cabal.project*'`
  Result: pass. Printed only `moifold.cabal`, matching required watcher-core test metadata.

- Command: `git diff --name-only -- . ':!test/ObserveCommandSpec.hs' ':!test/Main.hs' ':!moifold.cabal' ':!orchestrator/rounds/round-118/plan.md' ':!orchestrator/rounds/round-118/selection.md' ':!orchestrator/state.json'`
  Result: pass. Printed no additional changed paths.

- Command: `git diff -- src/CodexWatcher/Cli/Command/Observe.hs | (! rg -n '^[-+]import .*AppServerClient|^[-+]import .*Workflow\.Agent\.Codex')`
  Result: pass. No observe import migration was present.

- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal`
  Result: pass. Scan shows the expected remaining facade users, including `src/CodexWatcher/Cli/Command/Observe.hs`; this round did not migrate or remove them.

- Command: `test ! -e orchestrator/rounds/round-118/worker-plan.json`
  Result: pass. No worker-plan artifact exists.

- Command: `jq -e '.roadmap_id == "2026-05-11-00-highest-value-cleanup" and .roadmap_revision == "rev-001" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-118" and (.active_rounds | length) == 1 and .active_rounds[0].round_id == "round-118" and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none" and .active_rounds[0].merge_ready == false and (.active_rounds[0].roadmap_item_id == "round-118-observe-appserver-interpreter-coverage")' orchestrator/state.json`
  Result: pass. Current lifecycle state is the expected review-stage round state.

- Command: `jq -e '(.review_records == null or (.review_records | type == "object")) and (.roadmap_update == null)' orchestrator/state.json`
  Result: pass. No roadmap update is active and review-record storage shape is compatible.

- Command: plan-stage lifecycle check from `plan.md` with `.active_rounds[0].stage == "plan"`
  Result: fail as expected for the current reviewer handoff state. The same lineage and scheduler checks pass when the stage assertion is updated to `review`.

### Plan Compliance
- Add a focused observe command test module: met. `test/ObserveCommandSpec.hs` exports `observeCommandTests :: IO Bool`.
- Use black-box command-boundary coverage through `observeOnce`: met. The tests import `observeOnce`; no production seam or new export was added.
- Write an initialized issue-planning event log fixture: met. The test writes `IssuePlanningInitialized (PlannerConfig testRepo (maxParallelForTest 8) [])` as JSON lines.
- Capture stdout, stderr, and `ExitCode`: met. The test captures both streams around `observeOnce` and asserts command-boundary outcomes.
- Execute without endpoint fails with required endpoint flag error: met. The focused REPL and full suite both passed assertions for non-success exit, required stderr text, and no success output.
- Dry-run without endpoint succeeds through null interpreter fallback: met. The test runs without an endpoint, expects `ExitSuccess`, and checks `event: IssuePlanningTurnStarted`, `actions: 1`, and `mode: DryRunActions` without a fake server.
- Execute with configured endpoint reaches fake app-server: met. The test uses `withEndpointBackedAppServer`, asserts `mode: ExecuteActions`, and verifies `[initialize, initialized, turn/start]` with request ids `[0, none, 1]` plus the configured planner thread id in `turn/start`.
- Wire the aggregate into `watcher-core-test`: met. `test/Main.hs` imports and runs `observeCommandTests`; `moifold.cabal` adds `ObserveCommandSpec` to `watcher-core-test` `other-modules`.
- Preserve existing observe parser assertions: met. `observeOnceParsingCoversDomainsAndDefaults` remains wired and passed in `cabal test watcher-core-test`.
- Keep production `src/CodexWatcher/Cli/Command/Observe.hs` untouched and avoid import migration: met. `git diff -- src/CodexWatcher/Cli/Command/Observe.hs` is empty and the import-migration guard passed.
- Keep package descriptor changes limited to test metadata: met. Descriptor diff is a single `ObserveCommandSpec` `other-modules` entry.
- Avoid direct owner/protocol/runtime compatibility/docs/app changes and worker-plan artifact: met. Forbidden-surface diff guard printed no paths; `worker-plan.json` is absent.

### Decision
**APPROVED**

### Evidence
The integrated diff is coverage-only: `test/ObserveCommandSpec.hs` is new, `test/Main.hs` wires the aggregate, and `moifold.cabal` adds test metadata. Production observe code, app-server facade/client/protocol/transport modules, runtime compatibility files, fixtures, docs, app code, and the other importer files were not changed.

The focused REPL check and full watcher-core suite prove the selected behavior: execute mode rejects a missing endpoint; dry-run without endpoint succeeds with one dry-run action and does not need a fake app-server; execute mode with a configured endpoint reaches the endpoint-backed fake app-server and sends the expected session/turn-start traffic. Baseline build, tests, and diff hygiene all passed.
