# Highest-Value Cleanup Roadmap

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-001`
Roadmap style: `strategy-backlog`

## Goal

Make the repository easier to evolve by landing the highest-value cleanup in a
sequenced way: split oversized tests first, add missing compatibility evidence,
clarify runtime-state contracts, converge internal imports toward direct
package owners, decompose large behavior modules behind tests, and only then
continue through gated deprecation and removal until compatibility surfaces are
removed cleanly.

## Alignment Summary

- Thesis: cleanup should reduce future risk before it removes compatibility.
  The previous facade-removal family ended in a terminal hold, so this roadmap
  must keep pushing toward clean compatibility removal while collecting the
  gates that make that removal safe. Risky behavior must be visible before any
  public compatibility facade, compatibility file, or exposed module is
  deleted.
- Outcome: the repo has smaller test and runtime modules, reusable
  package-boundary checks outside the 17k-line `test/Main.hs`, fixture-backed
  compatibility-state contracts, clearer `planner-state.json` versus
  `planning-state.json` semantics, reduced internal facade imports, and exact
  deprecation/removal decisions backed by reviewer-approved evidence.
- Success criteria: all compatibility surfaces covered by this family are
  removed cleanly or migrated away from supported compatibility paths, with no
  remaining kept, deferred, or blocked compatibility set. Every cleanup slice
  must preserve behavior until its removal gate is approved, keep public
  compatibility surfaces exposed until gates are met, add focused evidence for
  touched runtime contracts, and leave `cabal build all` plus
  `cabal test watcher-core-test` green for behavior-affecting changes.
- Non-goals: no casual removal of `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or
  `CodexWatcher.Workflow.Permission`; no compatibility-file rename or deletion
  before fixture and healthcheck evidence; no event JSON `type` migration; no
  release or publication approval; no broad API churn in reusable packages.
- Chosen strategy: evidence-first cleanup. Start with test topology and
  scanners, then fixture and runtime-state contracts, then import convergence,
  then large-module splits, then compatibility cleanup, and finally exact
  deprecation/removal rounds.
- Expansion rule: completing the current milestone list is not, by itself,
  proof that the family is finished. When late evidence reveals more
  compatibility-removal work, the guider must author a reviewed roadmap update
  or new revision that adds milestones before terminal closeout. If any
  compatibility surface remains kept, deferred, blocked, or only held, the
  roadmap must keep expanding milestones toward clean removal instead of
  marking `done`.
- Deferred alternatives: direct facade deletion, direct runtime compatibility
  file deletion, and broad module rewrites without focused tests are rejected
  until the roadmap records the required gates.

## Outcome Boundaries

In scope:

- `test/Main.hs`, especially facade extraction tests, package-boundary
  scanners, import-policy checks, workflow behavior tests, and helper code
  around the current boundary-policy tests.
- Compatibility fixtures and contracts for `planner-state.json`,
  `planning-state.json`, `daemon-state.json`, `block-state.json`,
  `repair-state.json`, `runtime-owner.json`, checked-in compatibility
  snapshots, and live `issue-snapshot.json`.
- Internal import convergence away from compatibility facades in new or
  reusable-package-oriented code, while public facades remain available.
- Large-module decomposition targets:
  `src/CodexWatcher/Daemon.hs`,
  `src/CodexWatcher/Workflow/DocsMigration.hs`,
  `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`,
  `src/CodexWatcher/EventLog/Types.hs`, and
  `src/CodexWatcher/TurnOutput.hs`.
- Exact deprecation and removal gates for surfaces that have completed current
  import, fixture, behavior, documentation, Cabal, and downstream evidence.

Out of scope:

- Package upload, public release, or external publication decisions.
- Removing compatibility facades solely because direct imports exist.
- Removing or renaming compatibility state files solely because production code
  has few local readers.
- Moving concrete moifold lifecycle policy into reusable packages.
- Reopening old roadmap families or editing prior used roadmap revisions.

## Global Sequencing Rules

- Split and preserve tests before relying on the suite for later risky cleanup.
- Add compatibility fixtures before deleting, renaming, or changing runtime
  compatibility-state files.
- Clarify `planner-state.json` versus `planning-state.json` as a compatibility
  contract before any rename, deletion, or healthcheck behavior change.
- Migrate internal imports only when replacement modules are behaviorally
  equivalent and package ownership becomes clearer.
- Split large runtime modules only behind existing or newly extracted focused
  tests, and avoid behavior change in pure extraction rounds.
