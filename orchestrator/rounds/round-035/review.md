### Checks Run
- Command: `git diff --check`
  Result: pass; no whitespace errors reported.

- Command: `git diff --cached --check`
  Result: pass; no staged whitespace errors reported.

- Command: `cabal build all`
  Result: pass; Cabal reported `Up to date`.

- Command: `cabal test watcher-core-test`
  Result: pass; the full watcher core suite built and ran under GHC 9.12.2, ending with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.

- Command: `find agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src -name '*.hs' -print0 | xargs -0 rg -n '^import '`
  Result: pass; imports match the readiness report's package graph. Core imports only generic workflow siblings plus base/text/bytestring helpers, Codex imports app-server protocol, agent, Aeson, websocket transport, and core observation helpers, and GitHub imports GitHub ids plus Aeson/Text parsing/rendering helpers.

- Command: `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)|import CodexWatcher\\.AppServerProtocol|import CodexWatcher\\.Workflow\\.Agent\\.Codex|import CodexWatcher\\.Workflow\\.GitHub" src test agent-workflow-core agent-workflow-codex agent-workflow-github`
  Result: pass; matches show moifold and tests consuming adapter APIs, plus the compatibility facade importing Codex client/transport. No reverse moifold lifecycle ownership was found in the reusable packages.

- Command: `rg -n "library agent-workflow-core|library agent-workflow-codex|library agent-workflow-github|exposed-modules:|build-depends:" moifold.cabal`
  Result: pass; the three sublibrary sections and their exposed-module/build-dependency blocks are present for review.

- Command: `rg -n "^import CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\\.GitHub|Workflow\\.Moifold|Workflow\\.Types)" agent-workflow-codex/src`
  Result: pass; no matches, so the Codex adapter package has no forbidden moifold lifecycle imports.

- Command: `rg -n "^import CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\\.Agent|Workflow\\.Daemon|Workflow\\.EventLog|Workflow\\.Execution|Workflow\\.Moifold|Workflow\\.Observation|Workflow\\.Permission|Workflow\\.Transaction|Workflow\\.Types)" agent-workflow-github/src`
  Result: pass; no matches, so the GitHub adapter package has no forbidden app-server, Codex, moifold lifecycle, daemon, runtime, healthcheck, repair, or workflow-policy imports.

- Command: `rg -n "Data\\.Aeson|CodexWatcher\\.(AppServerProtocol|Workflow\\.Agent|Workflow\\.Agent\\.Codex|Workflow\\.GitHub|Workflow\\.Moifold|EventLog|Runtime|Daemon|Healthcheck)|WatcherEvent|SomeWatcherState|RuntimeInterpreter|RuntimeOwner|PidFile|CompatibilityWrite|FilePath|\\bIO\\b" agent-workflow-core/src`
  Result: pass; no matches, so core remains free of concrete event/runtime/filesystem/adapter ownership tokens named by the report.

- Command: `sed -n '88,222p' moifold.cabal | rg -n "reexported-modules:|CodexWatcher\\.AppServerProtocol|CodexWatcher\\.Workflow\\.Agent|CodexWatcher\\.Workflow\\.GitHub\\.Ids|websockets"`
  Result: pass; no matches in the main library section, confirming the main library does not reexport adapter modules and does not own websocket transport.

- Command: `sed -n '88,222p' moifold.cabal | rg -n "CodexWatcher\\.AppServerClient|moifold:agent-workflow-(codex|github)"`
  Result: pass; the main library exposes the compatibility wrapper and keeps dependencies on the Codex and GitHub sublibraries.

- Command: `git diff -- moifold.cabal test/Main.hs && git diff --cached -- moifold.cabal test/Main.hs`
  Result: pass; no output, confirming no code, Cabal, or package-boundary test cleanup was made or staged.

### Plan Compliance
- Inspect current source and docs surfaces: met. I inspected the README, implemented API freeze, `moifold.cabal`, `test/Main.hs` package-boundary assertions, project contract, active roadmap verification contract, and roadmap non-goals.

- Generate import-graph evidence: met. The report's import scans were rerun, including negative scans for forbidden core, Codex, and GitHub package edges.

- Write the readiness report sections: met. `docs/agentic-workflow-framework/package-extraction-readiness.md` contains package verdicts, import-graph evidence, dependency ownership, compatibility facade mapping, remaining moifold-owned blockers, boundary-test references, and validation commands.

- Make minimal cleanup only if the report uncovered a real mismatch: met. No mismatch was found. `moifold.cabal` and `test/Main.hs` are unchanged, and the import scans plus full `watcher-core-test` pass.

- Keep the round artifact-only if no readiness gap is found: met for code, Cabal, and tests. The implementation payload is the new readiness report plus a narrow README link. The worktree also has active-round `orchestrator/state.json` control-plane changes present; I did not edit state.

- Re-read against project contract and roadmap verification contract: met. The report explicitly says it is not a publication decision, does not remove compatibility facades, keeps moifold lifecycle/runtime/healthcheck/repair/prompt/schema policy out of reusable packages, and matches the roadmap non-goal of no package publishing.

### Decision
**APPROVED**

### Evidence
The required baseline checks all passed: `git diff --check`, `git diff --cached --check`, `cabal build all`, and `cabal test watcher-core-test`.

The readiness report's Cabal claims match `moifold.cabal`: `agent-workflow-core` depends only on `base`, `bytestring`, and `text`; `agent-workflow-codex` owns `aeson`, `bytestring`, `text`, `websockets`, and `moifold:agent-workflow-core`; `agent-workflow-github` owns `aeson`, `base`, and `text`; the main library depends on the three sublibraries.

The package-boundary assertions in `test/Main.hs` still cover the named contracts: `workflowCoreCabalSublibraryKeepsPackageBoundary`, `workflowCodexCabalSublibraryKeepsPackageBoundary`, `workflowGithubCabalSublibraryKeepsPackageBoundary`, and `workflowMoifoldCabalLibraryDoesNotReexportAdapters`. The full `watcher-core-test` suite passed with those assertions unchanged.

Manual comparison against `orchestrator/project-contract.md`, `docs/agentic-workflow-framework/implemented-api-freeze.md`, and `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/verification.md` found the report aligned with the package-boundary, compatibility-facade, and no-publication invariants.
