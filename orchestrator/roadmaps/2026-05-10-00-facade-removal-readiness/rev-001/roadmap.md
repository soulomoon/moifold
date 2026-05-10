# Facade Removal Readiness Roadmap

Roadmap id: `2026-05-10-00-facade-removal-readiness`
Roadmap revision: `rev-001`
Roadmap style: `strategy-backlog`

## Goal

Turn the held compatibility-facade cleanup into a fresh, evidence-backed
selected workstream that can migrate, deprecate, remove, or deliberately keep
exact import facades without contradicting the prior terminal hold.

## Alignment Summary

- Thesis: cleanup should focus on import-facade removal readiness, not a broad
  runtime compatibility-file campaign. The prior compatibility-surface family
  ended with no removals, so this roadmap must rebuild the removal case per
  exact facade.
- Outcome: each selected facade has current import evidence, replacement-path
  evidence, behavior and package-boundary validation, and an explicit
  reviewer-approved decision: keep, defer, deprecate, or remove.
- Success criteria: no facade is deprecated or removed until the exact surface
  has current import scans, build/test evidence, focused behavior evidence,
  documentation/Cabal exposure evidence when relevant, and reviewer approval.
- Non-goals: no runtime compatibility-file deletion, no event JSON `type`
  migration, no repair or healthcheck behavior change, no package upload, no
  public release approval, and no claim that the prior terminal hold approved
  removal.
- Chosen strategy: staged evidence first, then internal import migration, then
  public/API decision, then exact approved removal or an explicit terminal
  hold.
- Deferred alternatives: a direct deletion round is rejected because the prior
  family recorded no lawful removal; a broad runtime compatibility cleanup is
  deferred because this family is scoped to import facades.

## Outcome Boundaries

