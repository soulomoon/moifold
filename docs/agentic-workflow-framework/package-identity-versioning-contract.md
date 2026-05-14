# Package Identity And Versioning Contract

Status: package identity and versioning contract for future release
candidates, not a package publication decision.

This contract fixes the package identity assumptions that later metadata,
layout, validation, documentation, and release-gate rounds may rely on for the
workflow framework candidates:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

The current source tree has a root `moifold` package plus standalone local
package descriptors for these three package candidates. This contract fixes
their package identity; it does not publish packages, remove compatibility
facades, rename modules, tag a release, or approve a public release.

## Evidence Base

Source-backed inputs for this contract:

- `cabal.project` lists the root package and the standalone local package
  candidates `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github`.
- `agent-workflow-core/agent-workflow-core.cabal`,
  `agent-workflow-codex/agent-workflow-codex.cabal`, and
  `agent-workflow-github/agent-workflow-github.cabal` define the current
  package descriptors.
- `moifold.cabal` depends on the standalone package names and does not define
  `library agent-workflow-*` internal components.
- `docs/agentic-workflow-framework/package-extraction-readiness.md` records
  the current dependency ownership and extraction blockers.
- `docs/agentic-workflow-framework/implemented-api-freeze.md` records the
  implemented local package API surface and moifold-owned policy boundary.
- `orchestrator/project-contract.md` keeps package ownership, compatibility
  facades, event schemas, golden logs, runtime ownership, and release approval
  as repo-wide contracts.
- `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`
  requires metadata truth and blocks publication except in a terminal
  release-gate round with explicit approval.

## Package Decisions

| Package candidate | Name status | Intended role | Initial version policy | Module namespace policy | Version ordering |
| --- | --- | --- | --- | --- | --- |
| `agent-workflow-core` | Final package identity for the external candidate. | Generic workflow kernel: specs, replay, codecs, event-log cores, effect plans, permissions, transactions, audit, daemon projections, and reusable failure classification. | Start standalone external packaging at a conservative pre-1.0 version, preferably `0.1.0.0`, unless the release-metadata round records a stricter source-backed reset. Do not inherit stability from the current `moifold-0.1.0.0` package just because the number matches. | Keep exposed modules under `CodexWatcher.Workflow.*`. No source move or module rename is authorized here. | Base package for reusable workflow APIs. Adapter packages must bound against it once standalone descriptors exist. |
| `agent-workflow-codex` | Final package identity for the external candidate. | Codex app-server protocol, typed agent plans and ids, Codex client/protocol/interpreter/transport, and agent observation helpers. | Start standalone external packaging at a conservative pre-1.0 version, preferably `0.1.0.0`, independent of the current top-level `moifold` version and subject to release-metadata confirmation. | Keep `CodexWatcher.AppServerProtocol` and `CodexWatcher.Workflow.Agent*` modules. No compatibility facade migration is authorized here. | Depends on `agent-workflow-core`; version bounds must reflect the core API range it was validated against. |
| `agent-workflow-github` | Final package identity for the external candidate. | Typed GitHub ids, pure remote parsers/classifiers, and pure GitHub/git command specifications. | Start standalone external packaging at a conservative pre-1.0 version, preferably `0.1.0.0`, independent of the current top-level `moifold` version and subject to release-metadata confirmation. | Keep exposed modules under `CodexWatcher.Workflow.GitHub.*`. No source move or module rename is authorized here. | Currently independent of core and Codex. Add bounds only for actual dependencies introduced by later approved descriptor work. |

The three package names should remain the external descriptor names. They are
already present as standalone local package descriptors, match the implemented
ownership split, and are used consistently by the readiness report and API
freeze. Later rounds must not invent alternate names without a new
package-identity review.

## Versioning Policy

The current `moifold` version is evidence for the product package only. The
workflow package candidates now have their own `0.1.0.0` descriptors, but those
local descriptor versions still do not create public compatibility guarantees or
publication approval.

Each workflow package should use independent pre-1.0 semantic versioning:

- Patch releases may fix documentation, metadata, tests, or implementation
  defects without changing the exposed API or documented behavior.
- Minor releases may add modules, exports, constructors, helper functions, or
  behavior that remains compatible with downstream code using the prior public
  surface.
