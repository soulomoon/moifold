### Changes Made
- `test/AppServerProbeSpec.hs`: added endpoint-backed command tests for `probeAppServer`, including stdout/stderr/exit capture, command-level request filtering, success request sequencing, smoke-thread behavior, and selected failure formatting.
- `test/Main.hs`: wired `appServerProbeCommandTests` into the watcher-core test aggregate near the existing app-server and CLI checks.
- `moifold.cabal`: added `AppServerProbeSpec` to the `watcher-core-test` `other-modules` list only.
- `orchestrator/state.json`: advanced round-114 from implementation to review after local validation.

### Tests
- `test/AppServerProbeSpec.hs`: verifies initialize-only success; thread/read plus smoke thread plus smoke turn success with ids and params; `--start-smoke-turn` without a thread id using the created smoke thread; thread/read JSON-RPC failure formatting and stop point; thread/start JSON-RPC failure formatting and stop point; and turn/start parse failure formatting.

### Notes
No production files, app-server facade modules, direct owner modules, protocol modules, docs, runtime fixtures, roadmap files, selection, plan, review, or merge artifacts were edited. No `worker-plan.json` exists for this round.

Validation run:
- `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --exit-code -- src/CodexWatcher/Cli/Command/AppServerProbe.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
- `git diff --exit-code -- agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
- `git diff -- moifold.cabal`
- `test ! -e orchestrator/rounds/round-114/worker-plan.json`
- `git diff --check`
- `git diff --cached --check`
- `jq . orchestrator/state.json`
