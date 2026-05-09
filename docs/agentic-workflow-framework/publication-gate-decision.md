# Publication Gate Decision

Status: publication gate is on deliberate hold; package candidates remain in
candidate state.

Date: 2026-05-09 Asia/Shanghai.

This decision records the terminal gate outcome for the
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates. The release-candidate bundle records useful local evidence,
but the current tree does not have enough terminal-gate evidence or explicit
operator approval for externally visible publication.

No package upload, tag, GitHub release, release announcement, workflow trigger,
or publication command ran in this round. The packages remain local package
candidates.

## Shared Hold Decision

The gate is held for all three packages.

- Hosted CI is not observed for the current branch. Local CI configuration
  coverage is evidence that `.github/workflows/ci.yml` keeps the GHC `9.12.2`
  and Cabal `3.14.2.0` matrix, installs `ripgrep`, and runs
  `cabal build all`, `cabal test watcher-core-test`, and
  `scripts/validate-workflow-packages.sh`, but it is not a hosted CI pass.
- Haddock generated package documentation, but missing per-export
  documentation and link-destination warnings remain. These are still
  publication blockers until the gate explicitly accepts or fixes them.
- There is no explicit user or operator approval for externally visible
  package upload. That is independently sufficient to hold publication.
- The release-candidate bundle and round 049/050 artifacts are evidence for
  package candidates, not publication approval.

Moifold-owned policy boundaries remain unchanged: event schemas and event JSON
`type` fields, schema versions, golden logs, compatibility files,
compatibility facades, healthcheck, repair, runtime ownership, prompt policy,
app-server startup policy, issue/PR lifecycle policy, command execution,
review publication policy, package upload, tag creation, release actions, and
terminal publication approval remain owned by moifold rather than the reusable
workflow packages.

## agent-workflow-core

Decision: hold; keep as a package candidate.

Candidate evidence from the release-candidate bundle:

- `agent-workflow-core` has a standalone `0.1.0.0` descriptor with MIT
  license metadata, package-specific exposed modules, and only generic
  workflow-kernel dependencies.
- Package validation passed through `scripts/validate-workflow-packages.sh`,
  including `cabal check`, local source distribution creation, and descriptor
  archive inspection.
- `cabal build all`, `cabal test watcher-core-test`, and the standalone
  consumer example build/run passed against the package candidate.
- The consumer example exercises `WorkflowSpec`, planned observations,
  `WorkflowM`, `advance`, `emit`, and transition helpers.

Blocker classification:

- Hosted CI is not observed for the current branch.
- Missing per-export Haddock coverage remains for core workflow APIs, with
  link-destination warnings still present.
- There is no explicit user or operator approval for package upload.

The core package boundary remains generic workflow kernel ownership only. It
does not take over moifold event schemas, compatibility files, process/runtime
ownership, healthcheck, repair, or issue/PR lifecycle policy.

## agent-workflow-codex

Decision: hold; keep as a package candidate.

Candidate evidence from the release-candidate bundle:

- `agent-workflow-codex` has a standalone `0.1.0.0` descriptor with MIT
  license metadata, package-specific exposed Codex/app-server modules, and a
  dependency on `agent-workflow-core`.
- Package validation passed through `scripts/validate-workflow-packages.sh`,
  including `cabal check`, local source distribution creation, and descriptor
  archive inspection.
- `cabal build all`, `cabal test watcher-core-test`, and the standalone
  consumer example build/run passed against the package candidate.
- The consumer example constructs `thread/start`, `turn/start`, and
  `thread/read` JSON-RPC requests through package-facing APIs.

Blocker classification:

- Hosted CI is not observed for the current branch.
- Missing per-export Haddock coverage and link-destination warnings remain for
  Codex/app-server APIs.
- There is no explicit user or operator approval for package upload.

The Codex package owns app-server protocol and typed agent adapter surfaces.
Moifold continues to own app-server startup, prompts, structured-output
acceptance, retry escalation, classifier policy, lifecycle routing, daemon
supervision, runtime ownership, healthcheck, and repair.

## agent-workflow-github

Decision: hold; keep as a package candidate.

Candidate evidence from the release-candidate bundle:

- `agent-workflow-github` has a standalone `0.1.0.0` descriptor with MIT
  license metadata, package-specific exposed GitHub modules, and no dependency
  on core, Codex, or moifold.
- Package validation passed through `scripts/validate-workflow-packages.sh`,
  including `cabal check`, local source distribution creation, and descriptor
  archive inspection.
- `cabal build all`, `cabal test watcher-core-test`, and the standalone
  consumer example build/run passed against the package candidate.
- The consumer example constructs pure command specs for `gh pr list`,
  `gh pr view`, and `git push --dry-run`; no command execution is part of the
  package promise.

Blocker classification:

- Hosted CI is not observed for the current branch.
- Missing per-export Haddock coverage and link-destination warnings remain for
  GitHub identifiers, remote metadata, parsers, and command specs.
- There is no explicit user or operator approval for package upload.

The GitHub package owns typed identifiers, remote metadata parsing, and pure
command-spec construction. Moifold continues to own command execution,
issue/PR lifecycle decisions, merge readiness, review publication policy,
healthcheck, repair, runtime ownership, and release publication policy.

## Final Outcome

Publication is deliberately held. The current package candidates may continue
to be validated locally, reviewed, and improved as candidates, but this round
does not approve or perform externally visible publication.
