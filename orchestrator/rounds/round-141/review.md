### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass; reviewer duties loaded, including baseline checks, plan compliance, and explicit approval/rejection artifacts.
- Command: `python3 -m json.tool orchestrator/state.json`
  Result: pass; active round is `round-141` at review stage for roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-141-issue-fanout-appserver-spec-endpoint-direct-owner-migration`.
- Command: `sed -n '1,280p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass; active verification loaded and used for baseline, facade import convergence, AppServerClient, and scope checks.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass; package-boundary and public-compatibility facade invariants reviewed.
- Command: `sed -n '1,220p' test/IssueFanoutAppServerSpec.hs`
  Result: pass; selected file imports `AppServerEndpoint (..)` from `CodexWatcher.Workflow.Agent.Codex.Transport`, and the issue-fanout app-server test list is intact.
- Command: `sed -n '1,220p' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
  Result: pass; direct owner exports `AppServerEndpoint (..)`.
- Command: `rg -n 'CodexWatcher\.AppServerClient|AppServerEndpoint' test/IssueFanoutAppServerSpec.hs`
  Result: pass; no selected-file `CodexWatcher.AppServerClient` match remains, and `AppServerEndpoint` appears at the direct owner import plus existing endpoint uses.
- Command: `rg -n 'issueFanoutAppServerTests|issueFanoutExecuteStartsAppServerBackedIssueThreads|issueFanoutChildArgsRenderRootEndpoint|issueFanoutChildArgsRenderNonRootEndpoint|issueFanoutRetainsRetryableCloneFailureContract|issueFanoutChildStartClassificationSourceContract|issueFanoutExecuteFormatsJsonRpcFailure|issueFanoutExecuteFormatsDecodeFailure' test/IssueFanoutAppServerSpec.hs`
  Result: pass; all selected issue-fanout app-server assertions remain reachable from `issueFanoutAppServerTests`.
- Command: `rg -n 'CodexWatcher\.AppServerClient' src app test docs *.cabal cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null || true`
  Result: pass; `test/IssueFanoutAppServerSpec.hs` is absent from remaining facade users. Remaining matches are the public facade/exposure, docs/policy references, policy scans, and other out-of-scope tests such as workflow specs, `PrReviewLaunchCliSpec`, and `AutomaticLoopRunnerSpec`.
- Command: `git diff --stat`
  Result: pass; tracked diff before review artifacts was `orchestrator/state.json` control-plane metadata and `test/IssueFanoutAppServerSpec.hs`.
- Command: `git diff --name-status`
  Result: pass; tracked implementation-surface diff includes only `test/IssueFanoutAppServerSpec.hs`; `orchestrator/state.json` is round state metadata.
- Command: `git diff -- test/IssueFanoutAppServerSpec.hs`
  Result: pass; diff is exactly the import replacement from `CodexWatcher.AppServerClient (AppServerEndpoint (..))` to `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`.
- Command: `git diff --name-only -- . ':(exclude)orchestrator/**'`
  Result: pass; only non-orchestrator changed path is `test/IssueFanoutAppServerSpec.hs`.
- Command: `git diff --name-only -- src app test docs '*.cabal' cabal.project agent-workflow-core agent-workflow-codex agent-workflow-github 2>/dev/null`
  Result: pass; only selected implementation-surface path is `test/IssueFanoutAppServerSpec.hs`; no production, docs, package descriptor, or standalone package candidate changes.
- Command: `git diff --cached --name-status`
  Result: pass; no staged files.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors.
- Command: `cabal test watcher-core-test`
  Result: pass; `1 of 1 test suites (1 of 1 test cases) passed`, including issue-fanout app-server execute, child-argument rendering, retry classification, child-start classification, JSON-RPC failure, and decode-failure checks.
- Command: `cabal build all`
  Result: pass; build reported `Up to date`.

### Plan Compliance
- Confirm selected file starting point and use: met. The selected file now has the direct owner import and uses `AppServerEndpoint` only for endpoint construction/type positions.
- Confirm direct owner export: met. `CodexWatcher.Workflow.Agent.Codex.Transport` exports `AppServerEndpoint (..)`.
- Replace only the selected import in `test/IssueFanoutAppServerSpec.hs`: met. The selected file diff is a one-import replacement.
- Preserve assertions, helper calls, endpoint values, failure text, source-scan needles, fixture setup, and test names: met. Focused scans and `watcher-core-test` confirm the named tests remain reachable and passing.
- Run focused selected-file scans: met. The old facade import is gone from the selected file and the issue-fanout app-server assertions remain in the exported test list.
- Run broad facade scan: met. `test/IssueFanoutAppServerSpec.hs` is removed from remaining `CodexWatcher.AppServerClient` users; remaining hits are out of scope for this round.
- Diff/scope review: met. The only non-orchestrator changed path is `test/IssueFanoutAppServerSpec.hs`; no public facade, exposure, docs, package descriptor, other tests, test-support, or production files were changed.
- Baselines: met. `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check` all passed.

### Decision
**APPROVED**

### Evidence
The integrated implementation preserves behavior and stays inside the selected implementation scope. The selected test now imports `AppServerEndpoint (..)` from the direct transport owner, and the direct owner already exports that type. The old `CodexWatcher.AppServerClient` facade import is absent from `test/IssueFanoutAppServerSpec.hs`, while all issue-fanout app-server checks remain in `issueFanoutAppServerTests` and pass under `watcher-core-test`.

The broad `CodexWatcher.AppServerClient` scan still reports expected out-of-scope facade, Cabal exposure, docs/policy, policy-test, and other-test references. This round does not claim deprecation, removal, Cabal exposure cleanup, public facade removal, milestone completion, terminal completion, package publication, or release approval.
