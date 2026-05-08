### Changes Made
- `.github/workflows/ci.yml`: added an explicit strategy matrix with the supported GHC `9.12.2` and Cabal `3.14.2.0` row, then wired `haskell-actions/setup@v2` to install the matrix toolchain values.
- `.github/workflows/ci.yml`: preserved checkout, `cabal update`, `pull_request`, and `push` to `main`, and split CI execution into focused named steps for `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`.
- `.github/workflows/ci.yml`: retry repair added a narrow `Install package validation dependencies` step before `Validate workflow package candidates`; it runs `sudo apt-get update` and `sudo apt-get install -y ripgrep` so the hosted Ubuntu runner provisions the `rg` dependency used by `scripts/validate-workflow-packages.sh`.
- `orchestrator/rounds/round-044/implementation-notes.md`: recorded the implementation scope and verification evidence for review.

### Tests
- Earlier implementation evidence kept: `cabal build all` passed.
- Earlier implementation evidence kept: `cabal test watcher-core-test` passed.
- Retry passed: `scripts/validate-workflow-packages.sh`
- Retry passed: `git diff --check`
- Passed: `git diff --cached --quiet -- .` showed no staged diff, so `git diff --cached --check` was not applicable.
- Retry passed: `rg -n 'ripgrep|validate-workflow-packages|cabal build all|cabal test watcher-core-test|ghc-version|cabal-version' .github/workflows/ci.yml`
- Retry passed: `rg -n 'cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage' .github/workflows/ci.yml scripts/validate-workflow-packages.sh` returned no matches. `rg` exited 1 because there were no matches, which is the expected result for this scan.

### Notes
No change was needed to `scripts/validate-workflow-packages.sh`; it is already executable and remains the canonical package validation entrypoint. The retry addressed the CI portability issue from review by installing `ripgrep` in the workflow before the script runs. The package validator produced `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`, `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`, and `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`. No package upload or publication command was added. `cabal build all` and `cabal test watcher-core-test` were not rerun during this retry because the reviewer already reran them successfully and this repair only provisions the package script dependency.
