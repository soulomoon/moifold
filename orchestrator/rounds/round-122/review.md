### Checks Run
- Command: `printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded 22 modules and `AutomaticLoopRunnerSpec.automaticLoopRunnerTests` returned `True`; output included PASS lines for execute-mode endpoint traffic, dry-run no live traffic, retryable app-server transport failures, and fatal replay/decode/unexpected-start failures.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` ran successfully and ended with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `! rg -n '^import CodexWatcher\.AppServerClient\b' src/CodexWatcher/AutomaticLoop/Runner.hs`
  Result: pass. No facade import remains in `src/CodexWatcher/AutomaticLoop/Runner.hs`.
- Command: `rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Transport\b' src/CodexWatcher/AutomaticLoop/Runner.hs`
  Result: pass. Found the direct owner import at line 37.
- Command: `rg -n '\b(AppServerEndpoint|appServerInterpreterFromEndpoint|defaultAppServerClientOptions)\b' src/CodexWatcher/AutomaticLoop/Runner.hs`
  Result: pass. Found the three imported symbols at lines 38-40 and existing use sites at lines 91 and 116.
- Command: `git diff -- src/CodexWatcher/AutomaticLoop/Runner.hs`
  Result: pass. The diff removes only `import CodexWatcher.AppServerClient` and adds the explicit `CodexWatcher.Workflow.Agent.Codex.Transport` import list for `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`.
- Command: `git diff --name-only`
  Result: pass. Tracked changes are `orchestrator/state.json` and `src/CodexWatcher/AutomaticLoop/Runner.hs`, both allowed for this review state.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked pre-review round artifacts are `orchestrator/rounds/round-122/implementation-notes.md`, `orchestrator/rounds/round-122/plan.md`, and `orchestrator/rounds/round-122/selection.md`; review artifacts are expected to be added by this review.
- Command: `git diff --name-only | rg '^(docs/|fixtures/|app/|moifold\.cabal|src/CodexWatcher/AppServerClient\.hs|src/CodexWatcher/AppServerProtocol\.hs|agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Runtime/Compatibility|src/CodexWatcher/Runtime/Owner|src/CodexWatcher/Domain/PrReview/LaunchCli\.hs|src/CodexWatcher/Cli/Command/IssueFanout\.hs|test/|orchestrator/rounds/round-122/worker-plan\.json)' && exit 1 || true`
  Result: pass. No forbidden tracked path changed.
- Command: `test ! -e orchestrator/rounds/round-122/worker-plan.json`
  Result: pass. No worker plan exists.
- Command: `jq . orchestrator/state.json >/dev/null`
  Result: pass. Controller state JSON is valid and identifies `round-122`, roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, stage `review`, and `worker_mode: none`.
- Command: `sed -n '1,60p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass. The owner module exports `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`; the module was inspected only and not edited.
- Command: `jq . orchestrator/rounds/round-122/review-record.json >/dev/null`
  Result: pass. Review record JSON is valid.

### Plan Compliance
- Import-only migration: met. `src/CodexWatcher/AutomaticLoop/Runner.hs` now imports the three required symbols from `CodexWatcher.Workflow.Agent.Codex.Transport` and no longer imports `CodexWatcher.AppServerClient`.
- Preserve behavior and code bodies: met. The `Runner.hs` diff contains only import changes; no function body, type signature, export list, runtime behavior, dry-run behavior, retry/fatal classification, fanout, handoff, protocol, or compatibility code changed.
- Preserve public compatibility facade and owner modules: met. No changes were made to `src/CodexWatcher/AppServerClient.hs`, `src/CodexWatcher/AppServerProtocol.hs`, `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/*`, or related owner/runtime modules.
- Avoid docs, fixtures, tests, Cabal, app, protocol, runtime, PR-review launch, and issue fanout changes: met. The forbidden-path guard found no tracked changes under those paths, and the untracked path list contains only allowed round artifacts before this review added review files.
- No worker fan-out: met. `orchestrator/rounds/round-122/worker-plan.json` does not exist and `orchestrator/state.json` records `worker_mode: none`.
- Required validation: met. The focused runner gate, `cabal test watcher-core-test`, `cabal build all`, whitespace checks, import scans, diff inspection, path guards, no-worker-plan guard, and JSON checks all passed.

### Decision
**APPROVED**

### Evidence
The reviewed implementation matches the selected extraction exactly: `Runner.hs` replaces the public `CodexWatcher.AppServerClient` facade import with an explicit direct-owner import for `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`. The only tracked implementation diff is the import replacement, while control-plane state remains in the allowed scope. No forbidden implementation, package, docs, fixtures, tests, runtime compatibility, public facade, protocol, PR-review launch, issue fanout, or worker-plan paths were changed.

The accepted behavior gate for this surface passed in the focused REPL run and again as part of `watcher-core-test`, including execute-mode endpoint-backed app-server traffic, dry-run no-traffic behavior, and retry/fatal classification. The full package baseline and whitespace checks passed.
