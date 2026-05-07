### Changes Made
- `test/Main.hs`: Hardened the existing workflow boundary tests so `agent-workflow-core/src` is scanned for forbidden moifold lifecycle imports, Aeson imports, runtime/interpreter imports, GitHub adapters, Codex app-server modules, daemon policy modules, and concrete lifecycle/action/event tokens. Tightened the core Cabal component guard to reject the planned forbidden dependency surface while preserving the existing positive exposure checks for generic core modules.
- `orchestrator/rounds/round-003/implementation-notes.md`: Recorded the round implementation and verification evidence.

### Tests
- `test/Main.hs`: Verifies that `agent-workflow-core` keeps generic core definitions, exposes the generic workflow core modules, depends only on the approved generic dependency set, and rejects the expanded forbidden import, package, and concrete-token sets.
- `cabal build all`: PASS.
- `cabal test watcher-core-test`: PASS.
- `rg -n '^(import|import qualified) (Data\.Aeson|CodexWatcher\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\.State|Daemon|DaemonLoop|Domain\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|RunnerGuard|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\.Agent|Workflow\.GitHub|Workflow\.Moifold|Workflow\.Observation))' agent-workflow-core/src`: PASS, no output.
- `rg -n '\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents)\b' agent-workflow-core/src`: PASS, no output.
- `awk 'BEGIN { in_core = 0 } /^library agent-workflow-core$/ { in_core = 1; next } /^library agent-workflow-codex$/ { in_core = 0 } in_core { print }' moifold.cabal | rg -n 'aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold,|moifold:agent-workflow-codex|moifold:agent-workflow-github'`: PASS, no output.
- `git diff --check`: PASS.
- `git diff --cached --check`: PASS.

### Notes
No production ownership fix was required; the strengthened guards passed against the current `agent-workflow-core` source and Cabal component. No event schemas, golden logs, daemon result shapes, dry-run output, action ordering, or facade representation were changed.
