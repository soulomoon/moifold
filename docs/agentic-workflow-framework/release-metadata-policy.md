# Release Metadata Policy

Status: metadata policy for future external package candidates, not a package
descriptor migration, source-distribution readiness claim, release
announcement, upload approval, or publication decision.

This policy defines release metadata requirements for the future standalone
package candidates:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

The current source tree still has one Cabal package, `moifold`, at version
`0.1.0.0`, with those candidates implemented as internal named sublibraries.
Later descriptor, documentation, changelog, source-distribution, and
release-gate rounds may use this policy as their metadata source of truth, but
this policy does not create standalone descriptors or authorize publication.

## Evidence Base

Source-backed inputs for this policy:

- `moifold.cabal` records the current repository package metadata:
  `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`,
  `category: Development`, and `source-repository head` at
  `https://github.com/soulomoon/moifold.git`.
- `moifold.cabal` defines the internal sublibraries `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`.
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
  fixes the external package names, pre-1.0 version expectations, module
  namespace policy, version-bound expectations, ownership limits, and
  release-gate block.
- `docs/agentic-workflow-framework/package-extraction-readiness.md` records
  package ownership, dependency ownership, remaining blockers, and surfaces not
  included in extraction readiness.
- `docs/agentic-workflow-framework/implemented-api-freeze.md` records the
  implemented public surface of the internal sublibraries and the
  moifold-owned policy boundary.
- `orchestrator/project-contract.md` requires metadata, release notes, package
  descriptors, source distributions, and public documentation to preserve the
  package ownership split.
- `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`
  requires metadata truth and blocks package upload or publication outside a
  terminal release-gate round with explicit approval.

## Package Metadata Defaults

The following table gives descriptor-time defaults and wording constraints.
Every value marked "reconfirm" must be checked again when standalone
descriptors are actually written; current `moifold` metadata is evidence, not
automatic final metadata for every external package.

| Package candidate | License | Maintainer | Category | Synopsis | Description constraints | Source repository |
| --- | --- | --- | --- | --- | --- | --- |
| `agent-workflow-core` | Default to `MIT`, reconfirming that the repository license covers the extracted core sources before descriptor migration. | Use an explicit `maintainer` field. The current evidence is `soulomoon`; reconfirm the responsible maintainer before descriptor migration. | Default to `Development`, with wording focused on reusable workflow infrastructure rather than moifold watcher operations. | Typed workflow kernel, replay, and effect plans. | Name the implemented workflow kernel surface: specs, replay, codecs, event-log cores, effect plans, permissions, transactions, audit, daemon projections, and reusable failure classification. Do not claim concrete event-schema ownership, moifold lifecycle policy, filesystem/runtime ownership, healthcheck, repair, or public API stability beyond the approved pre-1.0 contract. | Use the current repository URL as evidence. Later descriptors should point to `https://github.com/soulomoon/moifold.git` until a release-gate or repository split explicitly approves a different source location. |
| `agent-workflow-codex` | Default to `MIT`, reconfirming that the repository license covers the extracted Codex adapter sources before descriptor migration. | Use an explicit `maintainer` field. The current evidence is `soulomoon`; reconfirm the responsible maintainer before descriptor migration. | Default to `Development`, with wording focused on reusable Codex adapter/protocol surfaces rather than watcher supervision. | Codex app-server protocol and typed agent adapters. | Name the implemented adapter surface: app-server protocol, typed agent plans and ids, Codex client/protocol/interpreter/transport, and agent observation helpers. Do not claim app-server startup policy, role prompt policy, structured-output policy, compatibility-facade removal, or moifold lifecycle routing. | Use the current repository URL as evidence. Later descriptors should point to `https://github.com/soulomoon/moifold.git` until a release-gate or repository split explicitly approves a different source location. |
| `agent-workflow-github` | Default to `MIT`, reconfirming that the repository license covers the extracted GitHub adapter sources before descriptor migration. | Use an explicit `maintainer` field. The current evidence is `soulomoon`; reconfirm the responsible maintainer before descriptor migration. | Default to `Development`, with wording focused on pure GitHub parsing and command-spec surfaces rather than PR lifecycle ownership. | Typed GitHub ids, parsers, and command specs. | Name the implemented adapter surface: GitHub ids, remote parsers/classifiers, and pure GitHub/git command specifications. Do not claim command execution policy, PR/issue lifecycle decisions, healthcheck ownership, merge/review publication policy, or Codex/moifold runtime ownership. | Use the current repository URL as evidence. Later descriptors should point to `https://github.com/soulomoon/moifold.git` until a release-gate or repository split explicitly approves a different source location. |

