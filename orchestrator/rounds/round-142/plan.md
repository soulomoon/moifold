### Goal

Migrate only `test/PrReviewLaunchCliSpec.hs` from the public `CodexWatcher.AppServerClient (AppServerEndpoint (..))` compatibility-facade import to the direct owner import `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, while preserving all existing PR-review launch CLI assertions and leaving the public facade unchanged.

### Approach

This is a single-file, import-only migration under the package-boundary cleanup rules in `orchestrator/project-contract.md`. `AppServerEndpoint (..)` is already exported by `CodexWatcher.Workflow.Agent.Codex.Transport`, and nearby tests already use that owner import for endpoint construction. Keep every test body, assertion label, fixture helper, command-rendering expectation, runtime-owner skip assertion, JSON-RPC failure assertion, and decode-failure assertion unchanged.

Do not touch production files, package descriptors, docs or policy text, the public `CodexWatcher.AppServerClient` facade, `test/Main.hs`, `test/TestSupport/Workflow.hs`, `test/TestSupport/AppServer.hs`, `test/AutomaticLoopRunnerSpec.hs`, or any other test module. Do not claim deprecation, Cabal exposure cleanup, public API cleanup, milestone completion, release approval, terminal completion, or public compatibility removal from this round.

Worker fan-out is not justified: the selected scope has one implementation file and one import replacement, with no separable ownership boundary.

### Steps

1. Open `test/PrReviewLaunchCliSpec.hs` and confirm the only `CodexWatcher.AppServerClient` import is exactly:
   `import CodexWatcher.AppServerClient (AppServerEndpoint (..))`
2. Replace that import with:
   `import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`
3. Leave all other imports and every definition in `test/PrReviewLaunchCliSpec.hs` unchanged unless formatting tools require purely local import ordering.
4. Confirm `AppServerEndpoint` construction remains present in the root and non-root endpoint dry-run tests, and the `runLaunch` type signature still uses `Maybe AppServerEndpoint`.
5. Confirm no `worker-plan.json` is added for this round.

### Verification

Run focused source checks first:

```sh
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint' test/PrReviewLaunchCliSpec.hs
rg -n 'module CodexWatcher\.Workflow\.Agent\.Codex\.Transport|AppServerEndpoint \(..\)' agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
```

Expected result: `test/PrReviewLaunchCliSpec.hs` no longer references `CodexWatcher.AppServerClient`, imports `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))`, and still constructs the same `AppServerEndpoint` values.

Run behavior and baseline checks from the active verification bundle:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

If any staging happens before review, also run:

```sh
git diff --cached --check
```

Record remaining broad `CodexWatcher.AppServerClient` users as out of scope rather than blockers for this round, especially public facade/exposure, docs/policy, broader workflow tests, `test/Main.hs`, `test/AutomaticLoopRunnerSpec.hs`, and other test support surfaces.
