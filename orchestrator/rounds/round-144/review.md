### Checks Run
- Command: `rg -n "CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.(Client|Transport)|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerEndpoint" test/RunnerGuardSpec.hs`
  Result: pass. `test/RunnerGuardSpec.hs` imports `AppServerClientFailure (..)`, `JsonRpcError (..)`, and `formatAppServerClientFailure` from `CodexWatcher.Workflow.Agent.Codex.Client`, imports `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`, and has no `CodexWatcher.AppServerClient` import.
- Command: `rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal agent-workflow-* || true`
  Result: pass. Remaining matches are expected out-of-scope facade exposure/users in `moifold.cabal`, other tests, docs, and `src/CodexWatcher/AppServerClient.hs`; no match remains in `test/RunnerGuardSpec.hs`.
- Command: `git diff -- test/RunnerGuardSpec.hs`
  Result: pass. Diff is only the planned import replacement: remove `CodexWatcher.AppServerClient`, add direct client import, and add direct transport import.
- Command: `git diff --name-only`
  Result: pass. Tracked changes are `orchestrator/state.json` and `test/RunnerGuardSpec.hs`; the only changed implementation/test file is the selected `test/RunnerGuardSpec.hs`.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` completed successfully; Cabal reported `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed.`
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.

### Plan Compliance
- Edit only `test/RunnerGuardSpec.hs`: met. The selected implementation/test diff is confined to `test/RunnerGuardSpec.hs`; existing orchestrator state/round artifacts are control-plane artifacts, not implementation changes.
- Replace the `CodexWatcher.AppServerClient` import with direct owner imports: met. The file now imports the failure types and formatter from `CodexWatcher.Workflow.Agent.Codex.Client`, and `AppServerEndpoint` from `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Leave test bodies, helpers, fixture setup, request assertions, failure-formatting assertions, repair-launch assertions, endpoint-backed fake app-server helpers, RunnerGuard config helpers, and exported test group unchanged: met. The diff contains import lines only.
- Confirm the target file no longer imports `CodexWatcher.AppServerClient`: met by the focused `rg` scan.
- Confirm no out-of-scope files changed: met for implementation scope. `git diff --name-only` shows no production files, package descriptors, docs/policy, direct-owner modules, public facade implementation, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/TestSupport/AppServer.hs`, or `test/FacadeImportPolicySpec.hs` changed.
- Record import convergence only, with no public facade deprecation/removal, Cabal exposure cleanup, package descriptor cleanup, milestone completion, release approval, or terminal completion: met in `implementation-notes.md` and consistent with this review.

### Decision
**APPROVED**

### Evidence
The integrated result matches the selected scope exactly. `test/RunnerGuardSpec.hs` no longer imports the `CodexWatcher.AppServerClient` compatibility facade and now imports the planned symbols from their direct owner modules. The diff is import-only, so endpoint parsing, app-server protocol/session handling, request sequencing, failure formatting, repair-launch behavior, fixtures, and assertions remain unchanged.

The broader facade scan still reports expected remaining out-of-scope users and policy references, including `moifold.cabal`, other test modules, docs, and `src/CodexWatcher/AppServerClient.hs`. This review does not treat the import migration as deprecation, removal, Cabal exposure cleanup, package cleanup, milestone completion, release approval, or terminal completion.

Required behavior and baseline gates passed: `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and `git diff --cached --check`.
