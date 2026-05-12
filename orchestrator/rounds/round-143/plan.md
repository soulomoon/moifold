### Goal

Move only `test/AutomaticLoopRunnerSpec.hs` off the public
`CodexWatcher.AppServerClient` compatibility facade by importing
`AppServerClientFailure (..)` from
`CodexWatcher.Workflow.Agent.Codex.Client` and `AppServerEndpoint` from
`CodexWatcher.Workflow.Agent.Codex.Transport`.

This round preserves the existing automatic-loop runner behavior coverage:
endpoint-backed execution must still use the configured endpoint, dry-run must
still avoid live endpoint traffic, and retry classification must still treat
transport failures as transient while keeping decode/replay and invalid-start
failures fatal.

### Approach

Make a single import-only change in `test/AutomaticLoopRunnerSpec.hs`.
Replace the current combined facade import:

```haskell
import CodexWatcher.AppServerClient (AppServerClientFailure (..), AppServerEndpoint)
```

with direct owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerClientFailure (..))
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
```

Do not change assertions, helper functions, endpoint fixture behavior,
`automaticLoopRunnerTests`, package descriptors, `test/Main.hs`, production
files, direct-owner modules, docs/policy, public facade exposure, deprecation,
or removal state. Reference `orchestrator/project-contract.md` for the shared
compatibility rules: preferred imports are evidence-producing cleanup only, not
public deprecation or facade-removal approval.

Worker fan-out is not justified. The selected extraction has one file, one
import boundary, no independent ownership split, and `state.json` records
`worker_mode: "none"` with `max_parallel_rounds: 1`. Do not write
`worker-plan.json`.

### Steps

1. Edit only `test/AutomaticLoopRunnerSpec.hs`.
2. Replace the `CodexWatcher.AppServerClient` import with the two direct-owner
   imports listed above.
3. Leave all test bodies, helper code, fixture setup/cleanup, request
   assertions, retry-classification assertions, and exported
   `automaticLoopRunnerTests` unchanged.
4. Confirm the target file no longer imports `CodexWatcher.AppServerClient`.
5. Confirm no out-of-scope files changed, especially production files,
   `test/Main.hs`, `test/TestSupport/AppServer.hs`, package descriptors,
   docs/policy, `src/CodexWatcher/AppServerClient.hs`, and direct-owner
   client/transport modules.
6. Record in implementation notes that this is import convergence only and
   does not approve public facade deprecation/removal, Cabal exposure cleanup,
   package descriptor cleanup, milestone completion, release approval, or
   terminal completion.

### Verification

Run focused scans first:

```sh
rg -n "CodexWatcher\\.AppServerClient|Workflow\\.Agent\\.Codex\\.(Client|Transport)|AppServerClientFailure|AppServerEndpoint" test/AutomaticLoopRunnerSpec.hs
rg -n "CodexWatcher\\.AppServerClient" src app test docs *.cabal agent-workflow-* || true
git diff -- test/AutomaticLoopRunnerSpec.hs
git diff --name-only
```

The selected-file scan should show no `CodexWatcher.AppServerClient` import in
`test/AutomaticLoopRunnerSpec.hs`, and should show the direct client/transport
imports. The broad scan may still list out-of-scope remaining facade users, but
must not list `test/AutomaticLoopRunnerSpec.hs`.

Run behavior and baseline checks:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

`cabal test watcher-core-test` is the required behavior gate for the preserved
automatic-loop runner assertions. If a narrower invocation for
`AutomaticLoopRunnerSpec.automaticLoopRunnerTests` is available in the local
test harness, it may be run before the full watcher-core test, but it does not
replace the full `watcher-core-test` gate.
