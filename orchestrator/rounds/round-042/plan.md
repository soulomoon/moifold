### Goal

Wire the main `moifold` package to consume the local standalone
`agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` package candidates from `cabal.project`, while keeping
the existing moifold compatibility facades and runtime behavior unchanged.

### Approach

Make this a Cabal consumer change, not a source ownership migration. The
standalone package descriptors and source trees already exist under
`agent-workflow-core/`, `agent-workflow-codex/`, and
`agent-workflow-github/`; `cabal.project` already lists those packages beside
the root `moifold` package. This round should therefore switch the root
`moifold.cabal` consumer dependencies from internal sublibrary targets to the
standalone package names and update only the package-boundary assertions that
currently encode the old internal-sublibrary wiring.

Keep compatibility modules such as `src/CodexWatcher/AppServerClient.hs`,
`src/CodexWatcher/Core/Ids.hs`, `src/CodexWatcher/Failure.hs`,
`src/CodexWatcher/EventLog/File.hs`, `src/CodexWatcher/Workflow/EventLog.hs`,
`src/CodexWatcher/Workflow/Execution.hs`, `src/CodexWatcher/Workflow/Permission.hs`,
and `src/CodexWatcher/Workflow/Types.hs` available. Their imports can continue
to name the same `CodexWatcher.Workflow.*` modules; the Cabal dependency
change should make those imports resolve through the local standalone package
candidates instead of `moifold:agent-workflow-*`.

Do not move lifecycle policy, daemon ownership, healthcheck, repair, prompt
policy, event schemas, golden fixtures, source distributions, CI, docs,
changelogs, release notes, package upload, roadmap files, or controller state.
Refer to `orchestrator/project-contract.md` for the stable compatibility and
ownership invariants.

### Steps

1. Update `moifold.cabal` so the root package no longer provides or consumes
   the internal workflow sublibraries:
   - Remove the `library agent-workflow-core` component stanza.
   - Remove the `library agent-workflow-codex` component stanza.
   - Remove the `library agent-workflow-github` component stanza.
   - In the main `library` `build-depends`, replace
     `moifold:agent-workflow-core`, `moifold:agent-workflow-codex`, and
     `moifold:agent-workflow-github` with:
     `agent-workflow-core >=0.1 && <0.2`,
     `agent-workflow-codex >=0.1 && <0.2`, and
     `agent-workflow-github >=0.1 && <0.2`.
   - In `test-suite watcher-core-test` `build-depends`, make the same
     replacement because `test/Main.hs` imports modules from all three
     workflow package candidates directly.
   - Leave the `executable moifold` dependency on `moifold` unchanged.

2. Leave `cabal.project` package entries unchanged:
   - `.` remains the root product package.
   - `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github` remain local project packages.
   - Do not add source distribution, repository, CI, or release validation
     wiring in this round.

3. Update `test/Main.hs` package-boundary assertions to reflect standalone
   package consumption:
   - Rename or revise `workflowCoreCabalSublibraryKeepsPackageBoundary`,
     `workflowCodexCabalSublibraryKeepsPackageBoundary`, and
     `workflowGithubCabalSublibraryKeepsPackageBoundary` so they no longer
     parse `library agent-workflow-*` component sections from `moifold.cabal`.
   - Keep their existing source ownership scans and standalone descriptor
     metadata/dependency checks for `agent-workflow-core/agent-workflow-core.cabal`,
     `agent-workflow-codex/agent-workflow-codex.cabal`, and
     `agent-workflow-github/agent-workflow-github.cabal`.
   - Add assertions that `moifold.cabal` does not contain
     `library agent-workflow-core`, `library agent-workflow-codex`,
     `library agent-workflow-github`, or any `moifold:agent-workflow-*`
     dependency.
   - Add assertions that the main `library` and `watcher-core-test` sections
     depend on the standalone packages with the approved bounds:
     `agent-workflow-core >=0.1 && <0.2`,
     `agent-workflow-codex >=0.1 && <0.2`, and
     `agent-workflow-github >=0.1 && <0.2`.

4. Update `workflowMoifoldCabalLibraryDoesNotReexportAdapters` in
   `test/Main.hs` so `keepsAdapterDependencies` expects standalone
   `agent-workflow-codex` and `agent-workflow-github` dependencies rather than
   `moifold:agent-workflow-codex` and `moifold:agent-workflow-github`. Keep the
   existing checks that the main library does not reexport adapter modules and
   that `src/CodexWatcher/AppServerClient.hs` remains a compatibility facade
   over the Codex client and transport modules.

5. Inspect imports after the Cabal rewrite rather than changing them
   mechanically. If build failures show missing direct package dependencies,
   add only the exact standalone package dependency needed by the component
   that imports those modules. Do not introduce new compatibility modules or
   remove existing facades.

6. Confirm the round did not broaden scope:
   - No changes to event JSON `type` fields, schema versions, golden logs, or
     replay fixtures.
   - No changes to runtime owner files, daemon state files, block/repair state
     files, app-server prompt policy, healthcheck behavior, repair behavior, or
     lifecycle decisions.
   - No edits to `orchestrator/state.json`, roadmap files, implementation
     notes, review artifacts, or merge artifacts.

### Verification

Run these checks from the round worktree:

1. Package-specific standalone builds:
   - `cabal build agent-workflow-core:lib:agent-workflow-core`
   - `cabal build agent-workflow-codex:lib:agent-workflow-codex`
   - `cabal build agent-workflow-github:lib:agent-workflow-github`

2. Product consumer builds:
   - `cabal build moifold:lib:moifold`
   - `cabal build moifold:exe:moifold`

3. Full repo validation:
   - `cabal build all`
   - `cabal test watcher-core-test`

4. Boundary scans:
   - `rg -n "moifold:agent-workflow-(core|codex|github)|^library agent-workflow-(core|codex|github)" moifold.cabal cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
     should produce no matches.
   - `rg -n "agent-workflow-(core|codex|github) >=0.1 && <0.2" moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal`
     should show the expected standalone bounds in `moifold.cabal`, plus the
     existing Codex-to-core dependency in `agent-workflow-codex.cabal`.
   - `rg -n "CodexWatcher\\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain\\.|EventLogRepair|Healthcheck|Runtime\\.|StateMachine|Workflow\\.Moifold\\.)" agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src`
     should not reveal new reusable-package imports of moifold lifecycle,
     runtime, healthcheck, repair, or compatibility ownership modules.

5. Diff hygiene:
   - `git diff --check`
   - `git diff --cached --check` only if the implementer stages files before
     handoff; otherwise record it as not applicable because no staged diff
     exists.

### Worker Fan-Out

No worker fan-out. The change is intentionally sequential because
`moifold.cabal` and the boundary assertions in `test/Main.hs` must be updated
together and verified as one consumer-wiring slice.