- Treat deprecation and removal as final gates, not cleanup shortcuts.
- Before terminal closeout, inspect merged evidence for newly discovered
  cleanup fronts. If more cleanup is justified, refine the roadmap through a
  reviewed update or new revision instead of marking the family done.
- Terminal closeout is valid only when compatibility removal is complete: no
  roadmap-covered compatibility facade, compatibility file, public
  compatibility module, or exposed-module compatibility entry remains in a
  kept, deferred, blocked, or hold-only state.
- Preserve `orchestrator/project-contract.md` invariants for event schemas,
  golden fixtures, compatibility files, dry-run rendering, package ownership,
  runtime ownership, healthcheck, repair, and public facade availability.

## Parallel Lanes

Default execution remains serial with `max_parallel_rounds: 1`. The guider may
later propose lane-bound parallelism only after the first inventory round
records disjoint ownership.

Candidate lanes after inventory:

- Test topology lane: focused test-module extraction and harness wiring.
- Compatibility fixture lane: fixture additions and runtime-state contract
  tests.
- Import convergence lane: direct-owner import migrations that do not touch the
  same files as fixture or module-split work.
- Large-module split lane: one module-family split at a time, unless planner
  evidence proves non-overlapping ownership and verification.

Deprecation/removal remains serial because public API, Cabal exposure, docs,
and downstream evidence must be reviewed per exact surface.

## Milestones

### 1. [completed] Test Topology And Cleanup Inventory

Milestone id: `milestone-001-test-topology-inventory`
Depends on: none
Intent: Make the cleanup evidence base navigable by inventorying current
facade, fixture, package-boundary, and large-module risks, then extracting the
highest-value reusable test helpers out of `test/Main.hs`.
Completion signal: focused test modules own reusable package-boundary scanners
and facade/import-policy checks; `test/Main.hs` is measurably smaller; the
test-suite wiring still runs the same behavior coverage; and the cleanup
inventory names remaining facade, fixture, and large-module follow-up gates.
Parallel lane: serial until inventory proves disjoint file ownership
Coordination notes: do not weaken tests to make extraction easier. Test helper
extraction should preserve assertions and failure messages unless a reviewer
approves a clearer equivalent.
Current status: `round-083-cleanup-inventory-refresh` completed
`direction-001-cleanup-inventory-refresh` as artifact-only evidence in
`orchestrator/rounds/round-083/cleanup-inventory.md` at merged commit
`0aed2e4`, and `round-084-boundary-policy-test-module-split` completed
`direction-002-boundary-policy-test-module-split` by extracting reusable
package-boundary scanner helpers and boundary-policy assertions into focused
watcher-core test modules at merged commit `83cac48`, and
`round-085-facade-import-policy-test-split` completed
`direction-003-facade-import-policy-test-split` by extracting facade
extraction, import-policy, and compatibility policy checks into a focused
watcher-core test module at merged commit `fec075a`, and
`round-086-workflow-behavior-test-split` completed
`direction-004-workflow-behavior-test-split` by extracting focused workflow
behavior tests into watcher-core modules at merged commit `0dc85da`.
Milestone 001 is complete: the cleanup inventory exists, focused test modules
own reusable boundary scanners, facade/import-policy checks, and workflow
behavior coverage, `test/Main.hs` is measurably smaller, and reviewer evidence
confirmed the watcher-core aggregation still reaches the moved behavior tests.

Candidate directions:

- Direction id: `direction-001-cleanup-inventory-refresh`
  Summary: Refresh the current cleanup inventory across compatibility facades,
  runtime compatibility files, oversized test/helper clusters, and large
  behavior modules.
  Why it matters now: the roadmap is broad, and later rounds need a current
  evidence map before changing tests or production boundaries.
  Preconditions: active roadmap bundle and prior terminal hold re-read.
  Parallel hints: serial; this creates the shared evidence base.
  Boundary notes: no production, test, Cabal, docs, or compatibility behavior
  changes except inventory artifacts.
  Extraction notes: include import scans, module line counts, fixture coverage,
  policy references, and downstream/operator inventory scope.
  Status: completed by `round-083` at `0aed2e4`; use
  `orchestrator/rounds/round-083/cleanup-inventory.md` as the current cleanup
  evidence map for later test-topology, fixture, import-convergence,
  large-module, and compatibility-removal gate planning. This status does not
  approve deprecation, migration, Cabal exposure changes, facade removal, or
  runtime compatibility-file removal.

