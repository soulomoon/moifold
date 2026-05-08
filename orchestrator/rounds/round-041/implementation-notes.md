### Changes Made
- `agent-workflow-github/agent-workflow-github.cabal`: added the standalone `agent-workflow-github` package descriptor with package-local metadata, `hs-source-dirs: src`, the existing GitHub adapter module surface, the shared warning stanza, and only `aeson`, `base`, and `text` as dependencies.
- `cabal.project`: added the explicit `agent-workflow-github` local package candidate while keeping the existing moifold package plus the core and Codex standalone packages.
- `test/Main.hs`: extended the GitHub package-boundary assertion to validate the standalone descriptor in addition to the existing internal `moifold:agent-workflow-github` sublibrary.

### Tests
- `test/Main.hs`: verifies the GitHub source tree has no forbidden moifold lifecycle imports or ownership tokens, the internal sublibrary keeps the approved adapter surface and dependency set, and the standalone descriptor records approved metadata, `hs-source-dirs: src`, exposed modules, and only approved dependencies.
- `cabal build agent-workflow-github:lib:agent-workflow-github`: passed.
- `(cd agent-workflow-github && cabal check)`: passed with no errors or warnings.
- `rg -n "^(import|import qualified) CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core\\.|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|WatcherLiveness|WatcherRuntimeStatus|Workflow\\.(Agent|Daemon|EventLog|Execution|Moifold|Observation|Permission|Transaction|Types))" agent-workflow-github/src`: passed; no matches, exit 1 as expected.
- `rg -n "\\b(WatcherEvent|SomeWatcherState|RuntimeCommand|RuntimeInterpreter|CommandReport|IssueConfig|PrConfig|ReviewEvidence|CleanReviewEvidence|Healthcheck|EventLogRepair|runtime-owner|daemon-state\\.json|issue-state\\.json|planning-state\\.json|watcher-state\\.json|block-state\\.json|app-server)\\b" agent-workflow-github/src`: passed; no matches, exit 1 as expected.
- `rg -n "bytestring|containers|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold|agent-workflow-core|agent-workflow-codex" agent-workflow-github/agent-workflow-github.cabal`: returned only `source-repository head` URL metadata at line 19 (`soulomoon/moifold.git`). Manual review confirmed `build-depends` contains none of the forbidden packages.
- `rg -n "aeson >=2\\.2 && <3|base >=4\\.18 && <5|text >=2\\.0 && <3" agent-workflow-github/agent-workflow-github.cabal`: passed; found all three approved dependency bounds.
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.

### Notes
No moifold local-consumer wiring, production behavior, compatibility facades, event schemas, golden fixtures, source distribution artifacts, CI, docs, changelog, or release metadata beyond the package descriptor were changed.

`moifold.cabal` was left unchanged. The existing internal sublibrary remains in place for current moifold consumers until the later consumer-wiring round.

`git diff --cached --check` was not applicable because no files were staged.
