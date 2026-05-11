### Changes Made
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`: replaced the production `CodexWatcher.AppServerClient` facade import with direct owner imports for the existing app-server symbols used by the module.

### Tests
- `printf ':set -v0\n:m + IssueFanoutAppServerSpec\nissueFanoutAppServerTests\n:quit\n' | cabal repl watcher-core-test`: passed; `issueFanoutAppServerTests` returned `True` after all focused issue-fanout app-server assertions printed `PASS`.
- `cabal test watcher-core-test`: passed; `Test suite watcher-core-test: PASS`, `1 of 1 test suites (1 of 1 test cases) passed`.
- `cabal build all`: passed; built and linked the `moifold` executable.
- `git diff --check`: passed with no output.
- `rg -n "import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/IssueFanout.hs`: no matches, proving the production IssueFanout facade import was removed.
- `rg -n "CodexWatcher\\.AppServerClient" src app test agent-workflow-codex agent-workflow-core agent-workflow-github moifold.cabal docs README.md`: remaining matches are only the public facade exposure, tests/support imports, and docs/Cabal compatibility references left intentionally untouched.
- `rg -n "startThreadWithEndpoint|defaultAppServerClientOptions|formatAppServerClientFailure|AppServerEndpoint" src/CodexWatcher/Cli/Command/IssueFanout.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`: confirms `IssueFanout.hs` still references the same app-server symbols and imports them from the direct owner modules.
- `git diff --unified=0 -- src/CodexWatcher/Cli/Command/IssueFanout.hs`: only the removed `CodexWatcher.AppServerClient` import and the two added direct owner imports changed.
- `jq -r '.controller_stage as $stage | .active_rounds[] | select(.round_id=="round-126") | "controller_stage=\\($stage) round_stage=\\(.stage) worker_mode=\\(.worker_mode) branch=\\(.branch)"' orchestrator/state.json && test ! -e orchestrator/rounds/round-126/worker-plan.json && echo "worker-plan.json absent"`: `controller_stage=dispatch-rounds round_stage=implement worker_mode=none branch=orchestrator/round-126-highest-value-cleanup-slice`; `worker-plan.json absent`.

### Notes
The direct owner source files are under `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/{Client,Transport}.hs`; verification used those paths rather than a nonexistent `src/...` owner path. No worker fan-out was used and no `worker-plan.json` was created.