- Direction id: `direction-002-boundary-policy-test-module-split`
  Summary: Extract reusable package-boundary scanners and policy helpers from
  `test/Main.hs` into focused test support or test modules.
  Why it matters now: these scanners guard future package and facade cleanup,
  but their current location makes future work harder to review.
  Preconditions: round-083 cleanup inventory evidence is available.
  Parallel hints: serial unless the planner proves disjoint edits from other
  test-split work.
  Boundary notes: preserve current package-boundary assertions and selected
  facade checks.
  Extraction notes: start around the existing boundary-policy helper cluster
  and keep `watcher-core-test` as the validation gate.
  Status: completed by `round-084` at `83cac48`; the reviewed split added
  `test/BoundaryPolicySpec.hs` and `test/TestSupport/SourceScan.hs`, kept the
  existing `test/Main.hs` aggregation reaching `workflowBoundaryPolicyTests`,
  and added only the required `watcher-core-test` `other-modules` metadata for
  those extracted modules. This status does not approve production import
  convergence, public deprecation, facade removal, Cabal exposure removal, or
  runtime compatibility-file removal.

- Direction id: `direction-003-facade-import-policy-test-split`
  Summary: Move facade extraction, import-policy, and compatibility policy
  checks into focused modules.
  Why it matters now: future deprecation/removal gates need readable tests that
  distinguish preferred imports from removal approval.
  Preconditions: boundary helper extraction is available or the planner
  records a safe independent split.
  Parallel hints: can follow direction 002; co-schedule only with disjoint test
  files.
  Boundary notes: do not change compatibility facade exposure or policy
  classifications.
  Extraction notes: preserve tests for `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission`.
  Status: completed by `round-085` at `fec075a`; the reviewed split added
  `test/FacadeImportPolicySpec.hs`, kept the existing `test/Main.hs`
  aggregation reaching `workflowFacadeImportPolicyTests`, and added only the
  required `watcher-core-test` `other-modules` metadata for the extracted
  module. The moved checks preserve compatibility-facade policy
  classifications, runner reachability, source-scan detail, replay parity, and
  permission-policy assertions. This status does not approve production import
  convergence, public deprecation, facade removal, Cabal exposure removal,
  runtime compatibility-file removal, or compatibility-file rename/deletion.

- Direction id: `direction-004-workflow-behavior-test-split`
  Summary: Extract workflow behavior tests out of `test/Main.hs` once shared
  test helpers are stable.
  Why it matters now: large-module cleanup needs focused behavior tests before
  production extraction.
  Preconditions: helper ownership from directions 002 and 003 is clear.
  Parallel hints: serial with other `test/Main.hs` work.
  Boundary notes: behavior coverage must be preserved; no production changes.
  Extraction notes: keep test ordering and aggregate result wiring easy to
  audit.
  Status: completed by `round-086` at `0dc85da`; the reviewed split added
  `test/WorkflowEventLogSpec.hs`, `test/WorkflowAgentSpec.hs`,
  `test/WorkflowIndexedSpec.hs`, `test/WorkflowDocsMigrationSpec.hs`,
  `test/WorkflowExecutionSpec.hs`, and `test/TestSupport/Workflow.hs`, kept
  `workflowFacadeExtractionTests` as the watcher-core aggregation path reaching
  the moved runners, and added only the required `watcher-core-test`
  `other-modules` metadata. Reviewer evidence records preserved assertion and
  PASS labels, runner reachability, a `test/Main.hs` reduction from 15473 to
  7120 lines, `cabal test watcher-core-test`, `cabal build all`, and diff
  hygiene. This status completes milestone 001 but does not approve production
  import convergence, public deprecation, facade removal, Cabal exposure
  removal, runtime compatibility-file removal, release approval, or
  compatibility-file rename/deletion.

### 2. [pending] Compatibility Fixtures And Runtime-State Contracts

