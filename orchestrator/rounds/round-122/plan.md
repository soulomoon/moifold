### Goal

Move only `src/CodexWatcher/AutomaticLoop/Runner.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by importing the direct owner module for exactly the runner symbols it uses: `AppServerEndpoint`, `appServerInterpreterFromEndpoint`, and `defaultAppServerClientOptions`.

This round is an import-only cleanup under roadmap `2026-05-11-00-highest-value-cleanup` revision `rev-001`, milestone `milestone-003-import-convergence-package-boundaries`, direction `direction-010-appserverclient-import-convergence`, item `round-122-automatic-loop-runner-appserverclient-import-convergence`. It relies on the accepted round-121 `AutomaticLoopRunnerSpec.automaticLoopRunnerTests` coverage gate and must preserve the project-contract invariants for public compatibility facades, package/module boundaries, dry-run safety, command/action ordering, and compatibility cleanup sequencing.

### Approach

Keep the implementation to a single production import edit in `src/CodexWatcher/AutomaticLoop/Runner.hs`.

Replace the existing open facade import:

```haskell
import CodexWatcher.AppServerClient
```

with the direct owner import:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Transport
  ( AppServerEndpoint
  , appServerInterpreterFromEndpoint
  , defaultAppServerClientOptions
  )
```

Do not change any code body, type signature, export list, behavior, tests, package metadata, docs, fixtures, protocol/client/transport owner modules, runtime compatibility files, public API/facade exposure, Cabal exposure, or review/issue orchestration artifacts. Do not create `orchestrator/rounds/round-122/worker-plan.json`; this is a single-file sequential implementation.

### Steps

1. Confirm the pre-implementation worktree state and note any unrelated existing changes without reverting them:

   ```sh
   git status --short --branch
   ```

2. Open `src/CodexWatcher/AutomaticLoop/Runner.hs` and make only the import replacement described above. Leave `runAutomaticLoop`, `automaticLoopAfterTick`, retry/fallback classification, dry-run behavior, execute-mode endpoint-backed interpreter construction, startup-thread refresh, issue-planning fanout, PR-review handoff, runtime compatibility reconciliation, and all other code bodies unchanged.

3. Confirm the direct owner module remains `CodexWatcher.Workflow.Agent.Codex.Transport` for all three required symbols by checking `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`. Do not edit that module.

4. Run the focused round-121 behavior gate:

   ```sh
   printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test
   ```

5. Run the package baseline:

   ```sh
   cabal test watcher-core-test
   cabal build all
   ```

6. Run whitespace checks:

   ```sh
   git diff --check
   git diff --cached --check
   ```

7. Run the positive/negative target import scan proving `Runner.hs` no longer imports the facade and imports the direct owner:

   ```sh
   ! rg -n '^import CodexWatcher\.AppServerClient\b' src/CodexWatcher/AutomaticLoop/Runner.hs
   rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Transport\b' src/CodexWatcher/AutomaticLoop/Runner.hs
   rg -n '\b(AppServerEndpoint|appServerInterpreterFromEndpoint|defaultAppServerClientOptions)\b' src/CodexWatcher/AutomaticLoop/Runner.hs
   ```

8. Run the changed-path guard before writing implementation notes or review artifacts. At that point the only allowed changed paths for this round are `src/CodexWatcher/AutomaticLoop/Runner.hs` and `orchestrator/rounds/round-122/plan.md`:

   ```sh
   git diff --name-only
   git ls-files --others --exclude-standard
   ```

   Treat any additional changed path as out of scope and stop for review. This guard is intentionally stricter than the existing dirty worktree display: implementation should not add or modify anything beyond the runner import and this plan before implementation notes or review artifacts are written.

9. Run explicit forbidden-path guards:

   ```sh
   git diff --name-only | rg '^(docs/|fixtures/|app/|moifold\.cabal|src/CodexWatcher/AppServerClient\.hs|src/CodexWatcher/AppServerProtocol\.hs|agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Runtime/Compatibility|src/CodexWatcher/Runtime/Owner|src/CodexWatcher/Domain/PrReview/LaunchCli\.hs|src/CodexWatcher/Cli/Command/IssueFanout\.hs|test/|orchestrator/rounds/round-122/worker-plan\.json)' && exit 1 || true
   test ! -e orchestrator/rounds/round-122/worker-plan.json
   ```

10. Record implementation notes only after the import edit and validation are complete. The notes should state that this was import-only, list the focused and baseline validation results, record the import scan, record the changed-path/forbidden-path guards, and explicitly state that no worker fan-out was used.

### Verification

Required validation for acceptance:

```sh
printf ':set -Wno-type-defaults\nAutomaticLoopRunnerSpec.automaticLoopRunnerTests\n:quit\n' | cabal repl watcher-core-test
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
! rg -n '^import CodexWatcher\.AppServerClient\b' src/CodexWatcher/AutomaticLoop/Runner.hs
rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Transport\b' src/CodexWatcher/AutomaticLoop/Runner.hs
rg -n '\b(AppServerEndpoint|appServerInterpreterFromEndpoint|defaultAppServerClientOptions)\b' src/CodexWatcher/AutomaticLoop/Runner.hs
git diff --name-only
git ls-files --others --exclude-standard
git diff --name-only | rg '^(docs/|fixtures/|app/|moifold\.cabal|src/CodexWatcher/AppServerClient\.hs|src/CodexWatcher/AppServerProtocol\.hs|agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Workflow/Agent/Codex/|src/CodexWatcher/Runtime/Compatibility|src/CodexWatcher/Runtime/Owner|src/CodexWatcher/Domain/PrReview/LaunchCli\.hs|src/CodexWatcher/Cli/Command/IssueFanout\.hs|test/|orchestrator/rounds/round-122/worker-plan\.json)' && exit 1 || true
test ! -e orchestrator/rounds/round-122/worker-plan.json
```

Behavior evidence must come from the accepted round-121 runner tests and the two baseline package commands, not from new tests or body changes in this round. The target scan must prove the import migration happened in `Runner.hs`, and the path guards must prove the round did not modify protocol/client owner modules, docs, fixtures, cabal metadata, tests, runtime compatibility files, PR-review launch, issue fanout, public facade/API exposure, or worker fan-out artifacts.
