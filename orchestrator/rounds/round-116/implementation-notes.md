### Changes Made
- `test/HealthcheckSpec.hs`: added `healthcheckAppServerThreadInspectionTests`, covering `runHealthcheck` through the endpoint-backed fake app-server and local command stubs so environment/GitHub diagnostics stay deterministic.
- `test/Main.hs`: registered the new Healthcheck endpoint-backed aggregate in the watcher-core test runner.

### Tests
- `test/HealthcheckSpec.hs`: verifies worker `thread/read` request id `9001`, method `thread/read`, configured `params.threadId`, `params.includeTurns = True`, successful report fields, missing-endpoint skip, missing-thread-id skip with no `thread/read`, JSON-RPC error formatting, and decode-failure prefix.

### Notes
Timeout coverage was omitted. The production healthcheck path hard-codes a five-second app-server response timeout, so a test would add at least five seconds per run and be more timing-sensitive than the rest of this focused evidence round. No production code, package descriptors, protocol modules, roadmap files, or shared test helpers were changed.
Review fix: replaced the test import of the `CodexWatcher.AppServerClient` compatibility facade with the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)`.
