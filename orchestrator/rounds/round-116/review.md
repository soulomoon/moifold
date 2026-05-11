### Checks Run
- Command: `printf 'HealthcheckSpec.healthcheckAppServerThreadInspectionTests\n:quit\n' | cabal repl watcher-core-test`
  Result: pass. GHCi loaded the watcher-core-test modules and `healthcheckAppServerThreadInspectionTests` returned `True`; all focused Healthcheck thread inspection assertions passed.
- Command: `cabal test watcher-core-test`
  Result: pass. The watcher-core-test suite passed, including the new Healthcheck endpoint-backed assertions.
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `git diff --name-only -- src app agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass. No changed files under guarded production/package source roots.
- Command: `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass. No package descriptor or project-file changes.
- Command: `git diff --exit-code -- src/CodexWatcher/Healthcheck.hs src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
  Result: pass. No production Healthcheck, facade, client, transport, or protocol changes.
- Command: `test ! -e orchestrator/rounds/round-116/worker-plan.json`
  Result: pass. No worker plan exists.
- Command: `jq -e '<state lineage check from plan.md>' orchestrator/state.json`
  Result: pass. State lineage matches roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, active round `round-116`, worker mode `none`, and `merge_ready = false`.
- Command: `rg -n '^import CodexWatcher\.AppServerClient' test/HealthcheckSpec.hs || true`
  Result: pass. No direct `CodexWatcher.AppServerClient` import remains in `test/HealthcheckSpec.hs`.

### Plan Compliance
- Re-read active scope and contracts: met. `selection.md`, `project-contract.md`, and `verification.md` confirm this is a test-only evidence gate before any `CodexWatcher.Healthcheck` import migration.
- Confirm private implementation and exported test route: met. `src/CodexWatcher/Healthcheck.hs` was not changed, and the tests exercise `runHealthcheck`.
- Edit only expected implementation paths: met. The implementation diff is limited to `test/HealthcheckSpec.hs` and `test/Main.hs`; no production paths, package descriptors, protocol modules, docs, compatibility files, roadmap files, or shared test helpers changed.
- Add success case for worker `thread/read`: met. The focused check and full test suite cover request id `9001`, method `thread/read`, configured `threadId`, `includeTurns = True`, successful report status, latest turn id, latest turn status, and turn count.
- Add skipped-case coverage: met. Missing endpoint and missing thread id cases are covered, including no `thread/read` request for the missing-thread-id case.
- Add failure-format coverage: met. JSON-RPC error formatting and decode-failure prefix assertions pass.
- Cover timeout behavior where practical: acceptable omission. `implementation-notes.md` records that the production timeout is hard-coded to five seconds, so adding the timeout test would make this focused gate slower and more timing-sensitive without adding production configurability in scope.
- Register the aggregate in `test/Main.hs`: met. `watcher-core-test` reaches and passes the aggregate.
- Preserve production behavior/imports: met. Production files are unchanged, and `test/HealthcheckSpec.hs` now imports `AppServerEndpoint` from the direct owner module `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Do not create `worker-plan.json`: met.

### Decision
**APPROVED**

### Evidence
The integrated round adds endpoint-backed test evidence for the Healthcheck app-server thread inspection path while leaving production behavior and package/protocol surfaces unchanged. The new tests verify the `thread/read` request shape, request id `9001`, `includeTurns = True`, configured thread id, successful latest-turn reporting, skip behavior for missing endpoint and missing thread id, JSON-RPC failure formatting, and decode-failure formatting. The previously rejected public-facade test import was corrected to use the direct owner type import from `CodexWatcher.Workflow.Agent.Codex.Transport`.
