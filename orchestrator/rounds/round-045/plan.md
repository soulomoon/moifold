### Goal

Refresh the package-boundary regression assertions so the standalone
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package layout stays protected after the external package and CI validation
rounds. The round should make the tests prove the current `cabal.project`,
`moifold.cabal`, package descriptors, and recursive source trees all agree on
the approved ownership split without weakening existing scans or changing
runtime behavior.

### Approach

Treat this as a focused `watcher-core-test` boundary refresh. The existing
tests in `test/Main.hs` already scan package source trees recursively for
forbidden imports/text and check the standalone package descriptors for
approved dependencies and metadata. Extend that same section instead of adding
another validation script or moving production code.

The main gap to close is package layout drift: a new `.hs` file under one of
the standalone package source roots can be missed unless the package descriptor
also exposes it, and the current hard-coded exposed-module checks do not prove
that the Cabal `exposed-modules` fields and recursive source-tree inventories
match exactly. Add reusable test helpers that derive module names from
recursive `.hs` paths, parse the `exposed-modules` field from the library
section, and compare the two inventories for each package.

Keep the package ownership contract from `orchestrator/project-contract.md`:
`agent-workflow-core` owns generic workflow kernel contracts only;
`agent-workflow-codex` owns Codex app-server protocol and typed agent adapters;
`agent-workflow-github` owns GitHub identifiers, remote metadata, and command
rendering helpers; the main moifold library owns lifecycle policy, daemon
ownership, process execution, compatibility files, healthcheck, and repair.

Do not edit implementation modules, package identity/version metadata, public
docs/Haddock/examples, changelog/release notes, CI design, source distribution
behavior, compatibility facades, event/golden fixtures, roadmap files, merge
or review artifacts, or `orchestrator/state.json`.

### Steps

1. Reconfirm the current package layout inputs before editing:
   - `cabal.project`
   - `moifold.cabal`
   - `agent-workflow-core/agent-workflow-core.cabal`
   - `agent-workflow-codex/agent-workflow-codex.cabal`
   - `agent-workflow-github/agent-workflow-github.cabal`
   - recursive `.hs` files under `agent-workflow-core/src`,
     `agent-workflow-codex/src`, and `agent-workflow-github/src`

2. Edit `test/Main.hs` in the existing `workflowFacadeExtractionTests`
   boundary section. Keep the current tests:
   - `workflowMoifoldCabalConsumesStandaloneWorkflowPackages`
   - `workflowCoreStandalonePackageKeepsPackageBoundary`
   - `workflowCodexStandalonePackageKeepsPackageBoundary`
   - `workflowGithubStandalonePackageKeepsPackageBoundary`
   - `workflowMoifoldCabalLibraryDoesNotReexportAdapters`

3. Add a new focused assertion, for example
   `workflowCabalProjectListsStandaloneWorkflowPackages`, and include it in
   `workflowFacadeExtractionTests` near the existing Cabal boundary checks. It
   should read `cabal.project` and assert:
   - the `packages:` stanza includes exactly the root project `.` plus
     `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github`;
   - no `moifold:agent-workflow-core`,
     `moifold:agent-workflow-codex`, or
     `moifold:agent-workflow-github` internal sublibrary reference appears in
     `cabal.project`.

4. Add small test helpers in `test/Main.hs`, close to the existing Cabal/source
   helper functions:
   - `cabalFieldLines :: Text -> Text -> [Text]`, or equivalent, to parse
     multiline fields inside a Cabal component section;
   - `cabalExposedModules :: Text -> [Text]`, returning normalized module
     names from the `exposed-modules:` field;
   - `sourceModulesUnder :: FilePath -> IO [Text]`, deriving module names from
     recursive `.hs` files under a package `src` root;
   - `sourceModuleFromPath :: FilePath -> FilePath -> Maybe Text`, converting
     paths such as
     `agent-workflow-core/src/CodexWatcher/Workflow/Codec.hs` to
     `CodexWatcher.Workflow.Codec`.

   Reuse the existing recursive `sourceFilesUnder` helper rather than
   hard-coding file names. Keep helper parsing narrow and test-local; do not
   introduce a new Cabal parser dependency for this round.

5. Strengthen each standalone package boundary test so the descriptor and
   source tree inventories match:
   - in `workflowCoreStandalonePackageKeepsPackageBoundary`, assert that
     `sort (cabalExposedModules standaloneCoreSection)` equals
     `sort (sourceModulesUnder ("agent-workflow-core" </> "src"))`;
   - in `workflowCodexStandalonePackageKeepsPackageBoundary`, make the same
     assertion for `agent-workflow-codex`;
   - in `workflowGithubStandalonePackageKeepsPackageBoundary`, make the same
     assertion for `agent-workflow-github`.

   The failure message should name the package and print mismatched modules
   through `assertNoTextMatches` or an equally reviewable diagnostic, so a
   future leak shows the exact missing or extra module.

