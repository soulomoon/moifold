### Goal
Move only `test/IssueFanoutAppServerSpec.hs` off the public `CodexWatcher.AppServerClient` compatibility-facade import for `AppServerEndpoint (..)`, using the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))` while preserving all issue-fanout app-server assertions.

### Approach
Keep this as a sequential, single-file import convergence round under `orchestrator/project-contract.md`. The selected spec imports only `AppServerEndpoint (..)` from `CodexWatcher.AppServerClient`, and the direct owner already exposes that type from `CodexWatcher.Workflow.Agent.Codex.Transport`, so the implementation should be a narrow import replacement only.

Preserve the existing issue-fanout behavior coverage: app-server-backed execute flow, child argument rendering for root and non-root endpoints, retryable clone failure classification, child-start classification, JSON-RPC failure formatting, and decode-failure formatting.

Do not edit production files, other tests, test support files, `test/PrReviewLaunchCliSpec.hs`, `test/AutomaticLoopRunnerSpec.hs`, workflow specs with broader `CodexWatcher.AppServerClient` imports, `test/FacadeImportPolicySpec.hs`, public facade implementation or exports, `CodexWatcher.Workflow.Agent.Codex.Client`, direct owner exports, package descriptors, docs/policy files, roadmap files, `orchestrator/state.json`, review artifacts, merge artifacts, Cabal exposure, public facade deprecation/removal, release gates, milestone completion, or terminal completion.

No worker fan-out is justified because the scope is one import in one test file with one serial verification path.

### Steps
1. Confirm the starting point in `test/IssueFanoutAppServerSpec.hs`:
   - The exact import `CodexWatcher.AppServerClient (AppServerEndpoint (..))` is present.
   - The file uses `AppServerEndpoint` only for endpoint construction and type signatures.
   - The `issueFanoutAppServerTests` list still includes execute, child-argument rendering, retry classification, child-start classification, JSON-RPC failure, and decode-failure checks.
2. Confirm the direct owner export in `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs` includes `AppServerEndpoint (..)`.
3. In `test/IssueFanoutAppServerSpec.hs`, replace only:
   - `import CodexWatcher.AppServerClient (AppServerEndpoint (..))`
   - with `import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`
4. Do not change any other imports, assertions, helper calls, endpoint values, request expectations, child argument expectations, failure text expectations, source-scan needles, fixture setup, app-server helpers, timing constants, or test names.
5. Run focused selected-file scans and record the results:
   - `rg -n 'CodexWatcher\.AppServerClient|AppServerEndpoint' test/IssueFanoutAppServerSpec.hs`
   - Expected: no `CodexWatcher.AppServerClient` match in the selected file, and `AppServerEndpoint` still appears through the direct owner import plus existing constructor/type uses.
   - `rg -n 'issueFanoutAppServerTests|issueFanoutExecuteStartsAppServerBackedIssueThreads|issueFanoutChildArgsRenderRootEndpoint|issueFanoutChildArgsRenderNonRootEndpoint|issueFanoutRetainsRetryableCloneFailureContract|issueFanoutChildStartClassificationSourceContract|issueFanoutExecuteFormatsJsonRpcFailure|issueFanoutExecuteFormatsDecodeFailure' test/IssueFanoutAppServerSpec.hs`
   - Expected: all selected issue-fanout app-server assertions remain reachable from `issueFanoutAppServerTests`.
6. Run broad remaining `CodexWatcher.AppServerClient` import scans over current source, app, tests, docs, package descriptors, and standalone package candidates:
   - `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null || true`
   - Record that `test/IssueFanoutAppServerSpec.hs` is removed from remaining facade importers.
   - Treat the public facade module definition, Cabal exposure, docs/policy text, policy tests, roadmap text, and other out-of-scope test imports as remaining evidence or future migration targets, not as part of this round.
7. Inspect the diff and confirm the implementation diff is limited to the import replacement in `test/IssueFanoutAppServerSpec.hs` plus this `plan.md`, with no changes to production files, other tests, test support files, package descriptors, docs/policy, roadmap/state artifacts, review artifacts, or merge artifacts.

### Verification
- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if anything is staged
- Focused `test/IssueFanoutAppServerSpec.hs` scans proving the old `CodexWatcher.AppServerClient` import is gone and every issue-fanout app-server assertion remains reachable from `issueFanoutAppServerTests`.
- Broad `CodexWatcher.AppServerClient` import scan proving `test/IssueFanoutAppServerSpec.hs` is no longer among remaining facade importers while other out-of-scope facade references are only recorded.
- Diff review confirming this is behavior-preserving import convergence only and does not imply public facade deprecation, removal, Cabal exposure cleanup, milestone completion, terminal completion, or release approval.

### Worker Fan-Out
No worker fan-out. Do not create `worker-plan.json` for this round.
