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
boundaries, and `round-094-runtime-owner-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`1ab9db7` by adding checked-in fixture and test evidence for the current
`runtime-owner.json` top-level `lease` shape only, including current
runtime-owner reader acceptance, healthcheck `runtimeOwner` mapping and summary
field path, and restart-script pid extraction and cleanup boundaries, and
`round-095-live-issue-snapshot-compatibility-fixtures` completed a
`direction-007-runtime-compatibility-fixtures` slice at merged commit
`aaa2e85` by adding checked-in fixture and test evidence for the current live
`issue-snapshot.json` planner snapshot shape only, including current writer
shape, `planningIssueFactsFromSnapshot` parser acceptance, execute-mode
write-before-planner-turn timing, planner prompt path consumption, and
healthcheck, repair, replay, and restart non-reader boundaries, and
`round-096-runtime-state-healthcheck-read-nonread-contracts` completed a
`direction-008-healthcheck-compatibility-contracts` slice at merged commit
`0d1a0b2` by adding watcher-core source-policy evidence for the current
healthcheck runtime-state read/non-read contract across selected surfaces:
issue planning reads `planner-state.json` through shared state, issue
implementation reads shared state plus `issue-state.json`, PR review keeps
`block-state.json` and `runtime-owner.json`, shared state keeps
`daemon-state.json`, `block-state.json`, and `runtime-owner.json`, healthcheck
does not read `planning-state.json`, `repair-state.json`, or live
`issue-snapshot.json`, and the runtime-owner summary path remains
`["runtimeOwner", "owner"]`.
Milestone 002 is in progress, not complete: the inventory names fixture,
healthcheck-contract, operator/downstream, and removal/migration blockers, the
state-file contract is now explicit, the planner/planning, daemon-state,
repair-failure block-state, repair-state, runtime-owner current-lease, and live
issue-snapshot fixture slices are covered, and the runtime-owner field-path and
consolidated healthcheck read/non-read contracts are now recorded, but any
additional fixture slices justified by later checked-in snapshot or downstream
evidence and final cleanup classifications still remain for later directions.
This status does not approve deprecation, facade removal, Cabal exposure
removal, runtime compatibility-file deletion, rename, or migration, healthcheck
behavior changes, repair behavior changes, restart behavior changes, fixture
batch approval, cleanup classification or removal approval, release approval,
milestone completion, terminal completion, or public compatibility removal.

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
  source boundaries. `round-094` completed
  `round-094-runtime-owner-compatibility-fixtures` at `1ab9db7` for the
  current `runtime-owner.json` top-level `lease` slice only. The reviewed round
  added the checked-in fixture
  `golden/runtime-compatibility/runtime-owner/current-lease/runtime-owner.json`
  and watcher-core assertions for exact `runtimeLeaseJson` parity, top-level
  legacy-field absence, nested lease field paths and values, runtime-owner
  reader acceptance, the current healthcheck `runtimeOwner` mapping and
  `["runtimeOwner", "owner"]` summary path, and restart-script pid extraction,
  stop, and cleanup assumptions. `round-095` completed
  `round-095-live-issue-snapshot-compatibility-fixtures` at `aaa2e85` for the
  current live `issue-snapshot.json` planner snapshot slice only. The reviewed
  round added the checked-in fixture
  `golden/runtime-compatibility/issue-snapshot/scoped-open-with-closed-subissue/issue-snapshot.json`
  and watcher-core assertions for exact current snapshot shape, parser
  acceptance through `planningIssueFactsFromSnapshot`, execute-mode
  write-before-planner-turn timing, planner prompt path rendering, and current
  healthcheck, repair, replay, and restart non-reader source boundaries. This
  is fixture/test evidence for the selected planning, daemon-state,
  repair-failure block-state, repair-state, runtime-owner current-lease, and
  live issue-snapshot slices only; it does not approve deletion, rename, schema
  migration, healthcheck behavior changes, script behavior changes, repair
  behavior changes, restart behavior changes, broad fixture batch approval,
  checked-in snapshot cleanup, deprecation, facade removal, Cabal exposure
  removal, release approval, terminal completion, or public compatibility
  removal. Direction 007 remains partial: round-095 closes the live
  issue-snapshot fixture blocker from the round-087 inventory, but it does not
  approve broad fixture batch completion, checked-in snapshot cleanup, or later
  cleanup classification/removal gates.

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
  Status: completed for the current selected healthcheck-contract surfaces;
  `round-089` completed
  `round-089-runtime-owner-healthcheck-contract` at `fa1337c` for the
  `runtime-owner.json` slice only. The reviewed round added runtime-owner JSON
  assertions, a healthcheck source-policy assertion preserving
  `runtime-owner.json` as the `runtimeOwner` state surface for issue planning,
  issue implementation, and PR review, and a narrow policy note recording that
  the current summary lookup remains `["runtimeOwner", "owner"]` rather than
  the lease-shaped `["runtimeOwner", "lease", "runtime"]` path. `round-096`
  completed `round-096-runtime-state-healthcheck-read-nonread-contracts` at
  `0d1a0b2` by adding a consolidated watcher-core source-policy assertion for
  the current healthcheck runtime-state read/non-read contract: issue planning
  reads `planner-state.json` through shared state, issue implementation reads
  shared state plus `issue-state.json`, PR review keeps `block-state.json` and
  `runtime-owner.json`, shared state keeps `daemon-state.json`,
  `block-state.json`, and `runtime-owner.json`, healthcheck does not mention
  `planning-state.json`, `repair-state.json`, or live `issue-snapshot.json`,
  healthcheck remains read-only for these source-policy checks, and the
  runtime-owner summary lookup remains `["runtimeOwner", "owner"]`. This is
  current contract evidence only; it does not approve production healthcheck
  behavior changes, runtime-owner schema or producer changes, script changes,
  broad fixture batch approval, compatibility-file deletion, rename, or
  migration, repair behavior changes, deprecation or removal, cleanup
  classification or removal approval, release approval, milestone completion,
  terminal completion, or public compatibility removal.

### 3. [in-progress] Import Convergence And Package-Boundary Cleanup

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
Current status: `round-097-facade-import-scan-refresh` completed
`direction-009-facade-import-scan-refresh` as artifact-only accepted evidence
at merged commit `04a675c`. The accepted inventory records current
selected-facade import counts of `CodexWatcher.AppServerClient`: 19
(`src`: 12, `test`: 7), `CodexWatcher.Core.Ids`: 44 (`src`: 31, `app`: 1,
`test`: 12), `CodexWatcher.Workflow.EventLog`: 10 (`src`: 2, `test`: 8), and
`CodexWatcher.Workflow.Permission`: 7 (`test`: 7); confirms `moifold.cabal`
still exposes all four selected compatibility facades; confirms no exact
selected-facade imports under `agent-workflow-core`, `agent-workflow-codex`,
or `agent-workflow-github`; and corrects the current `Core.Ids` classification
to 3 GitHub-only candidates, 2 agent-only candidates, and 39 combined users,
with `test/BoundaryPolicySpec.hs` classified as GitHub-only. Later convergence
remains blocked by per-surface evidence: `AppServerClient` needs endpoint
parsing, protocol, session handling, command rendering, fallback, timeout, and
failure-formatting checks; `Core.Ids` combined users need parser/renderer,
serialization, prompt/output, runtime-config, and fixture stability evidence;
`Workflow.EventLog` needs generic event-log/audit uses separated from moifold
wrapper uses plus golden replay, old-log parsing, event JSON `type`,
transition/replay parity, and wrapper behavior evidence; and
`Workflow.Permission` needs reusable permission-core uses separated from
concrete moifold policy helpers plus permission soundness, phase-validation,
state/effect validation, public API, and downstream evidence. This status does
not approve import migration, Cabal exposure changes, public deprecation,
facade removal, runtime compatibility cleanup, release/publication, milestone
completion, or terminal completion. `round-098` completed a narrow
`direction-011-core-ids-import-convergence` slice at merged commit `c223018`
by moving `test/BoundaryPolicySpec.hs` from the combined
`CodexWatcher.Core.Ids` compatibility facade to direct
`CodexWatcher.Workflow.GitHub.Ids`, preserving boundary-policy assertions and
command parity checks, leaving `moifold.cabal` unchanged, and passing
`cabal test watcher-core-test` plus `cabal build all`. This status records
one test-only direct-owner import convergence and does not approve production
import convergence, combined-user migration, parser, renderer, command-output,
prompt, fixture, runtime-config, public facade exposure, deprecation, removal,
release/publication, milestone completion, or terminal completion changes.
`round-099` completed a narrow production agent-id-only
`direction-011-core-ids-import-convergence` slice at merged commit `08bd47a`
by moving `src/CodexWatcher/Workflow/Execution.hs` from
`CodexWatcher.Core.Ids (RequestId)` to direct
`CodexWatcher.Workflow.Agent.Ids (RequestId)`, preserving workflow execution
behavior, request-id threading, dry-run conversion, action partitioning, and
checked execution behavior, leaving `moifold.cabal` unchanged, and passing
`cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
`git diff --cached --check`. This status records one production
agent-id-only direct-owner import convergence and does not approve
AppServerClient, Workflow.EventLog, Workflow.Permission, combined Core.Ids
user migration, public facade exposure changes, Cabal exposure removal,
package descriptor cleanup, parser, renderer, command-output, prompt,
fixture, runtime-config, runtime compatibility cleanup, deprecation, removal,
release/publication, milestone completion, or terminal completion changes.
`round-100` completed a narrow production GitHub-id-only
`direction-011-core-ids-import-convergence` slice at merged commit `080fed5`
by moving `src/CodexWatcher/Core/State.hs` from
`CodexWatcher.Core.Ids (CommitSha, PrNumber)` to direct
`CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`, preserving
`CompletionEvidence`, `WatcherState`, `SomeWatcherState`, constructors,
exports, deriving behavior, and existing watcher-core coverage, leaving
package descriptors and public compatibility facade exposure unchanged, and
passing `cabal test watcher-core-test`, `cabal build all`,
`git diff --check`, and `git diff --cached --check`. This status records one
production GitHub-id-only direct-owner import convergence and does not approve
AppServerClient, Workflow.EventLog, Workflow.Permission, combined Core.Ids
user migration, public facade exposure changes, Cabal exposure removal,
package descriptor cleanup, parser, renderer, command-output, prompt,
fixture, runtime-config, runtime compatibility cleanup, deprecation, removal,
release/publication, milestone completion, or terminal completion changes.
`round-101` completed a narrow executable GitHub-id-only
`direction-011-core-ids-import-convergence` slice at merged commit `93196cd`
by moving `app/Main.hs` from
`CodexWatcher.Core.Ids (RepoName (unRepoName))` to direct
`CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))`, preserving
`healthcheckOptionsFromCli` behavior, leaving public compatibility facade
exposure unchanged, adding only the compile-proven executable dependency
`agent-workflow-github >=0.1 && <0.2` to `executable moifold`, and passing
`cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
`git diff --cached --check`. This status records one executable
GitHub-id-only direct-owner import convergence plus the required executable
dependency, and does not approve AppServerClient, Workflow.EventLog,
Workflow.Permission, combined Core.Ids user migration, public facade exposure
changes, Cabal exposure removal, package descriptor cleanup beyond the narrow
executable dependency, parser, renderer, command-output, prompt, fixture,
runtime-config, runtime compatibility cleanup, deprecation, removal,
release/publication, milestone completion, or terminal completion changes.
`round-102` completed a narrow test agent-id-only
`direction-011-core-ids-import-convergence` slice at merged commit `ead9081`
by moving `test/WorkflowDocsMigrationSpec.hs` from
`CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`, preserving
existing docs-migration workflow behavior coverage and term-level id fixtures,
leaving package descriptors and public compatibility facade exposure
unchanged, and passing `cabal test watcher-core-test`, `cabal build all`,
`git diff --check`, and `git diff --cached --check`. This status records one
test agent-id-only direct-owner import convergence and does not approve
AppServerClient, Workflow.EventLog, Workflow.Permission, combined Core.Ids
user migration, broader Core.Ids migration, public facade exposure changes,
Cabal exposure removal, package descriptor cleanup, parser, renderer,
command-output, prompt, fixture, runtime-config, runtime compatibility
cleanup, deprecation, removal, release/publication, milestone completion, or
terminal completion changes. `round-103` completed the artifact-only
`round-103-core-ids-remaining-blocker-readiness` evidence round at merged
commit `b2eee52`. The approved live scan after rounds 098 through 102 records
39 remaining `CodexWatcher.Core.Ids` imports: 29 under `src`, 10 under `test`,
0 under `app`, and 0 under standalone package candidates. The five prior safe
single-domain candidates no longer import the facade and now use direct owner
imports. The remaining users are blocker-class production surfaces or
test-policy evidence surfaces, so direction 011's current single-domain queue
is closed. Any later `Core.Ids` work should be selected as split-import or
bridge-readiness slices with focused evidence. This status does not approve
broader Core.Ids migration, public deprecation, facade removal, Cabal exposure
removal, package descriptor cleanup, runtime compatibility cleanup,
release/publication, milestone completion, or terminal completion changes.

`round-104` completed the artifact-only
`round-104-eventlog-permission-bridge-split-readiness` evidence round at
merged commit `073a5d6` under direction 012. The approved live scan records
`CodexWatcher.Workflow.EventLog` imports at `src`: 2 and `test`: 8, and
`CodexWatcher.Workflow.Permission` imports at `test`: 7, with both facades at
`app`: 0 and standalone package candidate imports: 0. The evidence confirms
`moifold.cabal` still exposes both compatibility facades, while
`agent-workflow-core` exposes direct-owner modules
`CodexWatcher.Workflow.Audit`,
`CodexWatcher.Workflow.EventLog.Commit.Core`,
`CodexWatcher.Workflow.EventLog.Core`,
`CodexWatcher.Workflow.EventLog.File.Core`, and
`CodexWatcher.Workflow.Permission.Core`. The artifact classifies the mixed
export surfaces and each live importer; strongest later candidates include
`src/CodexWatcher/Workflow/DocsMigration.hs` and
`src/CodexWatcher/Daemon.hs`, both requiring focused behavior gates before any
future migration. Later work must remain narrow and gate-backed. This status
does not approve import migration, public deprecation or removal, Cabal
exposure removal, package descriptor cleanup, runtime compatibility cleanup,
release approval, milestone completion, or terminal completion.
`round-105` completed the artifact-only
`round-105-appserverclient-import-convergence-readiness` evidence round at
merged commit `d145f79` under direction 010. The approved live scan records
`CodexWatcher.AppServerClient` imports at `src`: 12, `test`: 7, `app`: 0,
`agent-workflow-core`: 0, `agent-workflow-codex`: 0, and
`agent-workflow-github`: 0. The evidence confirms
`CodexWatcher.AppServerClient` remains a public compatibility reexport of
`CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport`; `moifold.cabal` still exposes
the facade; and `agent-workflow-codex` exposes the direct owner modules. The
artifact classifies all source and test importers and records later gates for
endpoint parsing, app-server protocol, session handling, command rendering,
timeout, fallback, failure formatting, turn-classifier behavior, package
descriptor/public API/docs/downstream/test-policy evidence, and any public
surface cleanup. Later migration candidates are gate-backed only. This status
does not approve import migration, public deprecation or removal, Cabal
exposure removal, package descriptor cleanup, behavior change, release
approval, milestone completion, or terminal completion.
`round-106` completed the narrow
`round-106-turn-classifier-common-appserverclient-import-convergence` slice at
merged commit `604202e` under direction 010. It moved only
`src/CodexWatcher/Turn/Classifier/Common.hs` from importing
`CodexWatcher.AppServerClient` to importing direct owner
`CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
Classifier logic, exports, status normalization, structured-output parsing,
missing-output behavior, endpoint/session/protocol behavior, package
descriptors, public facade exposure, docs, fixtures, tests, and other
`CodexWatcher.AppServerClient` importers were unchanged. Validation passed
with `cabal test watcher-core-test`, `cabal build all`, import scans,
descriptor/facade diff check, `git diff --check`, and
`git diff --cached --check`. This status records one narrow production
direct-owner import convergence and does not approve public deprecation or
removal, Cabal exposure removal, package descriptor cleanup, behavior changes
beyond the import move, release approval, milestone completion, or terminal
completion.
`round-107` completed the narrow
`round-107-issue-planning-turn-classifier-appserverclient-import-convergence`
slice at merged commit `50f7ae6` under direction 010. It moved only
`src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` from importing
`CodexWatcher.AppServerClient` to importing direct owner
`CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. Issue-planning
classification behavior, `classifyIssuePlanningTurn`,
`classifyTurnCompletion`, missing-output blocking, issue/subissue request
parsing, planning graph parsing, invalid payload classification, and
structured blocked/incomplete/complete classification were unchanged.
Validation passed with target import scans, `cabal test watcher-core-test`,
`cabal build all`, descriptor/facade diff check, no `worker-plan.json`,
`git diff --check`, `git diff --cached --check`, and `jq` validation of state
and review-record. This status records one narrow production direct-owner
import convergence and does not approve public facade removal or deprecation,
Cabal exposure removal, package descriptor cleanup, docs, fixtures, tests,
protocol changes, other importer migration, release approval, milestone
completion, or terminal completion. `CodexWatcher.AppServerClient` remains
available and unchanged as a public facade.
`round-108` completed the narrow
`round-108-issue-implement-turn-classifier-appserverclient-import-convergence`
slice at merged commit `e0db27d` under direction 010. It moved only
`src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` from importing
`CodexWatcher.AppServerClient` to importing direct owner
`CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. Issue-implement
classifier exports, type signatures, parsing, classification logic,
`classifyIssuePlanTurn`, `classifyIssueImplementationTurn`,
`classifyIssueFinalReviewTurn`, `classifyTurnCompletion`, missing-output
blocking, structured blocked/incomplete/complete outcomes, expected-commit
validation, PR-number completion, reviewer-thread completion, malformed JSON
handling, and final-review clean/rework/blocked/incomplete cases were
unchanged. Validation passed with target import scans, classifier test
discovery, `cabal test watcher-core-test`, `cabal build all`,
descriptor/facade diff check, no `worker-plan.json`, `git diff --check`,
`git diff --cached --check`, and `jq` validation. This status records one
narrow production direct-owner import convergence and does not approve public
facade removal or deprecation, Cabal exposure removal, package descriptor
cleanup, docs, fixtures, tests, protocol changes, endpoint/session/timeout,
fallback, command, or failure-formatting changes, other importer migration,
release approval, milestone completion, or terminal completion.
`CodexWatcher.AppServerClient` remains available and unchanged as a public
facade.
`round-109` completed the narrow
`round-109-pr-review-turn-classifier-appserverclient-import-convergence`
slice at merged commit `b7c059f` under direction 010. It moved only
`src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` from importing
`CodexWatcher.AppServerClient` to importing direct owner
`CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. PR-review
classifier exports, type signatures, parsing, classification logic,
`classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`,
`classifyTurnCompletion`, missing-output blocking, structured worker
outcomes, reviewer-state JSON parsing, reviewed-commit validation, reviewer
prompt-version validation, prior/new findings status handling, LGTM handling,
solved/remaining review-thread handling, and incomplete/blocked reviewer
outcomes were unchanged. Validation passed with target import scans,
PR-review classifier test discovery, `cabal test watcher-core-test`,
`cabal build all`, descriptor/facade diff check, no `worker-plan.json`,
`git diff --check`, `git diff --cached --check`, and `jq` validation. This
status records one narrow production direct-owner import convergence and does
not approve public facade removal or deprecation, Cabal exposure removal,
package descriptor cleanup, docs, fixtures, tests, protocol changes,
endpoint/session/timeout/fallback, command, or failure-formatting changes,
other importer migration, release approval, milestone completion, or terminal
completion. `CodexWatcher.AppServerClient` remains available and unchanged as
a public facade. Milestone 003 remains in progress; current
`CodexWatcher.AppServerClient` source users remain in `RunnerGuard.hs`,
`Domain/PrReview/LaunchCli.hs`, `Domain/IssuePlanning/Loop.hs`,
`AutomaticLoop/Runner.hs`, `Healthcheck.hs`,
`Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`, and
`Cli/Command/IssueFanout.hs`, plus test-policy imports, and these are
higher-risk endpoint/session/timeout/fallback/command/failure-formatting or
test-policy surfaces. `round-110` completed the artifact-only
`round-110-runner-guard-appserverclient-gate-evidence` round at merged commit
`74f715b` under direction 010. The accepted evidence maps every
`src/CodexWatcher/RunnerGuard.hs` `CodexWatcher.AppServerClient` imported
symbol to direct owner modules and use sites, and evaluates gates for
repair-thread launch, `thread-name/set`, `turn/start`, request id progression,
active-thread read, thread-read materialization pending, `threadSystemError`,
latest-turn lookup, turn-completion classification, stale-turn decisions, and
`formatAppServerClientFailure` text. The recommendation is no later
RunnerGuard import-only split is safe yet until focused RunnerGuard active
app-server turn inspection coverage lands first. This status does not approve
migration, deprecation, public facade removal, Cabal exposure or package
cleanup, behavior change, source/test/docs/package changes, release approval,
milestone completion, or terminal completion. `CodexWatcher.AppServerClient`
remains public and unchanged. Milestone 003 remains in progress; current
`CodexWatcher.AppServerClient` source users remain in `RunnerGuard.hs` as
blocked by focused behavior coverage, `Domain/PrReview/LaunchCli.hs`,
`Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`, `Healthcheck.hs`,
`Cli/Command/AppServerProbe.hs`, `Cli/Command/Observe.hs`,
`Cli/Command/IssueFanout.hs`, plus test-policy imports.

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
  Status: completed by `round-097` at `04a675c`; use
  `orchestrator/rounds/round-097/facade-import-scan-refresh.md` as the current
  accepted selected-facade import and exposure inventory for later
  `AppServerClient`, `Core.Ids`, `Workflow.EventLog`, and
  `Workflow.Permission` convergence slices. This status is evidence only and
  does not approve import migration, Cabal exposure change, deprecation,
  removal, runtime compatibility cleanup, milestone completion, or terminal
  completion.

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
  Status: readiness evidence completed by `round-105` at `d145f79`. The
  reviewed artifact records live `CodexWatcher.AppServerClient` import counts
  of `src`: 12, `test`: 7, `app`: 0, `agent-workflow-core`: 0,
  `agent-workflow-codex`: 0, and `agent-workflow-github`: 0; confirms the
  facade remains a public compatibility reexport of
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`; confirms `moifold.cabal`
  still exposes the facade while `agent-workflow-codex` exposes the direct
  owner modules; and classifies all source/test importers with later gates for
  endpoint parsing, app-server protocol, session handling, command rendering,
  timeout, fallback, failure formatting, turn-classifier behavior, package
  descriptor/public API/docs/downstream/test-policy evidence, and any public
  surface cleanup. This status is artifact-only readiness evidence; it does
  not approve import migration, public deprecation or removal, Cabal exposure
  removal, package descriptor cleanup, behavior change, release approval,
  milestone completion, or terminal completion. `round-106` completed the
  `round-106-turn-classifier-common-appserverclient-import-convergence` slice
  at `604202e` by moving only
  `src/CodexWatcher/Turn/Classifier/Common.hs` from the compatibility facade
  to direct owner
  `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..))`.
  Classifier logic, exports, status normalization, structured-output parsing,
  missing-output behavior, endpoint/session/protocol behavior, package
  descriptors, public facade exposure, docs, fixtures, tests, and other
  `CodexWatcher.AppServerClient` importers were unchanged. Validation passed
  with `cabal test watcher-core-test`, `cabal build all`, import scans,
  descriptor/facade diff check, `git diff --check`, and
  `git diff --cached --check`. This status records only that narrow import
  move and does not approve public deprecation or removal, Cabal exposure
  removal, package descriptor cleanup, behavior changes beyond the import
  move, release approval, milestone completion, or terminal completion.
  `round-107` completed the
  `round-107-issue-planning-turn-classifier-appserverclient-import-convergence`
  slice at `50f7ae6` by moving only
  `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs` from the
  compatibility facade to direct owner
  `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
  Issue-planning classification behavior, `classifyIssuePlanningTurn`,
  `classifyTurnCompletion`, missing-output blocking, issue/subissue request
  parsing, planning graph parsing, invalid payload classification, and
  structured blocked/incomplete/complete classification were unchanged.
  Validation passed with target import scans, `cabal test watcher-core-test`,
  `cabal build all`, descriptor/facade diff check, no `worker-plan.json`,
  `git diff --check`, `git diff --cached --check`, and `jq` validation of
  state and review-record. This status records only that narrow import move
  and does not approve public facade removal or deprecation, Cabal exposure
  removal, package descriptor cleanup, docs, fixtures, tests, protocol
  changes, other importer migration, release approval, milestone completion,
  or terminal completion. `CodexWatcher.AppServerClient` remains available
  and unchanged as a public facade.
  `round-108` completed the
  `round-108-issue-implement-turn-classifier-appserverclient-import-convergence`
  slice at `e0db27d` by moving only
  `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` from the
  compatibility facade to direct owner
  `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.
  Issue-implement classifier exports, type signatures, parsing,
  classification logic, `classifyIssuePlanTurn`,
  `classifyIssueImplementationTurn`, `classifyIssueFinalReviewTurn`,
  `classifyTurnCompletion`, missing-output blocking, structured
  blocked/incomplete/complete outcomes, expected-commit validation, PR-number
  completion, reviewer-thread completion, malformed JSON handling, and
  final-review clean/rework/blocked/incomplete cases were unchanged.
  Validation passed with old target import scan no matches, direct-owner
  import scan found the selected import, classifier test discovery,
  `cabal test watcher-core-test`, `cabal build all`, descriptor/facade diff
  check, no `worker-plan.json`, `git diff --check`,
  `git diff --cached --check`, and `jq` validation. This status records only
  that narrow import move and does not approve public facade removal or
  deprecation, Cabal exposure removal, package descriptor cleanup, docs,
  fixtures, tests, protocol changes, endpoint/session/timeout/fallback,
  command, or failure-formatting changes, other importer migration, release
  approval, milestone completion, or terminal completion.
  `CodexWatcher.AppServerClient` remains available and unchanged as a public
  facade.
  `round-109` completed the
  `round-109-pr-review-turn-classifier-appserverclient-import-convergence`
  slice at `b7c059f` by moving only
  `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs` from the
  compatibility facade to direct owner
  `CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`. PR-review
  classifier exports, type signatures, parsing, classification logic,
  `classifyPrReviewWorkerTurn`, `classifyPrReviewReviewerTurn`,
  `classifyTurnCompletion`, missing-output blocking, structured worker
  outcomes, reviewer-state JSON parsing, reviewed-commit validation, reviewer
  prompt-version validation, prior/new findings status handling, LGTM
  handling, solved/remaining review-thread handling, and incomplete/blocked
  reviewer outcomes were unchanged. Validation passed with old target import
  scan no matches, direct-owner import scan found the selected import,
  PR-review classifier test discovery, `cabal test watcher-core-test`,
  `cabal build all`, descriptor/facade diff empty, no `worker-plan.json`,
  `git diff --check`, `git diff --cached --check`, and `jq` validation. This
  status records only that narrow import move and does not approve public
  facade removal or deprecation, Cabal exposure removal, package descriptor
  cleanup, docs, fixtures, tests, protocol changes,
  endpoint/session/timeout/fallback, command, or failure-formatting changes,
  other importer migration, release approval, milestone completion, or
  terminal completion. `CodexWatcher.AppServerClient` remains available and
  unchanged as a public facade. Direction 010 remains in progress: current
  source users remain in `RunnerGuard.hs`, `Domain/PrReview/LaunchCli.hs`,
  `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`,
  `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`,
  `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus
  test-policy imports, and those surfaces still require focused gates.
  `round-110` completed the artifact-only
  `round-110-runner-guard-appserverclient-gate-evidence` round at `74f715b`
  by mapping every `src/CodexWatcher/RunnerGuard.hs`
  `CodexWatcher.AppServerClient` imported symbol to direct owner modules and
  use sites, then evaluating gates for repair-thread launch,
  `thread-name/set`, `turn/start`, request id progression, active-thread
  read, thread-read materialization pending, `threadSystemError`,
  latest-turn lookup, turn-completion classification, stale-turn decisions,
  and `formatAppServerClientFailure` text. The accepted recommendation is
  that no later RunnerGuard import-only split is safe yet until focused
  RunnerGuard active app-server turn inspection coverage lands first. This
  status does not approve migration, deprecation, public facade removal,
  Cabal exposure or package cleanup, behavior change, source/test/docs/package
  changes, release approval, milestone completion, or terminal completion.
  `CodexWatcher.AppServerClient` remains public and unchanged. Direction 010
  remains in progress: current source users remain in `RunnerGuard.hs` as
  blocked by focused behavior coverage, `Domain/PrReview/LaunchCli.hs`,
  `Domain/IssuePlanning/Loop.hs`, `AutomaticLoop/Runner.hs`,
  `Healthcheck.hs`, `Cli/Command/AppServerProbe.hs`,
  `Cli/Command/Observe.hs`, and `Cli/Command/IssueFanout.hs`, plus
  test-policy imports.

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
  Status: in progress; `round-098` completed the
  `round-098-boundary-policy-github-ids-import-convergence` slice at
  `c223018` by moving only `test/BoundaryPolicySpec.hs` from
  `CodexWatcher.Core.Ids` to `CodexWatcher.Workflow.GitHub.Ids`. Assertions
  were preserved, `moifold.cabal` was unchanged, and validation passed with
  `cabal test watcher-core-test` plus `cabal build all`. Remaining work must
  still inventory and justify other direct-owner candidates and blockers.
  `round-099` completed the
  `round-099-workflow-execution-agent-id-import-convergence` slice at
  `08bd47a` by moving only `src/CodexWatcher/Workflow/Execution.hs` from
  `CodexWatcher.Core.Ids (RequestId)` to
  `CodexWatcher.Workflow.Agent.Ids (RequestId)`. Workflow execution behavior
  was preserved, `moifold.cabal` was unchanged, and validation passed with
  `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
  `git diff --cached --check`. `round-100` completed the
  `round-100-core-state-github-ids-import-convergence` slice at `080fed5` by
  moving only `src/CodexWatcher/Core/State.hs` from
  `CodexWatcher.Core.Ids (CommitSha, PrNumber)` to
  `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)`. Typed watcher
  state and completion-evidence behavior were preserved, package descriptors
  and public compatibility facade exposure were unchanged, and validation
  passed with `cabal test watcher-core-test`, `cabal build all`,
  `git diff --check`, and `git diff --cached --check`.
  `round-101` completed the
  `round-101-app-main-repo-name-import-convergence` slice at `93196cd` by
  moving only `app/Main.hs` from
  `CodexWatcher.Core.Ids (RepoName (unRepoName))` to
  `CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))`. CLI
  healthcheck option conversion was preserved, public compatibility facade
  exposure was unchanged, the only package descriptor change was the
  compile-proven executable-only `agent-workflow-github >=0.1 && <0.2`
  dependency for `executable moifold`, and validation passed with
  `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, and
  `git diff --cached --check`. `round-102` completed the
  `round-102-workflow-docs-migration-agent-ids-import-convergence` slice at
  `ead9081` by moving only `test/WorkflowDocsMigrationSpec.hs` from
  `CodexWatcher.Core.Ids` to
  `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))`. Existing
  docs-migration workflow behavior coverage and term-level id fixtures were
  preserved, package descriptors and public compatibility facade exposure were
  unchanged, and validation passed with `cabal test watcher-core-test`,
  `cabal build all`, `git diff --check`, and `git diff --cached --check`.
  `round-103` completed the artifact-only
  `round-103-core-ids-remaining-blocker-readiness` evidence round at
  `b2eee52`: live `CodexWatcher.Core.Ids` imports now stand at 39 total
  (`src`: 29, `test`: 10, `app`: 0, standalone packages: 0), all five prior
  safe single-domain candidates from rounds 098 through 102 now use direct
  owner imports, and the remaining importers are blocker-class production
  surfaces or test-policy evidence surfaces. The current single-domain queue
  for direction 011 is therefore closed; any later work should be split-import
  or bridge-readiness slices with focused parser/renderer, event-log/replay,
  prompt/loop-policy, runtime-compatibility, or test-policy evidence. Broader
  Core.Ids migration, broader production import convergence, package
  descriptor cleanup beyond the narrow executable dependency, Cabal exposure
  removal, public deprecation, facade removal, runtime compatibility cleanup,
  release approval, milestone completion, and terminal completion remain
  outside these completed slices.

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
  Status: completed by `round-104` at `073a5d6` as artifact-only readiness
  evidence. The reviewed artifact records live import counts for
  `CodexWatcher.Workflow.EventLog` as `src`: 2 and `test`: 8, and for
  `CodexWatcher.Workflow.Permission` as `test`: 7; both facades have
  `app`: 0 and standalone package candidate imports: 0. `moifold.cabal` still
  exposes both compatibility facades, and `agent-workflow-core` exposes the
  direct-owner modules `CodexWatcher.Workflow.Audit`,
  `CodexWatcher.Workflow.EventLog.Commit.Core`,
  `CodexWatcher.Workflow.EventLog.Core`,
  `CodexWatcher.Workflow.EventLog.File.Core`, and
  `CodexWatcher.Workflow.Permission.Core`. The evidence classifies mixed
  export surfaces, every live importer, and later gates; strongest later
  candidates include `src/CodexWatcher/Workflow/DocsMigration.hs` and
  `src/CodexWatcher/Daemon.hs`, both requiring focused behavior gates. This
  status is readiness evidence only and does not approve import migration,
  public deprecation or removal, Cabal exposure removal, package descriptor
  cleanup, runtime compatibility cleanup, release approval, milestone
  completion, or terminal completion.

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
