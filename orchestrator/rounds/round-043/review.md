### Checks Run
- Command: `scripts/validate-workflow-packages.sh`
  Result: pass; the script resolved the repository root, ran `cabal check` for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, generated all three source distributions under `dist-newstyle/sdist/`, verified the expected tarballs and Cabal descriptors, printed the artifact summary, and reported that no upload or package publication command was run.
- Command: `(cd agent-workflow-core && cabal check)`
  Result: pass; Cabal reported no errors or warnings.
- Command: `(cd agent-workflow-codex && cabal check)`
  Result: pass; Cabal reported no errors or warnings.
- Command: `(cd agent-workflow-github && cabal check)`
  Result: pass; Cabal reported no errors or warnings.
- Command: `cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-core`
  Result: pass; Cabal wrote `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`.
- Command: `cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-codex`
  Result: pass; Cabal wrote `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`.
- Command: `cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-github`
  Result: pass; Cabal wrote `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`.
- Command: `test -f dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`
  Result: pass.
- Command: `test -f dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`
  Result: pass.
- Command: `test -f dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`
  Result: pass.
- Command: `tar -tzf dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz | rg '^agent-workflow-core-0.1.0.0/agent-workflow-core\.cabal$'`
  Result: pass; found `agent-workflow-core-0.1.0.0/agent-workflow-core.cabal`.
- Command: `tar -tzf dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz | rg '^agent-workflow-codex-0.1.0.0/agent-workflow-codex\.cabal$'`
  Result: pass; found `agent-workflow-codex-0.1.0.0/agent-workflow-codex.cabal`.
- Command: `tar -tzf dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz | rg '^agent-workflow-github-0.1.0.0/agent-workflow-github\.cabal$'`
  Result: pass; found `agent-workflow-github-0.1.0.0/agent-workflow-github.cabal`.
- Command: `cabal build all`
  Result: pass; Cabal reported the project was up to date.
- Command: `cabal test watcher-core-test`
  Result: pass; `watcher-core-test` completed successfully and Cabal reported 1 of 1 test suites passed.
- Command: `git diff --check`
  Result: pass; no whitespace errors.
- Command: `git diff --cached --quiet -- . && printf '%s\n' 'No staged diff; git diff --cached --check not applicable' || git diff --cached --check`
  Result: pass; printed `No staged diff; git diff --cached --check not applicable`.
- Command: `git status --short --ignored=matching dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`
  Result: pass; reported `!! dist-newstyle/`, confirming the generated tarballs are ignored local artifacts.
- Command: `git ls-files --stage dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`
  Result: pass; no output, confirming the generated tarballs are not staged or tracked.
- Command: `rg -n "cabal[[:space:]]+upload|stack[[:space:]]+upload|hackage-upload|curl[[:space:]].*hackage|twine[[:space:]]+upload" scripts/validate-workflow-packages.sh docs/agentic-workflow-framework/package-validation.md docs/agentic-workflow-framework/README.md orchestrator/rounds/round-043/implementation-notes.md`
  Result: pass; no executable package upload command was found.
- Command: `rg -n "^packages:|agent-workflow-(core|codex|github)|^version:" cabal.project agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal`
  Result: pass; `cabal.project` lists the three package candidates, and all three descriptors define version `0.1.0.0`.

### Plan Compliance
- Step 1, reconfirm package candidates and versions: met. `cabal.project` lists `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; the descriptors define `0.1.0.0` for each package.
- Step 2, add a top-level repeatable validation script: met. `scripts/validate-workflow-packages.sh` is executable, resolves the repository root from its own path, validates exactly the three package candidates, runs the package-level checks, generates `dist-newstyle/sdist` artifacts, verifies tarball existence and descriptor contents, prints commands, and ends with an artifact summary and no-upload statement.
- Step 3, add focused package-validation documentation: met. `docs/agentic-workflow-framework/package-validation.md` records covered package candidates, the no-upload boundary, manual commands, expected artifact paths, and local-artifact handling.
- Step 4, add a narrow framework README link: met. `docs/agentic-workflow-framework/README.md` adds only an index entry for `package-validation.md`.
- Step 5, record exact implementation validation evidence: met. `orchestrator/rounds/round-043/implementation-notes.md` records the script command list, manual command list, artifact paths, no-upload status, ignored `dist-newstyle/` handling, and baseline validation results.
- Step 6, inspect final diff for scope: met for the implementation payload. The implemented payload is limited to the new validation script, focused package-validation doc, README index link, and implementation notes. The active `orchestrator/state.json` review-state change is controller state for this live round and was not edited during review.
- Verification contract: met. Source distribution validation, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and cached diff applicability checks all passed.

### Decision
**APPROVED**

### Evidence
The round satisfies selected `item-043-package-check-and-sdist`: reviewers now have a repeatable script plus documented manual commands for `cabal check`, `cabal sdist`, tarball existence checks, and tarball descriptor checks for all three workflow package candidates.

The generated source distributions are local ignored artifacts under `dist-newstyle/sdist/` and are not staged or tracked. The reviewed script, docs, and implementation notes contain no executable package upload command, and the docs explicitly preserve the no-upload/no-publication boundary.

The change stays inside the approved release-validation plumbing scope. It does not change package identities, descriptors, dependency bounds, compatibility facades, event schemas, golden fixtures, lifecycle/runtime/healthcheck/repair ownership, CI, changelog/release notes, examples, or package publication behavior.
