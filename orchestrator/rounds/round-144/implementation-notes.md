### Changes Made
- test/RunnerGuardSpec.hs: replaced the `CodexWatcher.AppServerClient` compatibility-facade import with direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.

### Tests
- test/RunnerGuardSpec.hs: preserved existing RunnerGuard active-turn inspection, materialization fallback, problem mapping, app-server failure formatting, repair-launch sequence, endpoint-backed fake app-server, and guard config helper assertions.

### Notes
This round is import convergence only. It does not approve public facade deprecation or removal, Cabal exposure cleanup, package descriptor cleanup, milestone completion, release approval, or terminal completion.
