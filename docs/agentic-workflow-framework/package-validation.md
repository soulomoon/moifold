# Package Validation

Status: local validation recipe for external package candidates.

This note records the repeatable local package checks for the current reusable
workflow package candidates:

- `agent-workflow-core-0.1.0.0`
- `agent-workflow-codex-0.1.0.0`
- `agent-workflow-github-0.1.0.0`

These commands validate package metadata and local source distributions only.
They do not upload packages, publish packages, or approve a release. Generated
tarballs under `dist-newstyle/sdist/` are local build artifacts and must not be
committed or uploaded by this validation step.

## Script

Run the repeatable validation entrypoint from any directory:

```sh
scripts/validate-workflow-packages.sh
```

The script resolves the repository root from its own path, runs the package
checks, generates source distributions under `dist-newstyle/sdist/`, verifies
the expected tarballs exist, and checks that each tarball contains its package
root and Cabal descriptor.

## Manual Commands

The script is equivalent to this expanded command list:

```sh
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
```

## Local Artifacts

Successful validation writes these source-distribution artifacts:

- `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`

The repository ignores `dist-newstyle/`, so these files remain uncommitted
local build outputs unless a future release-gate round explicitly authorizes
different handling.
