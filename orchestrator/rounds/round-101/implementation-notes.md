### Changes Made
- `app/Main.hs`: replaced the `RepoName (unRepoName)` import from `CodexWatcher.Core.Ids` with the direct owner import from `CodexWatcher.Workflow.GitHub.Ids`; `healthcheckOptionsFromCli`, command dispatch, and behavior were otherwise unchanged.
- `moifold.cabal`: added the minimal executable-only `agent-workflow-github >=0.1 && <0.2` dependency to `executable moifold` after `cabal build all` proved the executable could not import `CodexWatcher.Workflow.GitHub.Ids` through hidden package `agent-workflow-github-0.1.0.0`.

### Tests
- `app/Main.hs` focused scan before edit: confirmed the selected `CodexWatcher.Core.Ids (RepoName (unRepoName))` import and `healthcheckOptionsFromCli` use at `repoFilter = unRepoName <$> options.healthcheckCliRepo`.
- `app/Main.hs` focused scan after edit: confirmed `import CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))` and unchanged `healthcheckOptionsFromCli` conversion.
- Selected old-import scan: `rg -n "import CodexWatcher\\.Core\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test` returned no matches.
- Selected direct-owner import scan: `rg -n "import CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test` found `app/Main.hs` and existing `src/CodexWatcher/Cli/Command/Service.hs`.
- Owner/facade exposure scan: confirmed `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs` defines `CodexWatcher.Workflow.GitHub.Ids` and `newtype RepoName`, and `src/CodexWatcher/Core/Ids.hs` remains present as a facade re-exporting the GitHub IDs module.
- `git diff -- app/Main.hs moifold.cabal`: diff contains only the direct-owner import and the compile-proven executable dependency.
- Initial `cabal build all`: failed before the cabal edit with `Could not load module 'CodexWatcher.Workflow.GitHub.Ids'. It is a member of the hidden package 'agent-workflow-github-0.1.0.0'. Perhaps you need to add 'agent-workflow-github' to the build-depends in your .cabal file.`
- Final `cabal test watcher-core-test`: passed, `1 of 1 test suites (1 of 1 test cases) passed.`
- Final `cabal build all`: passed and linked the `moifold` executable.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no files were staged.

### Notes
Roadmap lineage: `2026-05-11-00-highest-value-cleanup` `rev-001`, round `round-101-app-main-repo-name-import-convergence`.

The compatibility facade `CodexWatcher.Core.Ids` remains available and exposed; no public facade, test, roadmap, state, selection, plan, or prior artifact files were edited. `orchestrator/state.json` was already modified in the worktree before this implementation pass and was left untouched.