- While the packages remain pre-1.0, breaking changes may still occur in minor
  version increments, but they must be called out in metadata, changelog, and
  release-gate evidence once those artifacts exist.
- A `1.0.0.0` line requires a separate release-gate decision that confirms the
  public API, documentation, compatibility policy, changelog, and validation
  artifacts are ready.

For these packages, a breaking change includes:

- removing or renaming an exposed module;
- removing, renaming, or changing the type of an exported value, type,
  constructor, class method, pattern synonym, or type family;
- changing constructor fields or record labels in a way that breaks
  construction, pattern matching, derived instances, or JSON/protocol helpers
  that the package documents as public;
- weakening documented laws for replay, planning, permission validation,
  transaction ordering, dry-run traversal, or parser/classifier behavior;
- changing rendered command specs, request construction, parser acceptance, or
  failure classification in a way downstream code may reasonably rely on;
- broadening dependencies across the package ownership boundaries without an
  approved layout or metadata round.

Adapter package bounds should be explicit:

- `agent-workflow-codex` should depend on the `agent-workflow-core` version
  range used during validation.
- If a later approved change makes `agent-workflow-github` depend on core, its
  bounds must follow the same rule.
- `moifold` may depend on all three packages as the concrete product, but its
  version policy remains separate from the reusable package versions.

## Ownership Limits

These reusable package version promises do not include moifold product policy
unless a later release-gate contract explicitly says so:

- concrete `WatcherEvent` schemas, event JSON `type` fields, schema migration
  policy, and golden replay fixtures;
- compatibility files such as `issue-state.json`, `daemon-state.json`, PR URL
  files, block state, repair state, and runtime owner files;
- concrete daemon loops, app-server startup policy, runtime ownership,
  filesystem writes, PID files, locks, leases, process execution, healthcheck,
  repair, and operator runbooks;
- role prompts, structured-output schemas, retry escalation, evidence
  requirements, issue/PR lifecycle policy, merge readiness, and publication
  decisions.

Those surfaces remain moifold-owned. They may consume reusable package APIs,
but they are not part of the reusable package compatibility promise.

Package publication remains blocked until a terminal release-gate round
explicitly approves it.

## Module Namespace Policy

The current exposed module namespace stays in force for this contract:

- `agent-workflow-core`: `CodexWatcher.Workflow.*`
- `agent-workflow-codex`: `CodexWatcher.AppServerProtocol` and
  `CodexWatcher.Workflow.Agent*`
- `agent-workflow-github`: `CodexWatcher.Workflow.GitHub.*`

This round authorizes no module renames and no source moves. A future
namespace change, if any, requires a separate migration plan with import
coverage, build evidence, documentation updates, compatibility notes, and
review approval.

The removed compatibility wrappers `CodexWatcher.AppServerClient`,
`CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
`CodexWatcher.Workflow.Permission` are not reusable package namespaces.
Consumers should import the direct owner modules instead. This contract still
does not move moifold lifecycle policy into the reusable packages.

## Compatibility Analysis

The current Cabal shape is:

```text
cabal.project
  .
  agent-workflow-core
  agent-workflow-codex
  agent-workflow-github

moifold
  library depends on agent-workflow-core, agent-workflow-codex, agent-workflow-github
```

That means today there are three standalone local package descriptors, not
internal package components. The package names are source-backed identity
decisions, so downstream documentation, dependency bounds, and package layout
work should not drift from the implemented split.

For current users importing modules through `moifold`, the module names do not
change as a result of this contract. Future standalone packages may let users
depend directly on the reusable packages while keeping the same import
namespaces. Any future import migration from moifold compatibility facades to
adapter modules must be handled by a separate deprecation or migration round.

Later rounds may rely on these assumptions:

- the external package candidates are named `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`;
- initial external versions are independent package versions, expected to be
  conservative pre-1.0 versions;
- `agent-workflow-codex` is versioned against `agent-workflow-core`;
- `agent-workflow-github` remains independent unless a later approved change
  introduces a real dependency;
- exposed module namespaces stay as currently implemented;
- moifold compatibility facades, event schemas, runtime ownership, and
  lifecycle policy remain outside the reusable package compatibility promise;
- no source movement, CI readiness, release note, source distribution, package
  upload, or publication approval is implied by this identity contract.
