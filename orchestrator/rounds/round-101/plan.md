### Goal
Move the `app/Main.hs` `RepoName (unRepoName)` import from the combined
`CodexWatcher.Core.Ids` compatibility facade to the direct owner module
`CodexWatcher.Workflow.GitHub.Ids`, while preserving CLI healthcheck option
conversion, command behavior, package-boundary contracts, and public
compatibility facade exposure.

### Approach
Keep this as a narrow sequential import-convergence slice. Change only the
`app/Main.hs` import unless the executable compile proof shows Cabal cannot
resolve the direct owner module from the executable component. In that case,
make only the minimal descriptor fix needed for the `moifold` executable to
depend directly on `agent-workflow-github`; do not touch library exposure,
public facade modules, tests, runtime behavior, roadmap artifacts, or state.

Use `orchestrator/project-contract.md` as the shared invariant source,
especially the package/module boundary and public compatibility facade rules.
This round is not a deprecation, removal, Cabal exposed-module cleanup,
milestone completion, release, or terminal-completion claim.

### Steps
1. Reconfirm the selected surface before editing:
   - `rg -n "CodexWatcher\\.Core\\.Ids \\(RepoName \\(unRepoName\\)\\)|CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(unRepoName\\)\\)|unRepoName|healthcheckOptionsFromCli" app/Main.hs`
   - Verify `healthcheckOptionsFromCli` still only maps
     `options.healthcheckCliRepo` through `unRepoName` into `repoFilter`.
2. Apply the only intended source edit:
   - In `app/Main.hs`, replace
     `import CodexWatcher.Core.Ids (RepoName (unRepoName))`
     with
     `import CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))`.
   - Do not change CLI command dispatch, healthcheck option construction, or
     any other imports unless formatting requires local import ordering.
3. Run focused import and owner scans:
   - `rg -n "import CodexWatcher\\.Core\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test`
   - `rg -n "import CodexWatcher\\.Workflow\\.GitHub\\.Ids \\(RepoName \\(unRepoName\\)\\)" app/Main.hs src test`
   - `rg -n "module CodexWatcher\\.Core\\.Ids|module CodexWatcher\\.Workflow\\.GitHub\\.Ids|newtype RepoName|unRepoName" src agent-workflow-github app test`
   - Record that `CodexWatcher.Core.Ids` remains present and exposed; do not
     remove or deprecate the facade.
4. Check descriptor reachability before and after compile:
   - Inspect the `moifold` executable stanza in `moifold.cabal`.
   - If `cabal build all` reports that the executable cannot import
     `CodexWatcher.Workflow.GitHub.Ids` because `agent-workflow-github` is not
     a direct dependency, add `agent-workflow-github >=0.1 && <0.2` only to the
     executable `build-depends`.
   - Do not change library exposed modules, other components, package
     candidates, or compatibility facade exposure.
5. Review the diff for scope:
   - `git diff -- app/Main.hs moifold.cabal`
   - Confirm the diff contains only the import change and, if compile-proven
     necessary, the minimal executable dependency.
6. Run the required baseline verification:
   - `cabal test watcher-core-test`
   - `cabal build all`
   - `git diff --check`
   - `git diff --cached --check`
7. If a verification command fails, fix only failures directly caused by this
   import convergence slice. If a failure points outside the selected surface,
   stop and report it as an out-of-scope blocker instead of broadening the
   round.

### Verification
The implementation is correct when:

- `app/Main.hs` imports `RepoName (unRepoName)` from
  `CodexWatcher.Workflow.GitHub.Ids`.
- `healthcheckOptionsFromCli` still converts the optional CLI repo filter with
  `unRepoName <$> options.healthcheckCliRepo` and all command dispatch behavior
  is unchanged.
- `CodexWatcher.Core.Ids` remains available and exposed as a public
  compatibility facade.
- Package descriptor changes are absent unless compile proof required the
  minimal executable `agent-workflow-github` dependency.
- The focused import scans show no remaining selected `app/Main.hs` import from
  `CodexWatcher.Core.Ids` and no accidental broad import churn.
- `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
  `git diff --cached --check` pass.

### Worker Fan-Out
No worker fan-out is justified. The selected extraction is one sequential
`app/Main.hs` import change with a possible single executable descriptor
adjustment only if compile proof requires it, so there are no independent
non-overlapping worker ownership boundaries.