In scope:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`
- Cabal exposure, Haddock/import guidance, and tests directly needed to support
  a keep/defer/deprecate/remove decision for those facades.

Out of scope:

- `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution`, unless a
  later reviewed roadmap update proves a specific replacement for their
  moifold-owned bridge roles.
- Runtime compatibility files such as `issue-state.json`, `daemon-state.json`,
  `planning-state.json`, `block-state.json`, `repair-state.json`,
  `runtime-owner.json`, and live snapshots.
- Release, publication, source-distribution, or package-upload decisions.

## Global Sequencing Rules

- Start with source-backed scans and policy refresh before changing imports.
- Migrate internal imports only where replacement modules are behaviorally
  equivalent and the replacement improves package-boundary clarity.
- Do not add deprecation pragmas, remove exposed modules, or edit Cabal exposure
  until the exact surface has reviewer approval.
- Preserve `orchestrator/project-contract.md` invariants for event schemas,
  golden fixtures, dry-run rendering, compatibility files, and package
  ownership.
- Treat local absence of a consumer as incomplete evidence unless the round
  records the inventory scope and reviewer accepts it.

## Parallel Lanes

The control plane remains serial by default with `max_parallel_rounds: 1`.
After milestone 001, the guider may propose lane-bound parallelism only if
facade ownership is disjoint and the active state is updated explicitly. Until
then, extract one round at a time.

## Milestones

### 1. [complete] Current Facade Evidence Refresh

Milestone id: `milestone-001-current-facade-evidence`
Depends on: none
Intent: Refresh the selected-facade inventory at the current branch tip and
separate exact removal candidates from facades that still own concrete moifold
behavior.
Completion signal: a reviewed evidence artifact names every selected facade,
current internal imports, preferred replacements, Cabal exposure, protecting
tests, downstream/operator inventory scope, and remaining blocker class.
Progress: round 075 completed the current import scan refresh in `066952b`;
round 076 completed behavior-owner classification in `606ad40`. Together these
rounds recorded local import counts, Cabal exposure, documentation references,
replacement mappings, protecting checks, downstream/operator inventory limits,
blocker classes, and behavior-owner classifications for the four selected
facades without changing production code, package descriptors, docs, runtime
compatibility files, imports, deprecation pragmas, Cabal exposure, or removals.
The milestone evidence classifies `CodexWatcher.AppServerClient` and
`CodexWatcher.Core.Ids` as pure reexport convenience facades, and
`CodexWatcher.Workflow.EventLog` and `CodexWatcher.Workflow.Permission` as mixed
surfaces with concrete moifold behavior bridges.
Parallel lane: serial
Coordination notes: this milestone is evidence-only. It must not migrate imports,
add warnings, edit Cabal exposure, or remove modules.

Candidate directions:

- Direction id: `direction-001-import-scan-refresh`
  Status: complete via round 075, merged as `066952b`.
  Summary: Refresh import scans and replacement mapping for the four selected
  facades.
  Why it matters now: the previous counts are historical and cannot justify a
  new removal decision by themselves.
  Preconditions: active roadmap bundle and prior compatibility policy re-read.
  Parallel hints: serial; this direction defines the shared evidence base.
  Boundary notes: no production source changes except evidence artifacts.
  Extraction notes: include source, app, test, Cabal, docs, and README import
  references in the scan scope.

- Direction id: `direction-002-behavior-owner-classification`
  Status: complete via round 076, merged as `606ad40`.
  Summary: Classify each facade as pure reexport, moifold behavior bridge, or
  mixed surface.
  Why it matters now: replacement imports are safe only when behavior ownership
  is explicit.
  Preconditions: direction 001 evidence is available or extracted in the same
  round.
  Parallel hints: serial with direction 001 unless the guider records a safe
  split.
  Boundary notes: do not reclassify `Workflow.Types` or `Workflow.Execution`
  into this family without a roadmap update.
  Extraction notes: distinguish adapter-id convenience from concrete event-log,
  replay, permission, and phase-validation behavior.

### 2. [in-progress] Internal Import Migration Readiness

Milestone id: `milestone-002-internal-import-migration`
Depends on: `milestone-001-current-facade-evidence`
Intent: Move internal moifold imports toward preferred modules where the
replacement is known and behavior-neutral, while keeping compatibility modules
available.
Completion signal: selected internal imports are migrated or explicitly held
with reasons, and tests show no behavior, package-boundary, or command-rendering
drift.
Progress: round 077 completed the selected `CodexWatcher.AppServerClient`
explicit-import migration slice in `a37f71a`. The round replaced endpoint-only
imports with `CodexWatcher.Workflow.Agent.Codex.Transport`, client-value imports
with `CodexWatcher.Workflow.Agent.Codex.Client`, and split `test/AppServerSpec.hs`
onto direct owner imports while keeping `src/CodexWatcher/AppServerClient.hs`
live and unchanged. Review evidence records the starting inventory at 28 facade
imports and the final inventory at 13 remaining broad/deferred facade imports,
with `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
`git diff --cached --check` passing. Milestone 002 remains in progress because
`direction-004-core-ids-split-import-migration` and
`direction-005-eventlog-permission-readiness` are still pending.
Parallel lane: serial by default; possible facade-specific lanes after approval
Coordination notes: import migration is not deprecation. Facade modules must
remain exposed unless a later milestone approves exact removal.

Candidate directions:

- Direction id: `direction-003-appserverclient-import-migration`
  Status: complete via round 077, merged as `a37f71a`.
  Summary: Replace internal `CodexWatcher.AppServerClient` imports where direct
  Codex client or transport imports are equivalent.
  Why it matters now: this is the smallest likely pure reexport cleanup path.
  Preconditions: milestone 001 confirms current users and replacement imports.
  Parallel hints: may be independent of `Core.Ids` if the guider proves file
  ownership is disjoint.
  Boundary notes: preserve app-server failure formatting, endpoint parsing, and
  turn protocol behavior.
  Extraction notes: keep the facade module available after any internal import
  migration.

- Direction id: `direction-004-core-ids-split-import-migration`
  Summary: Split internal `CodexWatcher.Core.Ids` imports into agent ids and
  GitHub ids where the caller only needs one side.
  Why it matters now: `Core.Ids` is a convenience facade over two package
  ownership areas, so split imports can make future package boundaries clearer.
  Preconditions: milestone 001 scan and behavior-owner classification.
  Parallel hints: serial unless a narrow file set can be isolated.
  Boundary notes: do not change newtype constructors, parsers, renderers, or
  command output.
  Extraction notes: record any callers that still legitimately need the combined
  facade.

