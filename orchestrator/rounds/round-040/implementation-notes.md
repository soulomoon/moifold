### Changes Made
- `agent-workflow-codex/agent-workflow-codex.cabal`: added the standalone `agent-workflow-codex` package descriptor with the approved `0.1.0.0` package identity, metadata, warning policy, exposed Codex adapter modules, `hs-source-dirs: src`, and bounded dependencies on `aeson`, `base`, `bytestring`, `text`, `websockets`, and standalone `agent-workflow-core`.
- `cabal.project`: added the explicit local `agent-workflow-codex` package entry while keeping `.` and `agent-workflow-core` in the project.
- `test/Main.hs`: extended the Codex package-boundary assertion to validate both the existing `moifold:agent-workflow-codex` internal sublibrary and the new standalone descriptor, including exposed modules, approved dependency sets, standalone metadata, and the standalone dependency on `agent-workflow-core`.

### Tests
- `test/Main.hs`: verifies `agent-workflow-codex/src` remains free of moifold lifecycle, daemon, event-log, runtime, GitHub, compatibility-file, and concrete watcher-state ownership imports/tokens; verifies the standalone descriptor exposes the Codex adapter surface and depends on standalone `agent-workflow-core` instead of `moifold:agent-workflow-core`.
- `cabal build agent-workflow-codex:lib:agent-workflow-codex`: passed.
- `(cd agent-workflow-codex && cabal check)`: passed with no errors or warnings.
- `rg -n "^(import|import qualified) CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime\\.|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold\\.|Workflow\\.Types)" agent-workflow-codex/src`: passed; no matches, exit 1 as expected.
- `rg -n "\\b(WatcherEvent|SomeWatcherState|issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|block-state|repair-state|runtime-owner)\\b" agent-workflow-codex/src`: passed; no matches, exit 1 as expected.
- `rg -n "containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|moifold:" agent-workflow-codex/agent-workflow-codex.cabal`: passed; no matches, exit 1 as expected.
- `rg -n "agent-workflow-core >=0\\.1 && <0\\.2|aeson >=2\\.2 && <3|base >=4\\.18 && <5|bytestring >=0\\.12 && <0\\.13|text >=2\\.0 && <3|websockets >=0\\.13 && <0\\.14" agent-workflow-codex/agent-workflow-codex.cabal`: passed; found all approved dependency bounds.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: not applicable; no staging performed.

### Notes
The internal `moifold:agent-workflow-codex` sublibrary remains in `moifold.cabal` and continues to depend on `moifold:agent-workflow-core`; moifold consumer rewiring is intentionally left for the later `direction-007-moifold-local-consumer-wiring` round.
