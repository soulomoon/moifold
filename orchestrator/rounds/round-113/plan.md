### Goal
Move only `src/CodexWatcher/RunnerGuard.hs` off the public
`CodexWatcher.AppServerClient` compatibility facade by importing the same
symbols from their direct owner modules, while preserving all RunnerGuard
behavior and leaving the public facade, Cabal exposure, API, docs, tests, and
all other importers unchanged.

### Approach
Keep this round to a narrow production import-only migration in
`src/CodexWatcher/RunnerGuard.hs`. Replace the current
`CodexWatcher.AppServerClient` import with two direct-owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client
  ( AppServerTurn (..)
  , formatAppServerClientFailure
  , latestTurnById
  , parseThreadReadTurns
  , parseTurnStartTurnId
  , threadReadMaterializationPending
  , threadSystemError
  )
import CodexWatcher.Workflow.Agent.Codex.Transport
  ( AppServerEndpoint
  , defaultAppServerClientOptions
  , sendOneAppServerRequest
  , startThreadWithEndpoint
  )
```

Exact symbol ownership:

| Existing `CodexWatcher.AppServerClient` symbol in `RunnerGuard.hs` | Direct owner |
| --- | --- |
| `AppServerTurn (..)` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `formatAppServerClientFailure` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `latestTurnById` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseThreadReadTurns` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseTurnStartTurnId` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `threadReadMaterializationPending` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `threadSystemError` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `AppServerEndpoint` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `defaultAppServerClientOptions` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `sendOneAppServerRequest` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `startThreadWithEndpoint` | `CodexWatcher.Workflow.Agent.Codex.Transport` |

No worker fan-out is justified. The implementation target is one import block
in one production file, the verification is sequential, and there are no
non-overlapping ownership boundaries to split across workers. Do not create
`orchestrator/rounds/round-113/worker-plan.json`.

### Steps
1. Re-read the selected scope and shared invariants before editing:
   - `sed -n '1,220p' orchestrator/rounds/round-113/selection.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '824,1000p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
2. Confirm the current target imports and use sites:
   - `rg -n "^import CodexWatcher\\.AppServerClient|AppServerEndpoint|AppServerTurn|defaultAppServerClientOptions|formatAppServerClientFailure|latestTurnById|parseThreadReadTurns|parseTurnStartTurnId|sendOneAppServerRequest|startThreadWithEndpoint|threadReadMaterializationPending|threadSystemError" src/CodexWatcher/RunnerGuard.hs`
3. Confirm the direct owner modules export the required symbols and that the
   public facade remains only a compatibility reexport:
   - `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|AppServerTurn|formatAppServerClientFailure|latestTurnById|parseThreadReadTurns|parseTurnStartTurnId|threadReadMaterializationPending|threadSystemError" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   - `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport|AppServerEndpoint|defaultAppServerClientOptions|sendOneAppServerRequest|startThreadWithEndpoint" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
   - `sed -n '1,80p' src/CodexWatcher/AppServerClient.hs`
4. Edit only `src/CodexWatcher/RunnerGuard.hs`:
   - remove the `CodexWatcher.AppServerClient` import block;
   - add the direct `CodexWatcher.Workflow.Agent.Codex.Client` import for
     `AppServerTurn (..)`, parsing, lookup, materialization, system-error, and
     failure-formatting symbols;
   - add the direct `CodexWatcher.Workflow.Agent.Codex.Transport` import for
     endpoint/options/send/thread-start symbols;
   - do not change code bodies, exports, protocol imports, request ids,
     prompts, failure text, session behavior, fallback behavior, stale-turn
     decisions, package descriptors, docs, or tests.
5. If compilation requires a local import adjustment, keep it in
   `src/CodexWatcher/RunnerGuard.hs` only and limit it to formatting or import
   ordering. Do not migrate any other `CodexWatcher.AppServerClient` importer.
6. Check the target import result immediately:
   - old target import must be gone:
     `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/RunnerGuard.hs`
   - direct client import must be present:
     `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/RunnerGuard.hs`
   - direct transport import must be present:
     `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/RunnerGuard.hs`
7. Inspect the production diff and reject behavior changes:
   - `git diff -- src/CodexWatcher/RunnerGuard.hs`
   - The production diff should be the import replacement only.
8. Prove all other importers and public compatibility surfaces were left alone:
   - `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
   - `git diff --exit-code -- agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
9. Run the focused RunnerGuard coverage that now includes the round-111 active
   turn inspection and round-112 repair-launch sequence gates:
   - `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`
10. Run the required suite and build:
    - `cabal test watcher-core-test`
    - `cabal build all`
11. Run round hygiene and state checks:
    - `test ! -e orchestrator/rounds/round-113/worker-plan.json`
    - `git diff --check`
    - `git diff --cached --check`
    - `jq . orchestrator/state.json`
    - after review writes its record: `jq . orchestrator/rounds/round-113/review-record.json`

### Verification
Required implementation evidence:

- Target old-import scan has no matches:
  `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/RunnerGuard.hs`
- Target direct-owner imports are present:
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/RunnerGuard.hs`
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/RunnerGuard.hs`
- Remaining facade import scan is recorded and shows only non-selected users:
  `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
- Focused RunnerGuard coverage from rounds 111 and 112:
  `printf 'RunnerGuardSpec.runnerGuardActiveTurnInspectionTests\n:quit\n' | cabal repl watcher-core-test`
- Full regression suite:
  `cabal test watcher-core-test`
- Full build:
  `cabal build all`
- Descriptor and public facade diff checks are empty:
  `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-codex/agent-workflow-codex.cabal src/CodexWatcher/AppServerClient.hs`
- Direct owner module diff check is empty:
  `git diff --exit-code -- agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
- No worker fan-out artifact:
  `test ! -e orchestrator/rounds/round-113/worker-plan.json`
- Whitespace checks:
  `git diff --check`
  `git diff --cached --check`
- JSON checks:
  `jq . orchestrator/state.json`
  `jq . orchestrator/rounds/round-113/review-record.json` after review

Behavior and surfaces that must remain unchanged: `checkRunnerGuard`,
`startRunnerGuardRepairThread`, repair prompt text, thread/start id 1,
thread/name/set id 2, turn/start id 3, active `thread/read` id 1 with
`includeTurns = True`, materialization-pending handling, `threadSystemError`
handling, latest-turn lookup, turn-completion classification, stale-threshold
decisions, formatted app-server failure details, app-server protocol
constructors, public `CodexWatcher.AppServerClient` exposure, package
descriptors, docs, and every other `CodexWatcher.AppServerClient` importer.
