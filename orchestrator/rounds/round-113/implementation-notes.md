### Changes Made
- `src/CodexWatcher/RunnerGuard.hs`: replaced the `CodexWatcher.AppServerClient` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. No code bodies, exports, request ids, prompts, failure text, app-server protocol usage, public facade exposure, package descriptors, docs, tests, or other importers were changed.
- `orchestrator/state.json`: advanced the active round metadata from `implement` to `review` after writing implementation notes.
- `orchestrator/rounds/round-113/implementation-notes.md`: recorded the round implementation summary and validation evidence.

### Tests
- `test/RunnerGuardSpec.hs`: existing focused RunnerGuard coverage verifies active turn inspection and repair launch sequencing through the endpoint-backed app-server path; this file was not edited in this round.

### Notes
This is intentionally an import-only production change. `CodexWatcher.AppServerClient` remains a public compatibility facade, and all non-selected source/test importers remain for later rounds.

Validation run:
- Target old-import scan absent: `rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/RunnerGuard.hs` produced no matches.
- Target direct-owner imports present: `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/RunnerGuard.hs` found line 28; `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/RunnerGuard.hs` found line 37.
- Remaining facade import scan across `src app test agent-workflow-core agent-workflow-codex agent-workflow-github` found only non-selected users: `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`, `src/CodexWatcher/Cli/Command/AppServerProbe.hs`, `src/CodexWatcher/AutomaticLoop/Runner.hs`, `src/CodexWatcher/Cli/Command/IssueFanout.hs`, `src/CodexWatcher/Cli/Command/Observe.hs`, and test-support/policy imports.
- Descriptor and public facade diff guard passed: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`.
- Direct owner module diff guard passed: `git diff --exit-code -- agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`.
- Focused RunnerGuard aggregate passed: `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`.
- Full regression suite passed: `cabal test watcher-core-test`.
- Full build passed: `cabal build all`.
- No worker fan-out artifact: `test ! -e orchestrator/rounds/round-113/worker-plan.json` passed.
- Whitespace checks passed: `git diff --check` and `git diff --cached --check`.
- State JSON check passed: `jq . orchestrator/state.json`.
