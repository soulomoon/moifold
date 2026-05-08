### Checks Run
- Command: `git status --short`
  Result: pass. Reported tracked doc/controller-state changes and untracked round artifacts: `docs/agentic-workflow-framework/README.md`, `orchestrator/state.json`, `docs/agentic-workflow-framework/package-identity-versioning-contract.md`, and `orchestrator/rounds/round-036/`.
- Command: `git diff`
  Result: pass. Tracked diff is limited to the narrow framework README link plus controller bookkeeping in `orchestrator/state.json`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked implementation and round artifacts are `docs/agentic-workflow-framework/package-identity-versioning-contract.md`, `orchestrator/rounds/round-036/selection.md`, `orchestrator/rounds/round-036/plan.md`, and `orchestrator/rounds/round-036/implementation-notes.md`.
- Command: `rg -n "^(name|version):|^library agent-workflow|exposed-modules:|CodexWatcher\\.Workflow|CodexWatcher\\.AppServerProtocol" moifold.cabal`
  Result: pass. Confirmed `name: moifold`, `version: 0.1.0.0`, named sublibraries `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, plus exposed `CodexWatcher.Workflow.*` and `CodexWatcher.AppServerProtocol` modules.
- Command: `find agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src -name '*.hs' -print | sort`
  Result: pass. Confirmed the current source modules remain under the existing `CodexWatcher.Workflow.*`, `CodexWatcher.AppServerProtocol`, and `CodexWatcher.Workflow.GitHub.*` namespaces.
- Command: `rg -n "agent-workflow-(core|codex|github)|CodexWatcher\\.Workflow|CodexWatcher\\.AppServerProtocol|release|package|compatibility|facade|moifold-owned|source move|module rename" docs/agentic-workflow-framework/package-extraction-readiness.md`
  Result: pass. Confirmed the readiness report backs the package ownership split and keeps publication, lifecycle policy, and compatibility facade removal out of scope.
- Command: `rg -n "agent-workflow-(core|codex|github)|CodexWatcher\\.Workflow|CodexWatcher\\.AppServerProtocol|release|package|compatibility|facade|moifold-owned|source move|module rename" docs/agentic-workflow-framework/implemented-api-freeze.md`
  Result: pass. Confirmed the API freeze records the current package-internal API surface and excludes package publication and compatibility-facade removal.
- Command: `rg -n "upload|publish|cabal upload|source move|module rename|release note|changelog|compatibility facade|descriptor migration|standalone package descriptors" docs/agentic-workflow-framework/package-identity-versioning-contract.md docs/agentic-workflow-framework/README.md`
  Result: pass. Confirmed the new contract explicitly blocks publication, descriptor migration, source moves, module renames, release-note/changelog readiness, and compatibility-facade removal.
- Command: `cabal build all`
  Result: pass. Built `moifold-0.1.0.0`, including `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, the main library, and the `moifold` executable with GHC 9.12.2.
- Command: `cabal test watcher-core-test`
  Result: pass. `watcher-core-test` built, ran, and reported `Test suite watcher-core-test: PASS`; `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors; no staged changes were present.

### Plan Compliance
- Inspect current identity evidence: met. Review confirmed the package name/version and named sublibrary evidence in `moifold.cabal`, plus the package-readiness, API-freeze, project-contract, and roadmap verification constraints.
- Confirm exact current package and module names with source-backed commands: met. `rg` and `find` confirmed `moifold`, version `0.1.0.0`, the three `agent-workflow-*` sublibraries, and current exposed module namespaces.
- Add package identity/versioning contract artifact: met. `docs/agentic-workflow-framework/package-identity-versioning-contract.md` records status, decision table, package names, pre-1.0 initial version policy, module namespace policy, semantic-versioning expectations, compatibility analysis, and release-gate limits.
- Record semantic-versioning expectations: met. The contract defines breaking changes for exposed modules, exports, constructors, functions, class methods, type families, documented behavior, dependency-boundary broadening, and adapter bounds against `agent-workflow-core`.
- Record module namespace policy: met. The contract keeps `CodexWatcher.Workflow.*`, `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent*`, and `CodexWatcher.Workflow.GitHub.*`, and states that no module rename or source move is authorized.
- Add compatibility analysis for current names: met. The contract identifies the current Cabal shape as `moifold` with named internal sublibraries, not standalone package descriptors, and lists the assumptions later metadata, layout, validation, docs, and release-gate rounds may rely on.
- Add narrow README discoverability link: met. The README change is a single link entry under the existing implemented-contract document list.
- Re-read against project and verification contracts: met. The contract keeps package publication blocked until terminal release-gate approval and excludes descriptor migration, source movement, CI readiness, changelog/release-note readiness, event schemas, runtime ownership, lifecycle policy, and compatibility-facade removal.
- Keep edits limited to the expected artifact/documentation scope: met. There were no Haskell source, Cabal/test, generated fixture, release-note, changelog, compatibility facade, package descriptor, source-distribution, or roadmap edits. `orchestrator/state.json` changed only as controller bookkeeping for the active round and was not treated as implementation scope.

### Decision
**APPROVED**

### Evidence
The integrated round is artifact-only and matches the selected item. The new package identity contract is backed by `moifold.cabal`, the package extraction readiness report, the implemented API freeze, the project contract, and the active verification contract. It makes the three external candidate names final for future descriptors while preserving the current package reality: one `moifold` package at `0.1.0.0` with three named internal sublibraries.

The contract does not authorize package upload, package publication, descriptor migration, source movement, module renaming, compatibility-facade removal, Cabal/test/source/generated/release-note/changelog changes, source distribution readiness, or public release readiness. The README diff is a narrow discoverability link. The `orchestrator/state.json` diff is controller state activation for round-036 and contains no substantive implementation change.
