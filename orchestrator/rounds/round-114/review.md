### Checks Run
- Command: `sed -n '1,220p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer duties and output format inspected.
- Command: `sed -n '1,220p' orchestrator/rounds/round-114/selection.md`
  Result: pass; lineage is roadmap `2026-05-11-00-highest-value-cleanup` / `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, extracted item `round-114-appserver-probe-command-coverage`.
- Command: `sed -n '1,260p' orchestrator/rounds/round-114/plan.md`
  Result: pass; plan requires a test-only `AppServerProbeSpec`, `test/Main.hs` aggregation, narrow `watcher-core-test` metadata, no production edits, no worker fan-out.
- Command: `sed -n '1,260p' orchestrator/rounds/round-114/implementation-notes.md`
  Result: pass; notes record only `test/AppServerProbeSpec.hs`, `test/Main.hs`, `moifold.cabal`, and state changes, with no production edits.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; touched surface is command request rendering/request-id/failure-format coverage, and public compatibility facades must remain available.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; baseline and AppServerClient task-specific checks identified.
- Command: `sed -n '480,1045p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass; milestone 003 / direction 010 remain in progress, and `Cli/Command/AppServerProbe.hs` is still a gated source user.
- Command: `sed -n '1,260p' test/AppServerProbeSpec.hs` and `sed -n '260,620p' test/AppServerProbeSpec.hs`
  Result: pass; new tests use the endpoint-backed fake app-server, capture stdout/stderr/exit code, filter session handshakes, and assert command requests, ids, params, success output, and selected failure formatting.
- Command: `git diff -- test/Main.hs`
  Result: pass; aggregation imports and runs only `appServerProbeCommandTests`.
- Command: `git diff --unified=0 -- moifold.cabal`
  Result: pass; descriptor diff is limited to adding `AppServerProbeSpec` under `watcher-core-test` `other-modules`.
- Command: `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass; GHCi loaded 20 modules and all 30 focused AppServerProbe assertions passed, returning `True`.
- Command: `cabal test watcher-core-test`
  Result: pass; watcher-core-test passed and the AppServerProbe assertions appeared in the full aggregate output.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.
- Command: `git diff --exit-code -- src/CodexWatcher/Cli/Command/AppServerProbe.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
  Result: pass; no production, facade, direct-owner, or protocol diff.
- Command: `git diff --exit-code -- agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; standalone package descriptors unchanged.
- Command: `test ! -e orchestrator/rounds/round-114/worker-plan.json`
  Result: pass; no worker fan-out artifact exists.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `jq . orchestrator/state.json`
  Result: pass; state parsed before review finalization.

### Plan Compliance
- Add focused `test/AppServerProbeSpec.hs`: met; the module exports `appServerProbeCommandTests :: IO Bool` and uses endpoint-backed command execution.
- Request-inspection helpers: met; helper coverage includes method, id, params, text path, bool params, turn input text, and success-output matching.
- Local command runner/capture helper: met; `runProbe` uses `withEndpointBackedAppServer`, builds `AppServerProbeCli`, runs `probeAppServer`, captures stdout/stderr/exit status, and returns recorded requests.
- Initialize-only success: met; asserts command `initialize` id `1`, probe client identity, success output, and empty stderr.
- Existing thread plus smoke thread/turn success: met; asserts command methods `initialize`, `thread/read`, `thread/start`, `turn/start`, ids `1` through `4`, thread/read params, smoke thread cwd/developer instructions, turn prompt/thread/workdir, and success output.
- Smoke turn without existing thread: met; asserts smoke thread creation precedes turn start and the returned smoke thread id is used.
- Selected failure formatting: met; tests cover `thread/read` JSON-RPC failure id `2`, `thread/start` JSON-RPC failure id `3`, and `turn/start` parse failure with the stable decode prefix, including stop-point assertions.
- `test/Main.hs` aggregate wiring: met; `appServerProbeCommandTests` is imported, executed, and included in the final boolean.
- `moifold.cabal` watcher-core-test metadata: met; only `AppServerProbeSpec` was added to `other-modules`.
- No worker fan-out: met; `worker-plan.json` is absent.
- Boundaries: met; production AppServerProbe/AppServerClient/direct-owner/protocol modules are unchanged, public facade exposure is unchanged, and package descriptor changes are limited to test metadata.

### Decision
**APPROVED**

### Evidence
The integrated round result adds the missing command-level evidence for `probeAppServer` without changing production behavior. The tests exercise the real websocket transport and command output/failure path, prove request id progression and selected params, and preserve the roadmap rule that this is evidence for a later import-only migration, not migration, deprecation, public facade removal, Cabal exposure cleanup, release approval, milestone completion, or terminal completion.
