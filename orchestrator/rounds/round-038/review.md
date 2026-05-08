### Checks Run
- Command: `cabal build all`
  Result: pass. Built `moifold-0.1.0.0`, including `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`, the main library, and the `moifold` executable with GHC 9.12.2.
- Command: `cabal test watcher-core-test`
  Result: pass. The `watcher-core-test` suite passed: `1 of 1 test suites (1 of 1 test cases) passed`. Output included the package-boundary assertions for workflow core, Codex, GitHub, and moifold compatibility facades.
- Command: `git diff --check`
  Result: pass. No whitespace diagnostics.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace diagnostics.
- Command: `git diff --no-index --check /dev/null docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  Result: pass. Command exited with diff status because the compared file is new, but emitted no whitespace diagnostics.
- Command: `git status --short`
  Result: pass by inspection. Implementation changes are limited to `docs/agentic-workflow-framework/README.md`, new `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`, controller bookkeeping in `orchestrator/state.json`, and round artifacts under `orchestrator/rounds/round-038/`.
- Command: `git ls-files --others --exclude-standard`
  Result: pass by inspection. Untracked files are the new compatibility policy and round artifacts: `selection.md`, `plan.md`, `implementation-notes.md`, plus this review output.

### Plan Compliance
- Create `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`: met. The new policy explicitly says it is not a code migration, package descriptor migration, release note, upload approval, publication decision, deprecation pragma, import migration, wrapper removal, or compatibility-file migration.
- Evidence section cites the required sources: met. The policy cites the readiness report, package identity/versioning contract, release metadata policy, implemented API freeze, project contract, `moifold.cabal`, `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, moifold workflow facades, and `test/Main.hs`.
- Package-by-package preferred-import table: met. The policy covers `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, and keeps preferred-import guidance separate from deprecation/removal approval.
- Compatibility facade status table: met. The table covers `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`.
- Compatibility wrapper and file rules: met. The policy keeps wrappers available, preserves compatibility file names and meanings, and keeps event schemas, golden logs, replay policy, dry-run rendering, action ordering, prompt schemas, structured output, runtime ownership, healthcheck, repair, and operator recovery moifold-owned.
- Deprecation-readiness gates: met. The policy blocks deprecation pragmas or warnings until import coverage, migration path, docs/descriptors, compatibility behavior checks, and reviewer approval exist.
- Removal gates: met. The policy requires a later removal-specific round with import-scan, build, behavior, golden/old-log evidence where relevant, changelog/release-note evidence when visible, descriptor/docs evidence, and reviewer approval.
- Release-note constraints: met. The policy requires pre-1.0 status, accurate facade status, and no implication of upload, source-distribution approval, CI readiness, extra stability, deprecation-readiness, migration completion, or facade removal without later approval.
- README index link: met. `docs/agentic-workflow-framework/README.md` adds a single implemented-contract link to the new policy.
- Scope boundaries: met. No production source, Cabal descriptor, test, generated artifact, changelog, release note, release artifact, package artifact, compatibility facade, wrapper, roadmap, or compatibility-file implementation changes occurred. `orchestrator/state.json` changed only as controller active-round bookkeeping for `round-038`.

### Decision
**APPROVED**

### Evidence
The integrated diff matches the selected artifact-only slice for roadmap `2026-05-09-00-external-package-extraction`, revision `rev-001`, milestone `milestone-001-package-identity-release-contract`, direction `direction-003-compatibility-and-deprecation-policy`, item `item-038-compatibility-deprecation-policy`.

The policy is consistent with the package identity/versioning contract and release metadata policy: it keeps the external candidate names, pre-1.0 framing, metadata truth rules, release-gate block, and moifold-owned lifecycle boundaries intact.

The policy is consistent with the source surfaces inspected during review. `src/CodexWatcher/AppServerClient.hs` reexports the Codex client and transport modules; `src/CodexWatcher/Core/Ids.hs` reexports agent and GitHub ids; `src/CodexWatcher/Workflow/Types.hs`, `Workflow.EventLog`, `Workflow.Execution`, and `Workflow.Permission` expose concrete moifold-facing state, event, replay, execution, and permission behavior. `moifold.cabal` exposes the three named internal sublibraries and keeps the listed facade modules in the main library. `test/Main.hs` contains boundary assertions that passed under `watcher-core-test`.

No package upload, source distribution, descriptor migration, release note, deprecation pragma, import migration, wrapper removal, event schema change, golden fixture change, compatibility-file migration, roadmap edit, production source edit, Cabal edit, or test edit was introduced.
