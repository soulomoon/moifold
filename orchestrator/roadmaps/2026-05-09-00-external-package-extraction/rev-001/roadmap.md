# External Package Extraction Roadmap

Roadmap id: `2026-05-09-00-external-package-extraction`
Roadmap revision: `rev-001`
Roadmap style: `strategy-backlog`

## Goal

Turn the internally stabilized `agent-workflow-core`,
`agent-workflow-codex`, and `agent-workflow-github` sublibraries into
release-ready external package candidates while preserving moifold behavior,
compatibility files, event schemas, and lifecycle ownership.

## Alignment Summary

- Thesis: external package extraction should be a release-gated engineering
  path, not a direct upload. Package identity, layout, CI, public docs,
  consumer validation, and release approval must be explicit and reviewable.
- Success criteria: the repo can build, test, document, sdist/check, and consume
  the three workflow packages as package candidates; reviewers can see the
  package metadata, module ownership, compatibility policy, and release gate;
  moifold remains a concrete consumer of the framework packages.
- Non-goals: no incidental package upload, no migration of moifold issue/PR
  lifecycle policy, no event schema or golden fixture changes, no broad
  compatibility-facade removal, no prompt/schema/runtime/healthcheck/repair
  migration, and no speculative API redesign detached from source evidence.
- Chosen strategy: release-gated three-package extraction. Stabilize package
  identity and metadata first, then physical/package layout, CI and tarball
  validation, public docs and examples, and finally consumer validation plus an
  explicit release decision.
- Deferred alternatives: core-only publication is deferred because adapter
  versioning would follow immediately; physical split without release policy is
  deferred because it would leave external users without compatibility and
  versioning commitments.
- Shared invariants: repo-wide compatibility and ownership promises live in
  `orchestrator/project-contract.md`.

## Outcome Boundaries

- In scope: package names and release metadata, Cabal/package descriptors,
  local multi-package layout, CI/build matrix, `cabal check` and source
  distribution validation, Haddock/public docs, example packages or examples,
  moifold consumer validation, compatibility/deprecation policy, and explicit
  release-gate artifacts.
- Out of scope: package upload without an approved release gate, moving
  moifold workflow policy into reusable packages, changing event JSON schemas
  or golden logs, deleting compatibility facades without proven deprecation
  coverage, replacing current workflow semantics, or treating healthcheck,
  repair, daemon ownership, process execution, or filesystem writes as
  framework-package responsibilities.

## Global Sequencing Rules

- Make package identity and release policy explicit before moving files or
  publishing metadata.
- Preserve the current module namespaces and ownership split unless a round
  proves a source-backed reason to change them.
- Keep moifold as the consumer of `agent-workflow-*`, never as a dependency of
  those packages.
- Run package validation on real package artifacts before any release decision.
- Keep package publication behind a final explicit release gate. A runtime round
  may prepare a candidate but must not upload it unless its selected direction
  and review explicitly authorize that action.
- Any compatibility-facade removal requires a separate deprecation/removal
  proof. Preferred-import guidance is not removal.

## Parallel Lanes

- Default lane: serial, because package layout, dependency ownership, and
  consumer wiring overlap.
- Potential lane `docs-release`: public docs, examples, and changelog polish
  may run after package identity is stable and before final release gate.
- Potential lane `ci-validation`: CI matrix and package tarball validation may
  run beside docs-only polish once package descriptors are stable.

## Milestones

### 1. [complete] Define Package Identity And Release Contract

