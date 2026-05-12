### Changes Made
- `test/PrReviewLaunchCliSpec.hs`: replaced the `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, preserving all PR-review launch CLI assertions and helper definitions.

### Tests
- `test/PrReviewLaunchCliSpec.hs`: existing PR-review launch CLI coverage remains unchanged, including worker/reviewer thread launch, dry-run command rendering, endpoint path rendering, runtime-owner skip behavior, JSON-RPC failure formatting, and decode-failure formatting.
- `rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint' test/PrReviewLaunchCliSpec.hs`: passed; the spec imports the direct transport owner and still constructs the same `AppServerEndpoint` values.
- `rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint \(..\)' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`: passed; the direct owner module exports `AppServerEndpoint (..)`.
- `rg -n 'CodexWatcher\.AppServerClient' src app test docs moifold.cabal agent-workflow-core agent-workflow-codex agent-workflow-github --glob '*.hs' --glob '*.md' --glob '*.cabal'`: passed; remaining hits are the public facade/exposure, docs/policy references, broad workflow specs, `test/Main.hs`, `test/AutomaticLoopRunnerSpec.hs`, and test support.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no staged changes were present.

### Notes
No `worker-plan.json` was added. Remaining `CodexWatcher.AppServerClient` facade users are intentionally out of scope for this round and should be handled by later exact selections.