- Direction id: `direction-005-eventlog-permission-readiness`
  Summary: Decide whether `Workflow.EventLog` and `Workflow.Permission` are
  migration candidates or concrete moifold bridge surfaces for now.
  Why it matters now: these facades expose concrete event-log, replay, and
  phase-permission behavior, so direct removal is higher risk than pure import
  cleanup.
  Preconditions: milestone 001 behavior-owner classification.
  Parallel hints: serial; both surfaces affect workflow correctness evidence.
  Boundary notes: preserve golden replay behavior, permission soundness, and
  `MoifoldSpec` concrete bridge semantics.
  Extraction notes: a valid result may be a reviewed hold instead of migration.

### 3. [pending] Public Facade Decision Gates

Milestone id: `milestone-003-public-facade-decision-gates`
Depends on: `milestone-002-internal-import-migration`
Intent: Decide whether each selected facade is ready for keep, defer,
deprecation, or exact removal, including exposed-module and documentation
consequences.
Completion signal: every selected facade has a reviewed decision record with
gate evidence, required docs/Cabal changes, and explicit reviewer approval or
blockers.
Parallel lane: serial
Coordination notes: deprecation and removal are separate decisions. A facade may
be documented as compatibility-only without receiving removal approval.

Candidate directions:

- Direction id: `direction-006-deprecation-readiness`
  Summary: Evaluate whether any facade should receive a deprecation pragma or
  public deprecation wording.
  Why it matters now: warnings are externally visible API signals and need a
  higher evidence bar than internal import cleanup.
  Preconditions: milestone 002 migration or hold evidence.
  Parallel hints: serial.
  Boundary notes: no deprecation warning unless the exact surface and migration
  path are approved.
  Extraction notes: include docs, Haddock, changelog/release-note constraints,
  and downstream inventory scope.

- Direction id: `direction-007-cabal-exposure-decision`
  Summary: Decide whether any exposed module can be removed from `moifold.cabal`
  or must remain exposed.
  Why it matters now: Cabal exposure is the public compatibility boundary for
  downstream imports.
  Preconditions: milestone 002 evidence and deprecation-readiness outcome.
  Parallel hints: serial.
  Boundary notes: no exposed-module deletion from local absence alone.
  Extraction notes: reviewer approval must name the exact exposed module.

### 4. [pending] Exact Removal Or Terminal Hold

Milestone id: `milestone-004-exact-removal-or-hold`
Depends on: `milestone-003-public-facade-decision-gates`
Intent: Land only exact approved removals, or close the family with a reviewed
hold that preserves every blocker and decision.
Completion signal: either approved removal rounds have landed with all gates
satisfied, or a final reviewed report records kept, deferred, deprecated, and
removed surfaces with the removed-surface set explicitly stated.
Parallel lane: serial
Coordination notes: terminal completion must distinguish removal completion from
a hold. Do not imply package release, upload, or broad compatibility-file
cleanup.

Candidate directions:

- Direction id: `direction-008-exact-approved-removal`
  Summary: Remove only surfaces whose gates passed and whose approval names the
  exact module or exposure entry.
  Why it matters now: this is the only lawful path from readiness evidence to
  actual deletion.
  Preconditions: milestone 003 approval for the exact surface.
  Parallel hints: serial.
  Boundary notes: update imports, Cabal exposure, docs, and tests in the same
  reviewed slice when public surface changes.
  Extraction notes: record removed-surface set, build/test evidence, and focused
  behavior evidence.

- Direction id: `direction-009-terminal-decision-report`
  Summary: Close the family with an explicit final decision report.
  Why it matters now: the family must not silently finish by exhausting tasks if
  no surface is lawful to remove.
  Preconditions: milestone 003 decisions complete, or removal rounds complete.
  Parallel hints: serial.
  Boundary notes: a hold is valid only if it preserves exact blockers and does
  not imply removal approval.
  Extraction notes: include kept, deferred, deprecated, removed, and blocked
  surfaces plus validation commands.
