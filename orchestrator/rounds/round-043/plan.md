### Goal

Add repeatable local package validation for the three workflow package
candidates: `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github`. The round should make `cabal check` and source
distribution generation reviewable for each package, record the exact commands
and generated artifact paths, and avoid any package upload or publication
behavior.

### Approach

Treat this as release-validation plumbing, not package policy or CI matrix
work. The standalone package descriptors already exist and `cabal.project`
already lists the root product plus the three workflow package candidates, so
the implementation should add a small repeatable validation entrypoint and a
focused framework docs note that explain how reviewers can run the package
checks and find the generated tarballs.

Place the repeatable command under top-level `scripts/` because the existing
`scripts/watcher-init/` tree is watcher/runtime setup specific, while this
validation is repo-package tooling. Keep explanatory release-readiness
documentation under `docs/agentic-workflow-framework/`, next to the existing
package identity, metadata, compatibility, API-freeze, and extraction
readiness docs.

Do not change package names, versions, dependency bounds, package identity
policy, release metadata policy, compatibility facades, event schemas, golden
fixtures, moifold lifecycle/runtime/healthcheck/repair ownership, CI config,
public README/Haddock/examples, changelogs, release notes, roadmap files,
review artifacts, merge artifacts, or `orchestrator/state.json`. Refer to
`orchestrator/project-contract.md` for stable package ownership and
compatibility invariants.

### Steps

1. Reconfirm the package candidates and versions from:
   - `cabal.project`
   - `agent-workflow-core/agent-workflow-core.cabal`
   - `agent-workflow-codex/agent-workflow-codex.cabal`
   - `agent-workflow-github/agent-workflow-github.cabal`
   The expected package/version pairs are `agent-workflow-core-0.1.0.0`,
   `agent-workflow-codex-0.1.0.0`, and
   `agent-workflow-github-0.1.0.0`.

2. Add a top-level repeatable validation script, preferably
   `scripts/validate-workflow-packages.sh`, owned by this round. The script
   should:
   - run from the repository root regardless of caller cwd;
   - validate exactly the three package candidates above;
   - run `(cd <package-dir> && cabal check)` for each package;
   - create a deterministic local artifact directory such as
     `dist-newstyle/sdist`;
   - run `cabal sdist --output-directory=dist-newstyle/sdist <package-name>`
     for each package from the repository root;
   - assert that each expected tarball exists at:
     `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`,
     `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`, and
     `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`;
   - inspect each tarball with `tar -tzf <artifact>` and verify it contains
     the expected package root directory and `.cabal` file, for example
     `agent-workflow-core-0.1.0.0/agent-workflow-core.cabal`;
   - print the exact commands it runs and a final artifact-path summary.

3. Add a focused docs artifact under
   `docs/agentic-workflow-framework/`, preferably
   `package-validation.md`. The doc should record:
   - package candidates covered by this validation;
   - the no-upload boundary;
   - the exact manual commands equivalent to the script:

   ```sh
   (cd agent-workflow-core && cabal check)
   (cd agent-workflow-codex && cabal check)
   (cd agent-workflow-github && cabal check)
   cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-core
   cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-codex
   cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-github
   tar -tzf dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz | rg '^agent-workflow-core-0.1.0.0/agent-workflow-core\.cabal$'
   tar -tzf dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz | rg '^agent-workflow-codex-0.1.0.0/agent-workflow-codex\.cabal$'
   tar -tzf dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz | rg '^agent-workflow-github-0.1.0.0/agent-workflow-github\.cabal$'
   ```

   - generated artifact paths:
     `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`,
     `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`, and
     `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`;
   - that generated tarballs remain local build artifacts and must not be
     committed or uploaded by this round.

4. If useful for discoverability, add one narrow link from
   `docs/agentic-workflow-framework/README.md` to the new package-validation
   doc. Keep this as an index link only; do not broaden into public package
   README, Haddock, examples, changelog, or release-note work.

5. Run the new script and capture its exact output summary in
   `orchestrator/rounds/round-043/implementation-notes.md` during the
   implementation stage. The notes must include every `cabal check` command,
   every `cabal sdist` command, and the final artifact paths. They must also
   state explicitly that no upload command was run.

6. Inspect the final diff for scope. Expected implementation files are limited
   to the new validation script, the new focused framework doc, the optional
   framework README link, and
   `orchestrator/rounds/round-043/implementation-notes.md`. Do not edit
   package descriptors unless `cabal check` reveals a real package-readiness
   defect that cannot be represented as validation evidence; if that happens,
   keep the descriptor fix minimal and explain the source-backed reason in
   implementation notes.

### Verification

The implementation is correct when all three package candidates pass
package-level `cabal check`, all three source distributions are generated
locally, the expected tarball paths are recorded and verified, and repository
behavior still passes the baseline checks from the active verification
contract.

Required commands from the round worktree:

```sh
scripts/validate-workflow-packages.sh

(cd agent-workflow-core && cabal check)
(cd agent-workflow-codex && cabal check)
(cd agent-workflow-github && cabal check)

cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-core
cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-codex
cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-github

test -f dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz
test -f dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz
test -f dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz

tar -tzf dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz | rg '^agent-workflow-core-0.1.0.0/agent-workflow-core\.cabal$'
tar -tzf dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz | rg '^agent-workflow-codex-0.1.0.0/agent-workflow-codex\.cabal$'
tar -tzf dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz | rg '^agent-workflow-github-0.1.0.0/agent-workflow-github\.cabal$'

cabal build all
cabal test watcher-core-test
git diff --check
git diff --cached --quiet -- . && echo "No staged diff; git diff --cached --check not applicable" || git diff --cached --check
```

The script may be the canonical way to run the package-specific checks, but
the implementation notes should still record the expanded command list and
artifact paths so reviewers can inspect the validation without reverse
engineering the script.

Generated source-distribution tarballs under `dist-newstyle/sdist/` should be
left uncommitted. If `dist-newstyle/` is already ignored, note that in the
implementation notes; otherwise avoid adding generated tarballs to the diff.

### Worker Fan-Out

No worker fan-out. Although the package checks are package-specific, the
implementation ownership is a single repeatable validation entrypoint plus one
coherent documentation artifact. Splitting by package would create overlapping
edits to the same script and docs, so this round should remain sequential and
should not create `worker-plan.json`.
