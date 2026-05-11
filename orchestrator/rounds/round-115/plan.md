### Goal

Move only `src/CodexWatcher/Cli/Command/AppServerProbe.hs` off the public
`CodexWatcher.AppServerClient` compatibility facade by importing the same
symbols from their direct owner modules, while preserving `probeAppServer`
behavior and leaving every other importer, test, package descriptor, public
surface, docs, facade exposure, and roadmap completion state unchanged.

### Approach

Keep this round to a narrow production import-only migration in
`src/CodexWatcher/Cli/Command/AppServerProbe.hs`. Replace the current
`CodexWatcher.AppServerClient` import with two direct-owner imports:

```haskell
import CodexWatcher.Workflow.Agent.Codex.Client
  ( formatAppServerClientFailure
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  )
import CodexWatcher.Workflow.Agent.Codex.Transport
  ( AppServerClientOptions (..)
  , defaultAppServerClientOptions
  , sendOneAppServerRequest
  )
```

Exact symbol ownership:

| Existing `CodexWatcher.AppServerClient` symbol in `AppServerProbe.hs` | Direct owner |
| --- | --- |
| `AppServerClientOptions (..)` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `defaultAppServerClientOptions` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `sendOneAppServerRequest` | `CodexWatcher.Workflow.Agent.Codex.Transport` |
| `formatAppServerClientFailure` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseThreadStartThreadId` | `CodexWatcher.Workflow.Agent.Codex.Client` |
| `parseTurnStartTurnId` | `CodexWatcher.Workflow.Agent.Codex.Client` |

The `AppServerClientOptions (..)` constructor/fields must remain imported with
record fields because `probeAppServer` updates
`appServerResponseTimeoutMicros`. Do not change the timeout value, request ids,
optional `thread/read`, smoke `thread/start`, smoke `turn/start`, success text,
failure formatting, endpoint/session/fallback behavior, or CLI semantics.

No worker fan-out is justified. The implementation target is one import block
in one production file, the validation is sequential, and there are no
non-overlapping ownership boundaries to split across workers. Do not create
`orchestrator/rounds/round-115/worker-plan.json`.

### Steps

1. Re-read the selected scope and shared invariants before editing:
   - `sed -n '1,220p' orchestrator/rounds/round-115/selection.md`
   - `sed -n '1,220p' orchestrator/project-contract.md`
   - `sed -n '860,1080p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
2. Confirm the current target import and use sites:
   - `rg -n "^import CodexWatcher\\.AppServerClient|AppServerClientOptions|defaultAppServerClientOptions|formatAppServerClientFailure|parseThreadStartThreadId|parseTurnStartTurnId|sendOneAppServerRequest" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
3. Confirm the direct owner modules export the required symbols and that the
   public facade remains only a compatibility reexport:
   - `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client|formatAppServerClientFailure|parseThreadStartThreadId|parseTurnStartTurnId" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
   - `rg -n "module CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport|AppServerClientOptions|defaultAppServerClientOptions|sendOneAppServerRequest" agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
   - `sed -n '1,80p' src/CodexWatcher/AppServerClient.hs`
4. Edit only `src/CodexWatcher/Cli/Command/AppServerProbe.hs`:
   - remove the `CodexWatcher.AppServerClient` import block;
   - add the direct `CodexWatcher.Workflow.Agent.Codex.Client` import for
     failure formatting and thread/turn start result parsing;
   - add the direct `CodexWatcher.Workflow.Agent.Codex.Transport` import for
     client options, default options, and endpoint request sending;
   - keep the change import-only unless compilation requires local import
     ordering or formatting in the same file.
5. Explicitly reject out-of-scope edits:
   - no changes to other `CodexWatcher.AppServerClient` importers;
   - no `AppServerProbe` behavior, request id, timeout, output, fallback,
     session, parser, or failure-formatting changes;
   - no test, test-support, facade, direct-owner, protocol, Cabal, API, docs,
     deprecation, removal, milestone-completion, or terminal-completion
     changes.
6. Check the target import result immediately:
   - old target import must be gone:
     `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
   - direct client import must be present:
     `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
   - direct transport import must be present:
     `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
7. Inspect the production diff and reject behavior changes:
   - `git diff -- src/CodexWatcher/Cli/Command/AppServerProbe.hs`
   - The production diff should be the import replacement only.
8. Prove the public compatibility surface and direct owner modules were left
   alone:
   - `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
   - `git diff --exit-code -- src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
9. Record the remaining facade users without treating them as this round's
   responsibility:
   - `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
10. Run the focused AppServerProbe coverage added by round 114:
    - `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
11. Run the required suite and build:
    - `cabal test watcher-core-test`
    - `cabal build all`
12. Run round hygiene and state checks:
    - `test ! -e orchestrator/rounds/round-115/worker-plan.json`
    - `git diff --check`
    - `git diff --cached --check`
    - `jq . orchestrator/state.json`
    - after review writes its record: `jq . orchestrator/rounds/round-115/review-record.json`

### Verification

Required implementation evidence:

- Target old-import scan has no matches:
  `! rg -n "^import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- Target direct-owner imports are present:
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Client" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
  `rg -n "^import CodexWatcher\\.Workflow\\.Agent\\.Codex\\.Transport" src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- Production diff for `AppServerProbe.hs` is import-only:
  `git diff -- src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- Focused AppServerProbe command coverage:
  `printf 'AppServerProbeSpec.appServerProbeCommandTests\n:quit\n' | cabal repl watcher-core-test`
- Full watcher-core regression suite:
  `cabal test watcher-core-test`
- Full build:
  `cabal build all`
- Remaining facade import scan is recorded and shows only non-selected users:
  `rg -n "^import CodexWatcher\\.AppServerClient" src app test agent-workflow-core agent-workflow-codex agent-workflow-github`
- Descriptor guard is empty:
  `git diff --exit-code -- moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
- Facade, direct-owner, and protocol diff guard is empty:
  `git diff --exit-code -- src/CodexWatcher/AppServerClient.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
- Worker fan-out remains absent:
  `test ! -e orchestrator/rounds/round-115/worker-plan.json`
- Diff and JSON hygiene:
  `git diff --check`
  `git diff --cached --check`
  `jq . orchestrator/state.json`
  `jq . orchestrator/rounds/round-115/review-record.json` after review

This verification does not approve migration of any other importer, public
facade deprecation or removal, Cabal exposure cleanup, API/docs changes,
package publication, milestone completion, or terminal completion.
