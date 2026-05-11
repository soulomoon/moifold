### Goal

Move only `src/CodexWatcher/Healthcheck.hs` off the public `CodexWatcher.AppServerClient` compatibility facade by replacing that facade import with direct Codex owner imports for the symbols already used by Healthcheck.

This round is import convergence only. It must not change Healthcheck code bodies, behavior, tests, package descriptors, public facade exposure, owner modules, app-server protocol, docs, other importers, milestone state, or removal/deprecation policy. Shared invariants remain governed by `orchestrator/project-contract.md`.

### Approach

Use a sequential single-file edit. Replace the unqualified `CodexWatcher.AppServerClient` import in `src/CodexWatcher/Healthcheck.hs` with explicit imports from the modules that own the currently used symbols:

- `CodexWatcher.Workflow.Agent.Codex.Client`: `formatAppServerClientFailure`, `parseThreadReadTurns`, and the `AppServerTurn` field accessors needed by existing Healthcheck code.
- `CodexWatcher.Workflow.Agent.Codex.Transport`: `AppServerEndpoint`, `defaultAppServerClientOptions`, `sendOneAppServerRequest`, and the `AppServerClientOptions` field accessor used by the existing record update.

Keep the existing `CodexWatcher.AppServerProtocol` import as the source of `threadReadRequest`, and keep `CodexWatcher.Core.Ids` as the source of `RequestId`, `ThreadId`, and `TurnId`. Do not touch `src/CodexWatcher/AppServerClient.hs` or the direct owner modules.

No worker fan-out is justified: the write set is one production import section plus this plan, and the verification is sequential.

### Steps

1. Edit only `src/CodexWatcher/Healthcheck.hs`.
2. Remove `import CodexWatcher.AppServerClient`.
3. Add explicit imports:
   - `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..), formatAppServerClientFailure, parseThreadReadTurns)`
   - `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerClientOptions (..), AppServerEndpoint, defaultAppServerClientOptions, sendOneAppServerRequest)`
4. Preserve all existing Healthcheck definitions and behavior, including `checkAppServerThread`, request id `9001`, `includeTurns = True`, the `5000000` microsecond timeout override, skip reasons, latest-turn reporting, and failure formatting.
5. Do not create `orchestrator/rounds/round-117/worker-plan.json`.
6. Leave all other source, test, docs, package descriptor, protocol, and facade files unchanged.

### Verification

Run the focused import scans:

```sh
! rg -n '^import CodexWatcher\.AppServerClient\b' src/CodexWatcher/Healthcheck.hs
rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Client\b' src/CodexWatcher/Healthcheck.hs
rg -n '^import CodexWatcher\.Workflow\.Agent\.Codex\.Transport\b' src/CodexWatcher/Healthcheck.hs
```

Run the round-116 focused Healthcheck app-server coverage and the baseline build/test gates:

```sh
printf 'HealthcheckSpec.healthcheckAppServerThreadInspectionTests\n:quit\n' | cabal repl watcher-core-test
cabal test watcher-core-test
cabal build all
git diff --check
git diff --cached --check
```

Run diff guards proving the scope stayed import-only and did not touch forbidden surfaces:

```sh
git diff --name-only -- src/CodexWatcher/AppServerClient.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs \
  agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs \
  src/CodexWatcher/AppServerProtocol.hs \
  '*.cabal' 'package.yaml' 'cabal.project*' test docs app

git diff --name-only -- . ':!src/CodexWatcher/Healthcheck.hs' ':!orchestrator/rounds/round-117/plan.md' ':!orchestrator/rounds/round-117/selection.md' ':!orchestrator/state.json'

test ! -e orchestrator/rounds/round-117/worker-plan.json
```

Run lifecycle state checks:

```sh
jq -e '
  .roadmap_id == "2026-05-11-00-highest-value-cleanup"
  and .roadmap_revision == "rev-001"
  and .controller_stage == "dispatch-rounds"
  and .active_round_id == "round-117"
  and (.active_rounds | length) == 1
  and .active_rounds[0].round_id == "round-117"
  and .active_rounds[0].stage == "plan"
  and .active_rounds[0].worker_mode == "none"
  and .active_rounds[0].merge_ready == false
  and (.active_rounds[0].roadmap_item_id == "round-117-healthcheck-appserverclient-import-convergence")
' orchestrator/state.json

jq -e '
  (.review_records == null or (.review_records | type == "object"))
  and (.roadmap_update == null)
' orchestrator/state.json
```

Record remaining `CodexWatcher.AppServerClient` users for reviewer context without changing them:

```sh
rg -n 'CodexWatcher\.AppServerClient' src app test docs '*.cabal'
```
