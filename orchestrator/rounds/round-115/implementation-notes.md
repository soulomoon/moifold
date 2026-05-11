### Changes Made
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`: replaced the `CodexWatcher.AppServerClient` compatibility facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. The production diff is import-only; all `probeAppServer` code bodies, request ids, timeout, output text, CLI behavior, and failure formatting are unchanged.

### Tests
- `test/AppServerProbeSpec.hs`: existing round-114 focused command coverage verifies `probeAppServer` initialize, optional `thread/read`, smoke `thread/start`, smoke `turn/start`, request ids, selected params, success output, and selected JSON-RPC/decode failure formatting.

### Notes
- Validation passed:
  - `rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/AppServerProbe.hs` produced no matches.
  - `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/Cli/Command/AppServerProbe.hs` found the direct client import.
  - `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/Cli/Command/AppServerProbe.hs` found the direct transport import.
  - `git diff -- src/CodexWatcher/Cli/Command/AppServerProbe.hs` showed only the import replacement.
  - `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
  - `cabal test watcher-core-test`
  - `cabal build all`
  - `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github` recorded remaining out-of-scope facade users in source and test files, excluding `AppServerProbe.hs`.
  - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  - `git diff --exit-code -- src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
  - `test ! -e orchestrator/rounds/round-115/worker-plan.json`
  - `git diff --check`
  - `git diff --cached --check`
  - `jq . orchestrator/state.json`
- Remaining `CodexWatcher.AppServerClient` users are intentionally out of scope for this round. No tests, package descriptors, direct owner modules, protocol modules, docs, facade exposure, Cabal/API surface, deprecation, or removal work was changed.
