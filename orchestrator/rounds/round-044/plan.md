### Goal

Add an explicit CI build matrix for the currently supported Haskell toolchain
and make CI run the existing moifold gates plus the workflow package candidate
validation established in round 043. The CI path must build and test moifold,
then check and package `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` without changing package identity, release policy, or
publication behavior.

### Approach

Treat this as CI validation plumbing only. The current repository source of
truth declares GHC `9.12.2` in `cabal.project`, and the existing GitHub Actions
workflow installs GHC `9.12.2` with Cabal `3.14.2.0`; no inspected roadmap,
descriptor, or doc declares additional supported compiler versions. Therefore
the implementation should make that supported toolchain an explicit
`strategy.matrix` row instead of inventing broader compiler support.

Keep `.github/workflows/ci.yml` as the primary implementation surface. Preserve
the existing `pull_request` trigger and `push` to `main`, and keep the
`watcher-core-test` gate. Extend the job so each matrix row runs:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
```

This reuses the round 043 validation entrypoint for package-level
`cabal check`, `cabal sdist`, expected tarball existence checks, tarball
descriptor inspection, and the explicit no-upload statement. Do not add fake
package-local tests: the three workflow package candidates currently expose
libraries only and do not define package-local test suites, so the current test
gate is the existing moifold `watcher-core-test` consumer/regression suite.

Only edit `scripts/validate-workflow-packages.sh` if CI exposes a real
entrypoint problem, such as missing executable permission, missing `rg` on the
runner, or output that is not useful enough for CI logs. Any script edit must
preserve the exact package list, `cabal check`, `cabal sdist`, tarball
descriptor checks, and no-upload boundary from round 043.

Do not edit package descriptors, `cabal.project`, package versions, public
README/Haddock/examples, changelog/release notes, compatibility facades, event
schemas, golden fixtures, roadmap files, merge/review artifacts, or
`orchestrator/state.json`. Refer to `orchestrator/project-contract.md` for
stable package ownership and compatibility invariants.

### Steps

1. Reconfirm the CI and package validation baseline from:
   - `.github/workflows/ci.yml`
   - `scripts/validate-workflow-packages.sh`
   - `cabal.project`
   - `moifold.cabal`
   - `agent-workflow-core/agent-workflow-core.cabal`
   - `agent-workflow-codex/agent-workflow-codex.cabal`
   - `agent-workflow-github/agent-workflow-github.cabal`

2. Update `.github/workflows/ci.yml` to use an explicit matrix for the
   supported compiler row. Keep the row values aligned with current CI and
   `cabal.project`:

   ```yaml
   strategy:
     fail-fast: false
     matrix:
       include:
         - ghc-version: "9.12.2"
           cabal-version: "3.14.2.0"
   ```

   Use the matrix values in `haskell-actions/setup@v2` instead of hard-coded
   toolchain literals.

3. Preserve the existing checkout and `cabal update` steps. If a new runner
   dependency is necessary for the round 043 script, add the narrowest possible
   install step, for example installing `ripgrep`; otherwise avoid unrelated
   CI setup churn.

4. Replace the single `Run tests` command with focused named steps that run,
   in this order:

   ```sh
   cabal build all
   cabal test watcher-core-test
   scripts/validate-workflow-packages.sh
   ```

   The build step proves moifold and the three local workflow package
   candidates build in the configured project. The test step preserves the
   existing watcher regression gate. The package validation step reuses round
   043 to run package candidate `cabal check` and source-distribution
   validation.

5. If `scripts/validate-workflow-packages.sh` is not executable in the
   repository, fix only that executable bit or invoke it through `bash` in CI.
   Prefer preserving the script as the canonical entrypoint rather than
   duplicating its package command list directly in YAML.

6. During implementation, record evidence in
   `orchestrator/rounds/round-044/implementation-notes.md`: the CI matrix row,
   the exact CI commands added, any script entrypoint adjustment, and the fact
   that no package upload or publication command was added.

7. Inspect the final diff for scope. Expected changed files are limited to:
   - `.github/workflows/ci.yml`
   - `scripts/validate-workflow-packages.sh` only if a real CI entrypoint issue
     requires it
   - `orchestrator/rounds/round-044/implementation-notes.md` during the
     implementation stage

### Verification

Run the same gates locally from the round worktree before review:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
git diff --cached --quiet -- . && printf '%s\n' 'No staged diff; git diff --cached --check not applicable' || git diff --cached --check
```

Also inspect the workflow statically:

```sh
rg -n 'strategy:|matrix:|ghc-version|cabal-version|cabal build all|cabal test watcher-core-test|validate-workflow-packages' .github/workflows/ci.yml
rg -n 'cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage' .github/workflows/ci.yml scripts/validate-workflow-packages.sh
```

The second `rg` command should find no executable package upload or
publication command.

The GitHub Actions job itself should show, for every configured matrix row,
that `cabal build all`, `cabal test watcher-core-test`, and
`scripts/validate-workflow-packages.sh` all run. If remote CI is not available
during implementation, record that the workflow was statically inspected and
that local equivalents passed.

### Risks

- `cabal.project` pins `with-compiler: ghc-9.12.2`; adding unproven compiler
  versions would not be a real supported matrix and may fight the project
  configuration. Keep the matrix to declared support unless a separate source
  of truth is added in another round.
- `scripts/validate-workflow-packages.sh` uses `rg` while the current workflow
  only installs the Haskell toolchain. If Ubuntu runners do not provide
  `ripgrep`, add a narrow install step rather than rewriting package
  validation in YAML.
- Source distributions are generated under `dist-newstyle/sdist/`. They must
  remain ignored local/CI artifacts and must not be uploaded or committed by
  this round.
- CI log clarity matters: if the package validation script fails, reviewers
  need to see which `cabal check`, `cabal sdist`, or tarball assertion failed.
  Preserve or improve the script's command echoing if touching it.

### Acceptance Criteria

- `.github/workflows/ci.yml` contains an explicit matrix covering the supported
  GHC `9.12.2` and Cabal `3.14.2.0` row.
- Each matrix run installs the matrix toolchain through
  `haskell-actions/setup@v2`.
- CI runs `cabal build all` and `cabal test watcher-core-test`; the existing
  watcher test gate is not dropped or weakened.
- CI runs `scripts/validate-workflow-packages.sh`, reusing the round 043
  package validation for all three workflow package candidates.
- No package upload, Hackage publication, version change, descriptor churn,
  public docs/examples, compatibility facade removal, event/golden change,
  roadmap edit, or `orchestrator/state.json` edit is introduced.
- Local verification passes or any blocker is recorded with exact command
  output in `orchestrator/rounds/round-044/implementation-notes.md`.

### Worker Fan-Out

No worker fan-out. This round has one coherent CI workflow surface plus a
single existing package validation entrypoint. Splitting work would create
overlapping ownership of `.github/workflows/ci.yml`, so do not create
`worker-plan.json`.
