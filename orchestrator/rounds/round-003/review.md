### Checks Run
- Command: `cabal build all`
  Result: PASS. Cabal reported `Up to date`.
- Command: `cabal test watcher-core-test`
  Result: PASS. The suite rebuilt and completed with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: PASS. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: PASS. No staged whitespace errors reported.
- Command: `rg -n '^(import|import qualified) (Data\.Aeson|CodexWatcher\.(ActionExecutor|AppServerClient|AppServerProtocol|ChildDaemon|Core\.State|Daemon|DaemonLoop|Domain\.|EffectInterpreter|Effects|EventLog|GhGit|Observation|RunnerGuard|Runtime|StateMachine|Supervisor|WatcherRuntimeStatus|Workflow\.Agent|Workflow\.GitHub|Workflow\.Moifold|Workflow\.Observation))' agent-workflow-core/src`
  Result: PASS. No output; `rg` exited 1 because there were no matches.
- Command: `rg -n '\b(SomeWatcherState|WatcherState|WatcherEvent|DaemonObservation|ObservedPolicyTick|EffectPlan|SomeEffect|ActionExecutionMode|RuntimeInterpreter|AppServerTurn|AppServerRequest|GitHubCommandSpec|RepoName|PrConfig|DaemonOptions|DaemonTickResult|runDaemonTickWithEvents|runObservedDaemonTickWithEvents)\b' agent-workflow-core/src`
  Result: PASS. No output; `rg` exited 1 because there were no matches.
- Command: `awk 'BEGIN { in_core = 0 } /^library agent-workflow-core$/ { in_core = 1; next } /^library agent-workflow-codex$/ { in_core = 0 } in_core { print }' moifold.cabal | rg -n 'aeson|directory|filepath|optparse-applicative|singletons|typed-process|unix|websockets|moifold,|moifold:agent-workflow-codex|moifold:agent-workflow-github'`
  Result: PASS. No output; `rg` exited 1 because there were no matches.
- Command: `find agent-workflow-core/src -type f -name '*.hs' | sort`
  Result: PASS. Listed all 12 current `agent-workflow-core/src` Haskell source files.
- Command: `rg -n "sourceImportViolationsUnder|sourceFilesUnder|coreBoundaryForbiddenImportModules|forbiddenConcreteTypes|forbiddenPackageNeedles|cabalBuildDependsPackages|unapprovedCoreDependencyMatches" test/Main.hs`
  Result: PASS. Confirmed the new test wiring uses recursive core source discovery, planned forbidden import/token/package lists, and parsed Cabal dependency names.
- Command: `git diff --name-only -- agent-workflow-core agent-workflow-codex agent-workflow-github src app golden golden/event-log test/golden fixtures 2>/dev/null`
  Result: PASS. No production, adapter, golden, or fixture paths were modified.

### Plan Compliance
- Step 1: Met. The round extends the existing boundary-test area in `test/Main.hs` around `workflowSpecModuleKeepsCoreBoundary` and `workflowCoreCabalSublibraryKeepsPackageBoundary`; no separate ad hoc script was added.
- Step 2: Met. `workflowCoreCabalSublibraryKeepsPackageBoundary` now calls `sourceImportViolationsUnder ("agent-workflow-core" </> "src")`, and `sourceFilesUnder` recursively walks the core source tree. The forbidden import list covers moifold lifecycle/policy, Aeson, runtime/interpreter, GitHub, Codex app-server, and daemon policy/runtime surfaces. The focused import command found no matches.
- Step 3: Met. The concrete token guard includes the planned watcher state/event, daemon observation/tick/result, effect/action, runtime, app-server, GitHub, repo/PR config, daemon option, and daemon runner names. The focused token command found no matches.
- Step 4: Met. The core Cabal guard rejects the planned forbidden packages and any package outside `base`, `bytestring`, and `text`. The focused Cabal command found no forbidden dependency surface in `library agent-workflow-core`.
- Step 5: Met. The positive exposure assertions still require generic core modules, including `CodexWatcher.Workflow.Codec` and `CodexWatcher.Workflow.Daemon.Core`.
- Step 6: Met. Adapter-boundary tests remain in place. No production source, adapter package, golden fixture, event-log fixture, dry-run output, action-ordering implementation, or `CodexWatcher.Workflow.Types` facade file changed.
- Step 7: Met. No existing core ownership violation was exposed by the strengthened checks, so no ownership move was required.
- Step 8: Met. The three focused no-output guard commands were re-run during review, and implementation notes record the implementer's run of the same checks.

### Decision
**APPROVED**

### Evidence
The active roadmap identity is `2026-05-07-00-workflow-kernel-indexing` revision `rev-001`, item `item-003-boundary-guards`, with no worker fan-out for this round. The integrated diff hardens boundary tests in `test/Main.hs` and carries orchestrator round state/artifacts; `git diff --name-only` before review artifacts showed only `orchestrator/state.json` and `test/Main.hs` as tracked changes.

The source-level guard covers all 12 current `agent-workflow-core/src` Haskell files through recursive file discovery. The implemented forbidden import list includes the planned lifecycle/policy, Aeson, runtime/interpreter, GitHub, Codex app-server, and daemon policy/runtime modules. The implemented token and Cabal dependency guards cover the planned forbidden concrete names and dependency surfaces, while preserving the generic core exposure assertions.

Compatibility-sensitive behavior is preserved. No event schema modules, golden logs, daemon result definitions, dry-run output paths, action ordering logic, adapter packages, or facade representation files changed, and `cabal test watcher-core-test` passed the golden replay, event codec, dry-run, action-ordering, daemon core projection, and workflow facade tests.