Milestone id: `milestone-002-compatibility-fixtures-contracts`
Depends on: `milestone-001-test-topology-inventory`
Intent: Add missing evidence for runtime compatibility files and clarify the
current state-file contract before runtime-state cleanup.
Completion signal: fixture and test coverage exists for the selected old and
current JSON shapes; `planner-state.json` versus `planning-state.json` has an
explicit reviewed contract; healthcheck behavior is documented and tested; and
runtime compatibility cleanup candidates are classified as keep, defer,
deprecate, migrate, or remove with blockers.
Parallel lane: compatibility fixture lane after test helpers are stable
Coordination notes: fixture additions may be split by state file, but
healthcheck and write-timing semantics must stay coherent.
Current status: `round-087-compatibility-fixture-gap-inventory` completed
`direction-005-compatibility-fixture-gap-inventory` as artifact-only evidence
in
`orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md` at
merged commit `51774b6`, and `round-088-planner-vs-planning-state-contract`
completed `direction-006-planner-vs-planning-state-contract` at merged commit
`1ebf426` by locking `planner-state.json` and `planning-state.json` as
distinct compatibility surfaces, and `round-089` completed the
`round-089-runtime-owner-healthcheck-contract` extraction under
`direction-008-healthcheck-compatibility-contracts` at merged commit `fa1337c`
by locking the current `runtime-owner.json` healthcheck field-path contract,
and `round-090-planner-planning-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`b2ffeed` by adding checked-in fixture and test evidence for the
`planner-state.json` and `planning-state.json` issue-planning surfaces only,
and `round-091-daemon-state-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`fd7be82` by adding checked-in fixture and test evidence for the active and
stopped `daemon-state.json` shapes only, and
`round-092-repair-failure-block-state-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`047b5d7` by adding checked-in fixture and test evidence for the
repair-failure `block-state.json` shape only, and
`round-093-repair-state-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`d70a0c3` by adding checked-in fixture and test evidence for the current
`repair-state.json` repair-summary shape only, including the current
write-order, compatibility-rewrite separation, and non-reader/non-healthcheck
boundaries.
Milestone 002 is in progress, not complete: the inventory names fixture,
healthcheck-contract, operator/downstream, and removal/migration blockers, the
state-file contract is now explicit, the runtime-owner healthcheck contract is
now recorded, and the planner/planning, daemon-state, repair-failure
block-state, and repair-state fixture slices are covered, but broad
fixture/test coverage for remaining selected compatibility surfaces,
healthcheck compatibility-contract evidence for remaining selected surfaces,
and final cleanup classifications still remain for later directions.
This status does not approve deprecation, facade removal, Cabal exposure
removal, runtime compatibility-file deletion or rename, healthcheck behavior
changes, repair behavior changes, restart behavior changes, fixture batch
approval, release approval, terminal completion, or public compatibility
removal.

Candidate directions:

- Direction id: `direction-005-compatibility-fixture-gap-inventory`
  Summary: Refresh fixture gaps for planning, daemon, block, repair,
  runtime-owner, checked-in snapshots, and live issue-snapshot surfaces.
  Why it matters now: policy line items already name missing gates, and future
  runtime cleanup must not guess.
  Preconditions: milestone 001 inventory or current policy evidence.
  Parallel hints: serial; establishes fixture ownership and priorities.
  Boundary notes: no runtime behavior or file-name change.
  Extraction notes: compare production producers/readers, healthcheck readers,
  golden snapshots, and docs policy.
  Status: completed by `round-087` at `51774b6`; the reviewed artifact-only
  inventory covers planning, daemon, block, repair, runtime-owner, checked-in
  compatibility snapshots, and live `issue-snapshot.json` surfaces. It records
  current producers and readers, healthcheck reader and non-reader evidence,
  existing checked-in fixture coverage, policy references, and prioritized
  blockers for future fixture, healthcheck-contract, planner/planning-contract,
  operator/downstream, and removal/migration rounds. Missing fixtures and
  non-reader evidence are blockers only; this status does not approve
  deprecation, facade removal, Cabal exposure removal, runtime
  compatibility-file deletion or rename, healthcheck behavior changes, repair
  behavior changes, release approval, or public compatibility removal.

- Direction id: `direction-006-planner-vs-planning-state-contract`
  Summary: Record and test the compatibility contract for
  `planner-state.json` and `planning-state.json`.
  Why it matters now: runtime writes both names, healthcheck reads
  `planner-state.json`, and docs mostly discuss `planning-state.json`.
  Preconditions: fixture gap inventory or direct source evidence from
  `Runtime.Compatibility` and `Healthcheck`.
  Parallel hints: may run before broad fixture additions if scoped narrowly.
  Boundary notes: no rename, deletion, or healthcheck reader change unless a
  later reviewed behavior-change direction approves it.
  Extraction notes: include producer, reader, docs, and fixture expectations.
  Status: completed by `round-088` at `1ebf426`; the reviewed implementation
  added watcher-core tests that distinguish `planner-state.json` summary/status
  writes from `planning-state.json` graph writes, strengthened the direct
  `RecordPlanningGraph` test so it writes only `planning-state.json`,
  strengthened the healthcheck source-policy assertion so issue planning reads
  `planner-state.json` and not `planning-state.json`, and added a narrow
  compatibility policy row for `planner-state.json` as a distinct kept
  surface. This status records the current compatibility contract only; it
  does not approve file rename/deletion, schema migration, healthcheck reader
  behavior changes, repair behavior changes, fixture batch expansion,
  deprecation, migration, runtime compatibility-file removal, release
  approval, or public compatibility removal.

