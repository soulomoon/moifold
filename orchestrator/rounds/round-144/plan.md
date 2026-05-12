### Goal

Move only `test/RunnerGuardSpec.hs` off the public
`CodexWatcher.AppServerClient` compatibility facade by importing
`AppServerClientFailure (..)`, `JsonRpcError (..)`, and
`formatAppServerClientFailure` from
`CodexWatcher.Workflow.Agent.Codex.Client`, and `AppServerEndpoint` from
`CodexWatcher.Workflow.Agent.Codex.Transport`.

This round preserves all existing RunnerGuard behavior coverage: active-turn
inspection, materialization fallback, problem mapping, failure-formatting
details, repair-launch sequencing, endpoint-backed fake app-server behavior,
and guard config helper coverage.

### Approach

Make a single import-only change in `test/RunnerGuardSpec.hs`. Replace the
current combined facade import:

```haskell
import CodexWatcher.AppServerClient
  ( AppServerClientFailure (..)
  , AppServerEndpoint
  , JsonRpcError (..)
  , formatAppServerClientFailure
  )
```

with direct owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client
  ( AppServerClientFailure (..)
  , JsonRpcError (..)
  , formatAppServerClientFailure
  )
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
```

Do not change assertions, helper functions, endpoint-backed fixture behavior,
`runnerGuardActiveTurnInspectionTests`, package descriptors, `test/Main.hs`,
`test/TestSupport/Workflow.hs`, `test/TestSupport/AppServer.hs`, production
files, direct-owner modules, docs/policy, public facade exposure, deprecation,
or removal state. Reference `orchestrator/project-contract.md` for the shared
compatibility rules: preferred imports are evidence-producing cleanup only, not
public deprecation, Cabal exposure cleanup, facade removal approval, release
approval, or terminal completion.

Worker fan-out is not justified. The selected extraction has one file, one
import boundary, no independent ownership split, and `state.json` records
`worker_mode: "none"` with `max_parallel_rounds: 1`. Do not write
`worker-plan.json`.

### Steps

1. Edit only `test/RunnerGuardSpec.hs`.
2. Replace the `CodexWatcher.AppServerClient` import with the two direct-owner
   imports listed above.
3. Leave all test bodies, helper code, fixture setup/cleanup, request
   assertions, failure-formatting assertions, repair-launch assertions,
   endpoint-backed fake app-server helpers, RunnerGuard config helpers, and
   exported `runnerGuardActiveTurnInspectionTests` unchanged.
4. Confirm the target file no longer imports `CodexWatcher.AppServerClient`.
5. Confirm no out-of-scope files changed, especially production files,
   `test/Main.hs`, `test/TestSupport/Workflow.hs`,
   `test/TestSupport/AppServer.hs`, `test/FacadeImportPolicySpec.hs`, package
   descriptors, docs/policy, `src/CodexWatcher/AppServerClient.hs`, and
   direct-owner client/transport modules.
6. Record in implementation notes that this is import convergence only and
   does not approve public facade deprecation/removal, Cabal exposure cleanup,
   package descriptor cleanup, milestone completion, release approval, or
   terminal completion.

### Verification

Run focused scans first:

```sh
rg -n "CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.(Client|Transport)|AppServerClientFailure|JsonRpcError|formatAppServerClientFailure|AppServerEndpoint" test/RunnerGuardSpec.hs
rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal agent-workflow-* || true
git diff -- test/RunnerGuardSpec.hs
git diff --name-only
```

The selected-file scan should show no `CodexWatcher.AppServerClient` import in
`test/RunnerGuardSpec.hs`, and should show the direct client/transport imports.
The broad scan may still list out-of-scope remaining facade users and policy
references, but must not list `test/RunnerGuardSpec.hs`.

Run behavior and baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

`cabal test watcher-core-test` is the required behavior gate for the preserved
RunnerGuard assertions. If a narrower invocation for
`RunnerGuardSpec.runnerGuardActiveTurnInspectionTests` is available in the
local test harness, it may be run before the full watcher-core test, but it
does not replace the full `watcher-core-test` gate.
