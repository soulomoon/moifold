### Checks Run
- Command: `pwd && git status --short --branch`
  Result: pass. Worktree is `/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-125` on branch `orchestrator/round-125-highest-value-cleanup-slice`.
- Command: `jq -r '.stage as $controller_stage | .active_rounds[] | select(.round_id == "round-125") | "controller_stage=\($controller_stage)\nround_stage=\(.stage)"' orchestrator/state.json`
  Result: pass. Controller stage and round stage are both `review`.
- Command: `printf ':module + IssueFanoutAppServerSpec\nissueFanoutAppServerTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `IssueFanoutAppServerSpec`; `issueFanoutAppServerTests` returned `True` after all focused IssueFanout app-server assertions passed.
- Command: `cabal test watcher-core-test`
  Result: pass. The watcher-core test suite completed successfully; the new IssueFanout app-server assertions all reported `PASS`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `rg -n 'import CodexWatcher\.AppServerClient' src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass. `src/CodexWatcher/Cli/Command/IssueFanout.hs:28` still imports `CodexWatcher.AppServerClient`.
- Command: `git diff -- src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass. No production diff in `IssueFanout.hs`.
- Command: `test ! -e orchestrator/rounds/round-125/worker-plan.json`
  Result: pass. No worker plan exists for this sequential round.
- Command: `git diff --name-only && git ls-files --others --exclude-standard`
  Result: pass. Changed paths are limited to expected test metadata, test runner wiring, new focused test module, round artifacts, and controller-owned `orchestrator/state.json`.
- Command: `jq -e '.stage == "review" and (.active_rounds[] | select(.round_id == "round-125") | .stage == "review")' orchestrator/state.json`
  Result: pass. JSON parses and records review stage for the active round.

### Plan Compliance
- Add `test/IssueFanoutAppServerSpec.hs` exporting `issueFanoutAppServerTests`: met. The new module exports `issueFanoutAppServerTests :: IO Bool`.
- Reuse endpoint-backed app-server helpers with deterministic request ids: met. Tests use `withEndpointBackedAppServer`, `jsonRpcResult`, and `jsonRpcError`, and assert IssueFanout request ids `8000` and `8001`.
- Success-path test covers child launches and persisted app-server thread ids: met. The focused suite asserts `thread/start` calls, request ids, launch workdir `cwd`, developer instruction context, config thread ids, event log thread ids, finalized manifests, and pending manifest removal.
- Command-rendering coverage: met. Root endpoint omits `--app-server-path`; non-root endpoint includes it; child args retain `run-issue-implement`, events, state dir, repo, workdir, host, port, poll seconds, execute, loop, and pid-file flags.
- Workdir setup retry coverage: met. The suite preserves the pure retryable predicate coverage for transient clone failures without real GitHub or network access.
- Readiness/completion classification coverage: met within the accepted plan fallback. Direct runtime classification still lacks a production test seam, so the round records the blocker and preserves source-order assertions for started, completed-before-ready, and problem classification.
- App-server failure formatting: met. JSON-RPC failure and decode failure tests assert non-zero exit, formatted failure text, request id `8000` for the JSON-RPC path, and no later child-thread request/config write after first failure.
- Wire the new suite into watcher-core tests: met. `test/Main.hs` imports and runs `issueFanoutAppServerTests`.
- Update only `watcher-core-test` metadata in `moifold.cabal`: met. The cabal diff only adds `IssueFanoutAppServerSpec` to `watcher-core-test` `other-modules`.
- Do not migrate production imports or public facade exposure: met. `IssueFanout.hs` still imports `CodexWatcher.AppServerClient`, has no diff, and no Cabal exposed-module or public facade cleanup occurred.
- Do not write `worker-plan.json`: met. No worker-plan file exists.
- Scope boundaries from selection: met. No implementation code, app-server protocol modules, runtime compatibility files, fixtures, docs, app code, public deprecation/removal, milestone completion, or release approval changed.

### Decision
**APPROVED**

### Evidence
The integrated round adds focused watcher-core coverage for IssueFanout app-server-backed child implementer launch behavior before production import migration. The new tests cover the selected contracts: child thread launch protocol, request id progression from `8000`, launch workdir `cwd`, developer instructions, persisted config/event/finalized manifest thread ids, child command rendering, retryable clone failure classification, fallback source-order readiness classification, and selected app-server failure formatting.

Changed-path evidence matches the round boundary: `moifold.cabal`, `test/Main.hs`, `test/IssueFanoutAppServerSpec.hs`, `orchestrator/rounds/round-125/{selection.md,plan.md,implementation-notes.md}`, and controller-owned `orchestrator/state.json`. Production `src/CodexWatcher/Cli/Command/IssueFanout.hs` has no diff and still imports `CodexWatcher.AppServerClient`.