- Direction id: `direction-007-runtime-compatibility-fixtures`
  Summary: Add focused fixtures for selected compatibility files and current
  tolerated legacy shapes.
  Why it matters now: runtime-state cleanup is blocked until old/current JSON
  shapes are checked in and replayable where applicable.
  Preconditions: direction 005 inventory.
  Parallel hints: state-file slices may be parallel only with disjoint fixture
  paths and tests.
  Boundary notes: no deletion, rename, or schema migration.
  Extraction notes: prioritize `daemon-state.json`, `planning-state.json`,
  `block-state.json`, `repair-state.json`, `runtime-owner.json`, checked-in
  compatibility snapshots, and live `issue-snapshot.json`.
  Status: partial; `round-090` completed
  `round-090-planner-planning-compatibility-fixtures` at `b2ffeed` for the
  `planner-state.json` / `planning-state.json` issue-planning slice only. The
  reviewed round added five checked-in fixtures under
  `golden/runtime-compatibility/issue-planning/...` and watcher-core
  assertions for exact fixture JSON shapes, compatibility projection writes,
  direct `RecordPlanningGraph` behavior, and the current healthcheck reader
  boundary. `round-091` completed
  `round-091-daemon-state-compatibility-fixtures` at `fd7be82` for the active
  and stopped `daemon-state.json` slice only. The reviewed round added two
  checked-in fixtures under
  `golden/runtime-compatibility/daemon-state/...` and watcher-core assertions
  for exact active/stopped fixture JSON shapes, snapshot-reader tolerance,
  representative compatibility projection writes, non-interchangeability, and
  the current healthcheck, repair rewrite, and restart cleanup source
  boundaries. `round-092` completed
  `round-092-repair-failure-block-state-compatibility-fixtures` at `047b5d7`
  for the repair-failure `block-state.json` slice only. The reviewed round
  added the checked-in fixture
  `golden/runtime-compatibility/block-state/repair-failure/block-state.json`
  and watcher-core assertions for exact parity with
  `repairFailureBlockStateJson`, snapshot-reader tolerance,
  repair-failure-specific fields, non-interchangeability with normal blocked
  writes, and the current automatic-loop writer, healthcheck reader, snapshot
  reader, successful-repair stale-block cleanup, and restart cleanup source
  boundaries. `round-093` completed
  `round-093-repair-state-compatibility-fixtures` at `d70a0c3` for the current
  `repair-state.json` repair-summary slice only. The reviewed round added the
  checked-in fixture
  `golden/runtime-compatibility/repair-state/completion-without-implementation/repair-state.json`
  and watcher-core assertions for exact summary shape, executed
  `repairInvalidState` output parity after archive-path normalization,
  separation from repair-failure `block-state.json`, repair writer ordering,
  compatibility rewrite separation, and the current non-reader/non-healthcheck
  source boundaries. This is fixture/test evidence for the selected planning,
  daemon-state, repair-failure block-state, and repair-state slices only; it
  does not approve deletion, rename, schema migration, healthcheck behavior
  changes, repair behavior changes, restart behavior changes, broad fixture
  batch approval, deprecation, facade removal, Cabal exposure removal, release
  approval, terminal completion, or public compatibility removal. Direction
  007 remains incomplete because fixtures for remaining selected runtime
  compatibility surfaces still require later slices.

