### Checks Run
- Command: `printf ':set -v0\n:m + IssueFanoutAppServerSpec\nissueFanoutAppServerTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded `IssueFanoutAppServerSpec`; `issueFanoutAppServerTests` returned `True` after all focused issue-fanout app-server assertions printed `PASS`, including deterministic request ids, launch cwd, developer instruction context, persisted thread ids, child command rendering, retry classification, fallback child-start classification, and JSON-RPC/decode failure formatting.
- Command: `cabal test watcher-core-test`
  Result: pass. The full watcher core suite completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output. No staged changes were present, but the staged diff gate is clean.
- Command: `git diff -- src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass. The only implementation diff removes `import CodexWatcher.AppServerClient` and adds direct owner imports from `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Command: `git diff --unified=0 -- src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass. Zero-context diff shows only one removed import line and two added import lines.
- Command: `git diff --name-only`
  Result: pass for implementation scope. Tracked diffs are `orchestrator/state.json` and `src/CodexWatcher/Cli/Command/IssueFanout.hs`; the implementation code change is limited to `IssueFanout.hs`. The state diff records active round review-stage metadata for `round-126`.
- Command: `git status --short`
  Result: pass with expected integrated-round paths. Status showed modified `orchestrator/state.json`, modified `src/CodexWatcher/Cli/Command/IssueFanout.hs`, and untracked `orchestrator/rounds/round-126/`.
- Command: `rg -n "import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/IssueFanout.hs`
  Result: pass. No matches; `IssueFanout.hs` no longer imports the facade.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test agent-workflow-codex agent-workflow-core agent-workflow-github moifold.cabal docs README.md`
  Result: pass. Remaining hits are the public facade module, Cabal exposed-module entry, tests, test support, and docs/policy references; no in-scope production caller remains.
- Command: `rg -n "startThreadWithEndpoint|defaultAppServerClientOptions|formatAppServerClientFailure|AppServerEndpoint" src/CodexWatcher/Cli/Command/IssueFanout.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass. `IssueFanout.hs` imports and still uses `formatAppServerClientFailure`, `AppServerEndpoint (..)`, `defaultAppServerClientOptions`, and `startThreadWithEndpoint`; owner modules define/export the same symbols.
- Command: `test ! -e orchestrator/rounds/round-126/worker-plan.json && echo "worker-plan.json absent"`
  Result: pass. No worker plan exists.
- Command: `jq -e '.stage == "review" and .controller_stage == "dispatch-rounds" and .active_round_id == "round-126" and (.active_rounds|length == 1) and .active_rounds[0].stage == "review" and .active_rounds[0].worker_mode == "none"' orchestrator/state.json`
  Result: pass. The JSON check returned `true`.

### Plan Compliance
- Reconfirm controller selection and lineage: met. `orchestrator/state.json` records roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, active round `round-126`, stage `review`, max parallel rounds `1`, and selected item `round-126-issue-fanout-appserverclient-import-convergence`.
- Replace only the production facade import in `IssueFanout.hs`: met. The source diff removes `CodexWatcher.AppServerClient` and adds direct owner imports for `formatAppServerClientFailure`, `AppServerEndpoint (..)`, `defaultAppServerClientOptions`, and `startThreadWithEndpoint`.
- Preserve all behavior code paths: met. Zero-context diff shows import lines only, and the focused REPL gate passed the app-server-backed issue fanout behavior assertions.
- Leave tests/support imports, public facade exposure, Cabal/API cleanup, docs, fixtures, runtime compatibility files, and owner modules untouched: met. Remaining facade scan hits are out of scope, and tracked implementation change is limited to the target production module.
- Prove diff is import-only: met. `git diff --unified=0 -- src/CodexWatcher/Cli/Command/IssueFanout.hs` contains only the removed facade import and two added direct imports.
- No worker fan-out: met. `worker-plan.json` is absent and state records `worker_mode=none`.
- Roadmap/project-contract alignment: met. Public compatibility facade availability and Cabal exposure remain unchanged; this round records preferred production imports only and does not claim deprecation, removal, release approval, or milestone completion.

### Decision
**APPROVED**

### Evidence
The integrated round result satisfies the active verification bundle. Baseline checks passed, the focused `IssueFanoutAppServerSpec.issueFanoutAppServerTests` REPL gate passed, and import/diff guards prove `src/CodexWatcher/Cli/Command/IssueFanout.hs` no longer imports `CodexWatcher.AppServerClient` while changing only import lines.

Remaining `CodexWatcher.AppServerClient` hits are intentionally out of scope: `src/CodexWatcher/AppServerClient.hs`, `moifold.cabal`, tests, test support, and docs/policy references. No tests, support modules, public facade module, Cabal exposure, docs, fixtures, runtime compatibility files, owner client/transport/protocol implementations, or behavior bodies were changed by the implementation diff.