## Field Requirements

Every standalone package descriptor must include explicit release metadata for
the package it describes. Descriptor rounds must not rely on the top-level
`moifold` package metadata as an implicit default.

- `license`: use `MIT` only after confirming the extracted package's source
  files and any generated descriptor text are covered by the repository license
  at descriptor time.
- `author`: current repository evidence is `soulomoon`; descriptor rounds may
  reuse it only after confirming it remains accurate for the standalone
  package.
- `maintainer`: each package needs an explicit maintainer field. Current
  evidence is `soulomoon`, but descriptor rounds must reconfirm the contact and
  ownership before writing standalone descriptors.
- `category`: default to `Development`. Category and adjacent descriptive text
  must describe reusable workflow, adapter, parser, or command-spec surfaces,
  not moifold watcher operations.
- `synopsis`: use one concise, package-specific sentence fragment. It must not
  imply upload approval, source-distribution validity, CI readiness, 1.0 API
  stability, moifold lifecycle ownership, or compatibility-facade removal.
- `description`: describe implemented modules and public non-goals together.
  Descriptions must preserve the package ownership split and must not turn
  moifold-owned runtime, lifecycle, compatibility, prompt, healthcheck, repair,
  or publication policy into reusable package promises.
- `source-repository`: use `source-repository head` with the current repository
  URL until a later approved round proves a different public source location.
  Source metadata must not imply a package has been uploaded or that a source
  distribution has passed validation.

## Changelog And Release Notes

This round creates no changelog entry and no release-note entry.

Later changelog and release-note work must distinguish internal extraction
history from public package API promises:

- Changelog entries may describe descriptor creation, package layout changes,
  and API changes only when those changes have landed and been validated.
- Public release notes must call out pre-1.0 status, package ownership,
  compatible import/module expectations, breaking changes, validation evidence,
  remaining moifold-owned policy, and compatibility-facade status.
- Release notes must not read as an announcement, upload approval, source
  distribution approval, or public release readiness claim before the terminal
  release-gate round approves that evidence.
- Breaking changes while the packages remain pre-1.0 must be called out in the
  changelog and release-gate evidence once those artifacts exist.

## Metadata Truth Rules

Every descriptor field, README or Haddock claim, changelog entry, release-note
statement, and source-distribution description must be backed by implemented
source, current docs, or explicit release-gate evidence.

Metadata must not claim any of the following unless a later approved round
proves that specific claim:

- package upload or public release approval;
- standalone descriptor readiness before descriptors exist and pass review;
- source-distribution validity before `cabal check` and source-distribution
  validation run for the relevant package candidate;
- CI coverage beyond the checks that actually ran;
- public API stability beyond the approved pre-1.0 package contract;
- compatibility-facade removal or deprecation readiness;
- ownership of concrete `WatcherEvent` schemas, event JSON `type` fields,
  schema migrations, golden replay policy, or compatibility files;
- healthcheck, repair, app-server startup policy, daemon/runtime ownership,
  filesystem writes, prompt policy, structured-output policy, issue/PR
  lifecycle support, merge readiness, or review/publication decisions.

Package descriptions must preserve the ownership split recorded in
`orchestrator/project-contract.md` and
`docs/agentic-workflow-framework/package-identity-versioning-contract.md`.
Reusable workflow packages may expose typed data, pure helpers, protocol
adapters, and effect interpretation contracts. Moifold remains the concrete
product and runtime owner.

## Descriptor-Time Checklist

Before any later round writes standalone package descriptors, it must confirm:

- the package name matches the package identity contract;
- the version remains an independently chosen pre-1.0 package version unless a
  release-gate contract approves otherwise;
- license, author, maintainer, category, synopsis, description, and
  source-repository fields match this policy or record a source-backed
  deviation;
- package descriptions name only implemented public surfaces;
- changelog and release-note text does not overstate publication or
  compatibility promises;
- no metadata claims package upload, source-distribution readiness, CI
  readiness, compatibility-facade removal, or moifold lifecycle migration
  without specific evidence from an approved later round.