- Direction id: `direction-008-healthcheck-compatibility-contracts`
  Summary: Add or refresh healthcheck tests for compatibility-state files that
  healthcheck reads or explicitly does not read.
  Why it matters now: healthcheck is an operator-facing compatibility reader,
  so cleanup requires exact read-only behavior evidence.
  Preconditions: direction 005 or 006 evidence for selected files.
  Parallel hints: can pair with fixture work only when touched test modules do
  not overlap.
  Boundary notes: no healthcheck behavior change without focused approval.
  Extraction notes: record explicit non-reader policy for write-only files such
  as `planning-state.json` or `repair-state.json` when applicable.
  Status: partial; `round-089` completed
  `round-089-runtime-owner-healthcheck-contract` at `fa1337c` for the
  `runtime-owner.json` slice only. The reviewed round added runtime-owner JSON
  assertions, a healthcheck source-policy assertion preserving
  `runtime-owner.json` as the `runtimeOwner` state surface for issue planning,
  issue implementation, and PR review, and a narrow policy note recording that
  the current summary lookup remains `["runtimeOwner", "owner"]` rather than
  the lease-shaped `["runtimeOwner", "lease", "runtime"]` path. This is
  current contract evidence only; it does not approve healthcheck behavior
  changes, runtime-owner schema or producer changes, script changes, fixture
  batch approval, file deletion or rename, schema migration, repair behavior
  changes, deprecation or removal, release approval, or public compatibility
  removal. Remaining healthcheck-contract surfaces from the milestone and
  round-087 inventory still require later selected slices, so direction 008 is
  not complete.

### 3. [pending] Import Convergence And Package-Boundary Cleanup

Milestone id: `milestone-003-import-convergence-package-boundaries`
Depends on: `milestone-001-test-topology-inventory`
Intent: Continue package-boundary cleanup by moving new and internal reusable
package-oriented code away from compatibility facade imports while keeping
public facades exposed until gates are met.
Completion signal: direct-owner imports replace safe internal facade imports;
remaining facade users are inventoried with reasons; package-boundary tests
protect reusable packages from moifold-owned dependencies; and no public
deprecation or removal is implied.
Parallel lane: import convergence lane after inventory
Coordination notes: import migration is not deprecation. Keep facades exposed
in `moifold.cabal` until exact removal gates are approved.

Candidate directions:

- Direction id: `direction-009-facade-import-scan-refresh`
  Summary: Refresh current imports of `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission`.
  Why it matters now: prior counts are useful history, but cleanup rounds need
  current imports after test splits and fixture work.
  Preconditions: milestone 001 inventory.
  Parallel hints: serial evidence round.
  Boundary notes: no import changes or public surface changes.
  Extraction notes: include `src`, `app`, `test`, package descriptors, docs,
  and standalone package candidates.

- Direction id: `direction-010-appserverclient-import-convergence`
  Summary: Move safe remaining internal `CodexWatcher.AppServerClient` imports
  to direct Codex client and transport modules.
  Why it matters now: it reduces facade dependence while preserving the public
  compatibility module.
  Preconditions: current import scan and focused app-server behavior evidence.
  Parallel hints: may be independent of Core.Ids slices if file ownership is
  disjoint.
  Boundary notes: no facade deletion, Cabal exposure change, or deprecation
  pragma.
  Extraction notes: preserve endpoint parsing, session protocol, command
  rendering, and failure formatting.

- Direction id: `direction-011-core-ids-import-convergence`
  Summary: Split remaining safe `CodexWatcher.Core.Ids` users onto direct
  agent-id or GitHub-id owner modules.
  Why it matters now: the combined id facade obscures package ownership in
  reusable or executable-adjacent code.
  Preconditions: current import scan, package descriptor impact check, and
  parser/rendering behavior evidence.
  Parallel hints: may be sliced by domain when ownership is disjoint.
  Boundary notes: do not change constructors, parsers, renderers, or command
  output.
  Extraction notes: record each remaining combined-facade user and blocker.

- Direction id: `direction-012-eventlog-permission-bridge-split-readiness`
  Summary: Prepare exact split evidence for `Workflow.EventLog` and
  `Workflow.Permission` mixed moifold bridge behavior.
  Why it matters now: these facades are not pure reexports, and removal needs a
  concrete owner split before public API action.
  Preconditions: current import scan and fixture/behavior coverage for touched
  replay or permission behavior.
  Parallel hints: serial; both surfaces affect workflow correctness.
  Boundary notes: no public deprecation, Cabal exposure change, or removal.
  Extraction notes: separate reusable core imports from concrete moifold bridge
  helpers and record what remains product-owned.

### 4. [pending] Large Runtime Module Decomposition

Milestone id: `milestone-004-large-module-decomposition`
Depends on: `milestone-001-test-topology-inventory`
Intent: Split the largest runtime and workflow modules behind focused tests so
future behavior changes are reviewable.
Completion signal: each selected module has a smaller, named ownership split;
focused tests cover the moved behavior; public exports remain stable unless a
specific reviewed direction approves a change; and baseline build/test checks
pass after each split.
Parallel lane: large-module split lane, one module family at a time by default
Coordination notes: pure extraction is preferred. Behavior changes require a
separate selected direction with focused tests.