6. Keep the existing explicit exposed-module ownership checks, but make them
   depend on the parsed Cabal module inventory rather than broad substring
   matches where practical. The expected current inventories are:

   `agent-workflow-core`:
   - `CodexWatcher.Workflow.Audit`
   - `CodexWatcher.Workflow.Codec`
   - `CodexWatcher.Workflow.Daemon.Core`
   - `CodexWatcher.Workflow.DSL`
   - `CodexWatcher.Workflow.EventLog.Commit.Core`
   - `CodexWatcher.Workflow.EventLog.Core`
   - `CodexWatcher.Workflow.EventLog.File.Core`
   - `CodexWatcher.Workflow.Execution.Core`
   - `CodexWatcher.Workflow.Failure`
   - `CodexWatcher.Workflow.Indexed.Spec`
   - `CodexWatcher.Workflow.Permission.Core`
   - `CodexWatcher.Workflow.Spec`
   - `CodexWatcher.Workflow.Transaction.Core`

   `agent-workflow-codex`:
   - `CodexWatcher.AppServerProtocol`
   - `CodexWatcher.Workflow.Agent`
   - `CodexWatcher.Workflow.Agent.Codex`
   - `CodexWatcher.Workflow.Agent.Codex.Client`
   - `CodexWatcher.Workflow.Agent.Codex.Interpreter`
   - `CodexWatcher.Workflow.Agent.Codex.Protocol`
   - `CodexWatcher.Workflow.Agent.Codex.Transport`
   - `CodexWatcher.Workflow.Agent.Ids`
   - `CodexWatcher.Workflow.Agent.Types`
   - `CodexWatcher.Workflow.Observation.Agent`

   `agent-workflow-github`:
   - `CodexWatcher.Workflow.GitHub.Command`
   - `CodexWatcher.Workflow.GitHub.Ids`
   - `CodexWatcher.Workflow.GitHub.Remote`

7. Strengthen `workflowMoifoldCabalConsumesStandaloneWorkflowPackages` only in
   test-local ways:
   - keep the current assertion that `moifold.cabal` no longer defines
     `library agent-workflow-core`, `library agent-workflow-codex`, or
     `library agent-workflow-github`;
   - keep the current assertion that neither the library nor test suite uses
     `moifold:agent-workflow-*`;
   - assert via parsed `build-depends` package names that the main library and
     `watcher-core-test` both depend on the three standalone packages;
   - keep the approved version-bound checks
     `agent-workflow-core >=0.1 && <0.2`,
     `agent-workflow-codex >=0.1 && <0.2`, and
     `agent-workflow-github >=0.1 && <0.2`.

8. Preserve the recursive forbidden-import and forbidden-token scans. If a
   source-tree inventory assertion fails because a package descriptor is
   genuinely stale, make the minimal descriptor correction needed to align the
   package with its existing source tree. Do not move modules or edit source
   implementation as part of this round.

9. During implementation, record evidence in
   `orchestrator/rounds/round-045/implementation-notes.md`: the assertions
   added or strengthened, any descriptor-only correction if one was necessary,
   and the exact validation commands and results.

10. Inspect the final diff for scope. Expected implementation files are
    limited to:
    - `test/Main.hs`
    - `orchestrator/rounds/round-045/implementation-notes.md`
    - one of the three `agent-workflow-*/agent-workflow-*.cabal` descriptors
      only if the new inventory assertion reveals a real descriptor/source
      mismatch

### Verification

Run the focused test gate and baseline checks from the round worktree:

```sh
cabal test watcher-core-test
cabal build all
scripts/validate-workflow-packages.sh
git diff --check
git diff --cached --quiet -- . && printf '%s\n' 'No staged diff; git diff --cached --check not applicable' || git diff --cached --check
```

Also run these static inspection commands to prove the boundary refresh is
present and no package publication behavior was introduced:

```sh
rg -n 'workflowCabalProjectListsStandaloneWorkflowPackages|cabalExposedModules|sourceModulesUnder|sourceModuleFromPath|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary' test/Main.hs
rg -n 'cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage' .
```

The second `rg` command should find no newly introduced upload or publication
command. If it finds pre-existing documentation text or no-upload policy text,
record that distinction in implementation notes rather than changing docs.

### Risks

- A brittle Cabal parser in tests could create false failures. Keep parsing
  scoped to the simple fields this repository uses, and reuse existing helper
  style in `test/Main.hs`.
- Exact source/exposed-module matching will fail if hidden internal modules are
  intentionally added later. That is acceptable for this release-candidate
  package layout; a future round that wants hidden modules should update the
  assertion and justify the new boundary.
- Broad substring scans can produce false positives in comments. Do not weaken
  existing scans in this round; if a false positive appears, narrow the
  diagnostic to parsed imports or identifier tokens while preserving the same
  ownership prohibition.
- `scripts/validate-workflow-packages.sh` may generate local tarballs under
  `dist-newstyle/sdist/`. These are validation artifacts and must remain
  uncommitted.

### Acceptance Criteria

- `test/Main.hs` includes a Cabal-project assertion proving the local project
  lists `.` plus the three standalone workflow package directories and does
  not reference old `moifold:agent-workflow-*` sublibraries.
- Each standalone package boundary test proves its recursive `.hs` source
  module inventory exactly matches the Cabal library `exposed-modules`
  inventory.
- Existing recursive forbidden-import, forbidden-token, dependency, metadata,
  moifold consumer, and no-adapter-reexport checks remain present and are not
  weakened.
- The main moifold library and `watcher-core-test` still depend on
  `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github` with the approved `>=0.1 && <0.2` bounds.
- No implementation modules, event/golden fixtures, compatibility facades,
  package versions/identity, public docs/examples, CI design, roadmap files, or
  `orchestrator/state.json` are changed.
- `cabal test watcher-core-test`, `cabal build all`,
  `scripts/validate-workflow-packages.sh`, and diff hygiene checks pass, or any
  blocker is recorded with exact command output in
  `orchestrator/rounds/round-045/implementation-notes.md`.

### Worker Fan-Out

No worker fan-out. The round has one coherent test-helper surface in
`test/Main.hs`; splitting by package would create overlapping edits to the same
boundary helpers and test list, so do not create `worker-plan.json`.