Milestone id: `milestone-001-package-identity-release-contract`
Depends on: none
Intent: Convert the internal readiness report into a concrete external package
contract with names, versions, metadata, changelog policy, release gates, and
compatibility/deprecation posture.
Completion signal: package names, versioning policy, license/source metadata,
maintainer/repository metadata, changelog/release-note policy, and explicit
upload authorization rules are recorded and reviewable.
Parallel lane: default serial
Coordination notes: this must precede physical package movement so later rounds
do not infer release policy from layout.
Progress: round 036 completed the package names and versioning contract in
`56b5a02`, recording final external candidate names for
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`,
pre-1.0 versioning policy, module namespace policy, semantic-versioning
expectations, compatibility analysis for the current internal sublibraries, and
release-gate limits. Round 037 completed the release metadata policy in
`bad28e9`, recording package metadata requirements, package-specific wording
constraints, changelog and release-note gates, metadata truth rules, and
descriptor-time checks without changing descriptors, source layout, artifacts,
upload state, or publication approval. Round 038 completed the compatibility
and deprecation policy in `2574fa3`, recording preferred-import guidance,
compatibility facade status, deprecation-readiness gates, removal gates, and
release-note constraints without changing wrappers, compatibility files, event
schemas, package descriptors, source layout, generated artifacts, upload state,
or publication approval. Milestone 001 is complete because directions 001, 002,
and 003 now satisfy the package identity, metadata, changelog/release-note,
compatibility/deprecation, and explicit upload authorization completion signal.

Candidate directions:

- Direction id: `direction-001-package-names-and-versioning`
  Status: complete via round 036, merged as `56b5a02`.
  Summary: choose final package names, initial versions, module namespace
  policy, and semantic-versioning expectations for the three packages.
  Why it matters now: package descriptors and docs need stable identity before
  release artifacts are generated.
  Preconditions: completed package extraction readiness report.
  Parallel hints: serial with other release-contract work.
  Boundary notes: do not rename modules or packages in code unless this
  direction explicitly includes the corresponding tested migration.
  Extraction notes: include a compatibility analysis for current module names
  and package names.

- Direction id: `direction-002-release-metadata-policy`
  Status: complete via round 037, merged as `bad28e9`.
  Summary: define license, maintainer, category, synopsis, description,
  source-repository, changelog, and release-note requirements.
  Why it matters now: `cabal check`, Hackage readiness, and public docs depend
  on complete metadata.
  Preconditions: package names are stable or explicitly recorded as provisional.
  Parallel hints: may run beside docs-only policy work after package names are
  fixed.
  Boundary notes: no upload or public release.
  Extraction notes: produce reviewable metadata requirements before editing
  package descriptors.

- Direction id: `direction-003-compatibility-and-deprecation-policy`
  Status: complete via round 038, merged as `2574fa3`.
  Summary: define preferred imports, compatibility facade status, deprecation
  readiness, and removal gates for moifold wrappers.
  Why it matters now: external packages need compatibility promises before
  downstream users rely on them.
  Preconditions: package ownership report is current.
  Parallel hints: can run with docs-release work if it remains artifact-only.
  Boundary notes: do not remove wrappers or compatibility files in this
  direction.
  Extraction notes: map `CodexWatcher.AppServerClient` and other wrappers to
  preferred package imports and future removal evidence.

### 2. [complete] Build Standalone Package Layout

Milestone id: `milestone-002-standalone-package-layout`
Depends on: `milestone-001-package-identity-release-contract`
Intent: Move from internal Cabal sublibraries to standalone package candidates
or an equivalent local multi-package layout without changing behavior.
Completion signal: the three workflow packages have package descriptors or
equivalent standalone build surfaces; moifold consumes them locally; package
boundary assertions and current behavior still pass.
Parallel lane: default serial
Coordination notes: keep changes vertical and package-owned. Core should move
before adapters when dependency order matters.
Progress: round 039 completed the core package layout in `68f2195`, adding the
standalone `agent-workflow-core` package descriptor, local project wiring, and
boundary assertions while preserving the existing core source layout. Round 040
completed the Codex package layout in `8f81c1e`, adding the standalone
`agent-workflow-codex` descriptor, local project wiring, and boundary
assertions while preserving the existing Codex source layout and internal
sublibrary for current moifold consumers. Round 041 completed the GitHub
package layout in `f8061c2`, adding the standalone `agent-workflow-github`
descriptor, local project wiring, and boundary assertions while preserving the
existing GitHub source layout and internal sublibrary for current moifold
consumers. Round 042 completed moifold local consumer wiring in `14f84a4`,
switching moifold and `watcher-core-test` to consume the local standalone
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates with approved bounds, removing the internal
`moifold:agent-workflow-*` sublibrary wiring, and preserving compatibility
facades and behavior validation. Milestone 002 is complete because directions
004, 005, 006, and 007 now satisfy the standalone package descriptors,
equivalent build surfaces, local moifold consumption, package-boundary
assertions, and current-behavior checks required by the completion signal.

Candidate directions:

- Direction id: `direction-004-core-package-layout`
  Status: complete via round 039, merged as `68f2195`.
  Summary: create or validate the standalone `agent-workflow-core` package
  descriptor and source layout.
  Why it matters now: Codex adapter and moifold consumer wiring depend on the
  core package boundary.
  Preconditions: package identity and metadata policy are approved.
  Parallel hints: serial before adapter descriptors if files or Cabal project
  wiring overlap.
  Boundary notes: core must remain free of Aeson, Codex, GitHub, moifold
  lifecycle, filesystem, runtime, and concrete event ownership.
  Extraction notes: run package-specific build/check commands and update
  boundary tests if the layout changes.

- Direction id: `direction-005-codex-package-layout`
  Status: complete via round 040, merged as `8f81c1e`.
  Summary: create or validate the standalone `agent-workflow-codex` package
  descriptor and source layout.
  Why it matters now: Codex transport and protocol ownership must be real
  package metadata, not only an internal sublibrary claim.
  Preconditions: core package layout is buildable or explicitly stubbed as a
  local dependency.
  Parallel hints: may run beside GitHub layout only if package descriptors and
  source trees are disjoint.
  Boundary notes: no moifold issue/PR lifecycle imports, prompt policy, or
  compatibility-file ownership.
  Extraction notes: verify app-server protocol/client/interpreter/transport
  modules build outside the main moifold library.

- Direction id: `direction-006-github-package-layout`
  Status: complete via round 041, merged as `f8061c2`.
  Summary: create or validate the standalone `agent-workflow-github` package
  descriptor and source layout.
  Why it matters now: GitHub adapter parsing and pure command specs should be
  independently buildable before release validation.
  Preconditions: package identity and metadata policy are approved.
  Parallel hints: may run beside Codex layout only with disjoint ownership.
  Boundary notes: keep command execution, healthcheck, PR/issue lifecycle, and
  merge/review publication policy in moifold.
  Extraction notes: verify pure parser/rendering dependencies and boundary
  scans after descriptor changes.

- Direction id: `direction-007-moifold-local-consumer-wiring`
  Status: complete via round 042, merged as `14f84a4`.
  Summary: wire moifold to consume the local package candidates and preserve
  existing compatibility facades.
  Why it matters now: external extraction is only useful if the product can
  consume the packages without behavioral drift.
  Preconditions: package descriptors are locally buildable.
  Parallel hints: serial after package layout changes.
  Boundary notes: do not remove compatibility modules unless a separate
  deprecation/removal direction authorizes it.
  Extraction notes: prove `cabal build all` and `watcher-core-test` still cover
  moifold behavior.

### 3. [pending] Establish Release Validation And CI Matrix

Milestone id: `milestone-003-release-validation-ci`
Depends on: `milestone-002-standalone-package-layout`
Intent: Make package validation repeatable through source distributions,
package checks, docs builds, and CI coverage.
Completion signal: reviewers can run or inspect package-level `cabal check`,
source distribution, build/test, Haddock, and CI matrix evidence for each
package candidate.
Parallel lane: `ci-validation`
Coordination notes: validation can be split by package only after descriptors
are stable and planner assigns disjoint ownership.

Candidate directions:

- Direction id: `direction-008-package-check-and-sdist`
  Summary: add repeatable `cabal check` and source distribution validation for
  the three packages.
  Why it matters now: package candidates need real package artifacts before
  release decisions.
  Preconditions: standalone descriptors or equivalent package surfaces exist.
  Parallel hints: package-specific workers are possible if descriptors are
  disjoint.
  Boundary notes: do not upload generated artifacts.
  Extraction notes: record exact commands and artifact paths in reviewable docs
  or scripts.

- Direction id: `direction-009-ci-build-matrix`
  Summary: add or adapt CI to build, test, check, and package the workflow
  packages across the supported compiler matrix.
  Why it matters now: external users need confidence that package candidates
  are not only locally buildable.
  Preconditions: local package validation is stable enough to automate.
  Parallel hints: can run beside docs-release work after package commands are
  known.
  Boundary notes: avoid broad unrelated CI churn.
  Extraction notes: keep existing moifold validation in CI while adding package
  candidate gates.

- Direction id: `direction-010-boundary-test-refresh-for-package-layout`
  Summary: update recursive boundary and Cabal/package assertions to reflect
  the external-package layout.
  Why it matters now: existing internal sublibrary tests must keep protecting
  package ownership after the layout changes.
  Preconditions: package layout is chosen.
  Parallel hints: serial with package descriptor changes if assertions read the
  same files.
  Boundary notes: do not weaken ownership scans to make package movement pass.
  Extraction notes: prefer recursive source-tree checks over hand-listed files.

### 4. [pending] Publish Public Docs And Examples

Milestone id: `milestone-004-public-docs-examples`
Depends on: `milestone-002-standalone-package-layout`
Intent: Turn internal framework docs into public package-facing documentation
and examples without implying moifold lifecycle policy is part of the
framework.
Completion signal: package READMEs, Haddock-facing module docs, examples or
example workflows, changelog/release notes, and public non-goals are
reviewable and aligned with implemented APIs.
Parallel lane: `docs-release`
Coordination notes: docs may run beside CI validation once package identity and
layout are stable.

Candidate directions:

- Direction id: `direction-011-package-readmes-and-haddock`
  Summary: create package-facing READMEs and Haddock/module documentation for
  the public API surfaces.
  Why it matters now: external package candidates need docs that explain what
  is stable and what remains moifold-owned.
  Preconditions: package names and exposed modules are stable.
  Parallel hints: can run beside CI if docs do not alter descriptors.
  Boundary notes: avoid marketing copy and avoid promising package publication
  before the release gate.
  Extraction notes: link back to the implemented API freeze and package
  readiness report where useful.

- Direction id: `direction-012-examples-and-consumer-guides`
  Summary: add small package examples or consumer guides that demonstrate core,
  Codex, and GitHub package usage without moifold lifecycle dependencies.
  Why it matters now: examples prove the extracted packages are understandable
  outside the product code.
  Preconditions: package layout and public imports are stable.
  Parallel hints: can run beside documentation polish if examples do not alter
  package descriptors.
  Boundary notes: do not introduce a generic prompt runner or YAML workflow
  engine.
  Extraction notes: prefer a minimal buildable example over broad tutorial
  prose when feasible.

- Direction id: `direction-013-changelog-and-release-notes`
  Summary: prepare changelog entries and release notes for the package
  candidates.
  Why it matters now: release gates need human-readable change scope and
  compatibility notes.
  Preconditions: package metadata policy is approved.
  Parallel hints: can run with docs-release once package names and versions are
  stable.
  Boundary notes: no release announcement or package upload.
  Extraction notes: distinguish internal extraction history from public API
  promises.

### 5. [pending] Validate Consumer And Release Gate

Milestone id: `milestone-005-consumer-release-gate`
Depends on: `milestone-003-release-validation-ci`,
`milestone-004-public-docs-examples`
Intent: Prove moifold consumes the external-package candidates correctly and
make the publish/no-publish decision explicit.
Completion signal: moifold consumer validation passes against the package
candidates; compatibility/deprecation policy is recorded; release artifacts are
reviewed; the final roadmap update records either an approved publication plan
or a deliberate hold with blockers.
Parallel lane: default serial
Coordination notes: keep this final and serial. Publication, if any, requires a
selected release-gate direction and explicit review approval.

Candidate directions:

- Direction id: `direction-014-moifold-consumer-validation`
  Summary: prove moifold builds and tests while consuming the external-package
  candidates through the intended local/package mechanism.
  Why it matters now: the product must remain the behavioral oracle while the
  packages become external candidates.
  Preconditions: package descriptors, validation, and docs are ready enough for
  consumer testing.
  Parallel hints: serial with final release-gate work.
  Boundary notes: preserve event schemas, golden logs, compatibility files,
  runtime ownership, healthcheck, repair, and prompt policy.
  Extraction notes: include focused evidence for compatibility facades and
  current CLI/watcher workflows.

- Direction id: `direction-015-release-candidate-bundle`
  Summary: assemble a release-candidate evidence bundle: package artifacts,
  checks, docs, changelog, CI status, compatibility/deprecation notes, and
  remaining blockers.
  Why it matters now: publication should follow reviewed evidence, not
  optimism.
  Preconditions: package validation and consumer validation pass.
  Parallel hints: serial finalization work.
  Boundary notes: no upload unless paired with explicit release approval.
  Extraction notes: make the go/no-go decision reviewable by package.

- Direction id: `direction-016-explicit-publication-gate`
  Summary: record the final publish/hold decision and, only if explicitly
  approved, perform the release action specified by the reviewed plan.
  Why it matters now: this family exists to proceed toward real external
  extraction, but publication must remain deliberate and reversible in process
  even when artifacts are ready.
  Preconditions: release-candidate bundle is reviewed and no release blockers
  remain, or blockers are accepted as hold reasons.
  Parallel hints: serial terminal direction.
  Boundary notes: package upload is externally visible and must not happen as
  incidental cleanup.
  Extraction notes: if publication is not approved, record the blockers and
  leave the packages in candidate state.