Candidate directions:

- Direction id: `direction-013-daemon-module-split`
  Summary: Split `CodexWatcher.Daemon` into focused runtime, tick, or command
  ownership modules without changing daemon behavior.
  Why it matters now: daemon code sits on real runtime behavior and should be
  smaller before further cleanup.
  Preconditions: focused daemon tests or extracted behavior tests from
  milestone 001.
  Parallel hints: serial with other daemon/runtime changes.
  Boundary notes: preserve daemon result shapes, event append order,
  compatibility writes, and runtime ownership.
  Extraction notes: record moved exports and unchanged public API evidence.

- Direction id: `direction-014-docs-migration-module-split`
  Summary: Split `Workflow.DocsMigration` into smaller parsing, planning, and
  replay/application owners.
  Why it matters now: docs migration has golden and replay behavior that should
  be isolated before cleanup.
  Preconditions: current docs migration tests and golden replay evidence.
  Parallel hints: serial unless only test support moves.
  Boundary notes: preserve docs migration event schemas and golden behavior.
  Extraction notes: keep old fixture replay coverage in the same reviewed
  slice.

- Direction id: `direction-015-issue-implement-indexed-module-split`
  Summary: Split `Workflow.Moifold.IssueImplement.Indexed` into smaller indexed
  policy, observation, transition, or adapter owners.
  Why it matters now: indexed issue implementation is behavior-sensitive and
  blocks future workflow cleanup if it stays monolithic.
  Preconditions: focused indexed issue-implement tests and parity evidence.
  Parallel hints: serial; avoid overlapping issue implementation behavior
  changes.
  Boundary notes: preserve event schemas, daemon routing, dry-run text,
  request-id progression, and state transition parity.
  Extraction notes: do not move concrete moifold policy into reusable packages.

- Direction id: `direction-016-eventlog-types-module-split`
  Summary: Split `CodexWatcher.EventLog.Types` into smaller event groups or
  codec ownership modules.
  Why it matters now: event type code is central compatibility surface and
  should be easier to audit before schema cleanup.
  Preconditions: golden event-log, codec, and replay tests for touched
  constructors.
  Parallel hints: serial.
  Boundary notes: no event JSON `type` change, schema-version change, or old
  log rejection unless separately approved.
  Extraction notes: preserve parse/render behavior and fixture compatibility.

- Direction id: `direction-017-turn-output-module-split`
  Summary: Split `CodexWatcher.TurnOutput` into structured-output, prompt
  version, and rendering owners.
  Why it matters now: turn output and prompt compatibility are user-visible and
  should be isolated before cleanup.
  Preconditions: focused output/prompt tests for touched behavior.
  Parallel hints: serial with prompt or app-server output changes.
  Boundary notes: preserve structured-output requirements and prompt schema
  compatibility.
  Extraction notes: do not change app-server protocol or output parsing as an
  incidental extraction.

### 5. [pending] Runtime Compatibility Cleanup Gates

Milestone id: `milestone-005-runtime-compatibility-cleanup-gates`
Depends on: `milestone-002-compatibility-fixtures-contracts`
Intent: Turn compatibility fixture evidence into exact keep, defer, migrate,
  deprecate, or remove decisions for runtime compatibility surfaces.
Completion signal: every selected runtime compatibility file has a reviewed
decision with fixture, old-log, repair, healthcheck, write-timing,
operator/downstream, and baseline validation evidence; approved migrations or
removals are exact and scoped.
Parallel lane: serial by default
Coordination notes: do not delete runtime compatibility files from local
absence alone. Missing downstream/operator evidence means defer or keep.

Candidate directions:

- Direction id: `direction-018-runtime-compatibility-decision-refresh`
  Summary: Refresh the compatibility-file policy table after fixture and
  healthcheck contract work.
  Why it matters now: cleanup decisions must reflect current evidence, not
  older policy gaps.
  Preconditions: milestone 002 complete or selected fixture evidence accepted.
  Parallel hints: serial evidence round.
  Boundary notes: no deletion, rename, or schema change.
  Extraction notes: classify each selected file as keep, defer, migrate,
  deprecate, or remove with blockers.

- Direction id: `direction-019-selected-compatibility-file-migration`
  Summary: Land exact approved migrations for compatibility files whose gates
  are satisfied.
  Why it matters now: not every cleanup requires deletion; some may need docs,
  healthcheck, or fixture alignment.
  Preconditions: direction 018 approval naming the exact file and migration.
  Parallel hints: serial unless files have disjoint producers, readers, and
  fixtures.
  Boundary notes: preserve event truth, repair ordering, healthcheck behavior,
  and write timing.
  Extraction notes: update fixtures, docs, tests, and policy in one reviewed
  slice.

- Direction id: `direction-020-selected-compatibility-file-removal`
  Summary: Remove only compatibility files whose removal gates are all approved.
  Why it matters now: deletion is the final cleanup action, not the first.
  Preconditions: reviewer approval naming exact file paths and satisfied gates.
  Parallel hints: serial.
  Boundary notes: no broad runtime compatibility cleanup by implication.
  Extraction notes: include old-log, fixture, healthcheck, repair,
  write-timing, operator/downstream, and baseline evidence.

### 6. [pending] Final Deprecation And Removal Campaign

Milestone id: `milestone-006-final-deprecation-removal`
Depends on:
`milestone-003-import-convergence-package-boundaries`,
`milestone-005-runtime-compatibility-cleanup-gates`
Intent: Perform only exact public deprecations and removals whose gates are
complete, then keep expanding until every roadmap-covered compatibility surface
is removed cleanly.
Completion signal: every selected facade, compatibility file, public module,
exposed-module entry, deprecated symbol, and deferred cleanup surface has
landed its approved clean removal or migration away from supported
compatibility paths with docs, Cabal, fixture, behavior, and downstream
evidence; the final report has empty kept, deferred, and blocked
compatibility-surface sets.
Parallel lane: serial
Coordination notes: deprecation is externally visible. Removal requires exact
approval and cannot be inferred from preferred-import guidance.

Candidate directions:

- Direction id: `direction-021-public-deprecation-readiness`
  Summary: Decide which compatibility facades or runtime surfaces should
  receive explicit public deprecation signals.
  Why it matters now: warnings and docs are public API signals and must be
  aligned before removal.
  Preconditions: import convergence, fixture evidence, policy refresh, and
  downstream inventory for the exact surface.
  Parallel hints: serial.
  Boundary notes: no deprecation pragma or wording unless the exact surface is
  approved.
  Extraction notes: include docs, Haddock, changelog/release-note constraints,
  Cabal exposure, and downstream scope.

- Direction id: `direction-022-cabal-exposure-and-public-api-decision`
  Summary: Decide whether exact exposed modules or public exports can be
  removed, deprecated, or must remain available.
  Why it matters now: Cabal exposure is the compatibility boundary for
  downstream imports.
  Preconditions: public deprecation readiness and current import/downstream
  scans.
  Parallel hints: serial.
  Boundary notes: no exposed-module deletion from local absence alone.
  Extraction notes: reviewer approval must name the exact module, export, or
  exposed-module entry.

- Direction id: `direction-023-exact-approved-removals`
  Summary: Remove only deprecated or otherwise exact-approved surfaces whose
  gates are satisfied.
  Why it matters now: this is the final cleanup action after evidence and
  public compatibility alignment.
  Preconditions: exact approval for the surface, including import, behavior,
  fixture, docs, Cabal, and downstream evidence.
  Parallel hints: serial.
  Boundary notes: do not bundle unrelated removals.
  Extraction notes: record removed-surface set, retained-surface set, build/test
  evidence, focused behavior evidence, and policy updates.

- Direction id: `direction-024-terminal-cleanup-report`
  Summary: Prove compatibility removal is complete or expand the roadmap with
  the next cleanup milestones.
  Why it matters now: a broad cleanup family must not silently finish by
  exhausting tasks while compatibility surfaces remain.
  Preconditions: deprecation/removal rounds complete and every
  roadmap-covered compatibility surface has a reviewed removed or migrated
  final state.
  Parallel hints: serial.
  Boundary notes: a hold is valid as interim evidence only; it is not terminal
  success. If any compatibility surface remains kept, deferred, blocked, or
  hold-only, or if evidence names additional high-value cleanup not covered by
  the current milestones, terminal closeout is not ready; the guider should add
  a reviewed roadmap revision with additional milestones instead.
  Extraction notes: include kept, deferred, deprecated, removed, migrated, and
  blocked surface sets plus validation commands. The kept, deferred, and
  blocked compatibility-surface sets must be empty for terminal approval; if
  they are not empty, author an expansion update that names the next
  milestones, dependencies, and verification gates.
