# Framework Kernel Migration Roadmap

Roadmap id: `2026-05-08-00-framework-kernel-migration`
Roadmap revision: `rev-001`
Roadmap style: `strategy-backlog`

## Goal

Finish the remaining migration from moifold's internal workflow extraction into
a stable reusable agent workflow framework, while keeping the current moifold
issue/PR workflows behaviorally unchanged.

## Alignment Summary

- Thesis: stabilize the reusable framework contract before publishing or
  broadly removing compatibility layers.
- Success criteria: reviewers can see a coherent `WorkflowSpec` contract,
  authoring DSL, event-log and transaction law surface, adapter ownership, and
  extraction readiness story backed by tests and source-scan guards.
- Non-goals: no package publishing yet; no event JSON schema changes; no golden
  log rewrites; no generic prompt runner; no moving concrete issue/PR lifecycle,
  daemon ownership, process execution, filesystem writes, healthcheck, or
  repair into core just to make package boundaries look cleaner.
- Chosen strategy: framework stabilization first. Work proceeds through
  spec/API consolidation, DSL proof, generic runtime-contract hardening,
  adapter API stabilization, and extraction readiness.
- Deferred alternatives: package extraction first and broad moifold cleanup
  first are deferred until the reusable contract is less leaky and better
  proven by laws and examples.
- Shared invariants: repo-wide compatibility and ownership promises live in
  `orchestrator/project-contract.md`.

## Outcome Boundaries

- In scope: stronger indexed workflow API work, law and parity tests, DSL
  ergonomics, generic event-log and transaction contracts, adapter package
  APIs, boundary scans, docs/API freeze, and extraction readiness artifacts.
- Out of scope: external package publication, renaming current event `type`
  fields, changing golden event logs, replacing moifold workflow ADTs with a
  generic schema, weakening classifier evidence, or deleting compatibility
  facades without local proof.

## Global Sequencing Rules

- Preserve behavior first, then simplify APIs.
- Prefer one narrow vertical slice plus DocsMigration parity before generalizing
  a contract.
- Keep concrete workflow policy in moifold unless imports and tests prove the
  moved surface is generic.
- Every behavior-affecting extraction must include focused tests before relying
  on the new abstraction.
- Used roadmap revisions are immutable; future semantic coordination changes
  should publish a new revision under this family.

## Parallel Lanes

- Default lane: serial, because spec shape, DSL contracts, and package
  boundaries overlap heavily.
- Potential later lane `docs-and-examples`: may run beside implementation only
  after the relevant API milestone is stable and the planner assigns disjoint
  write scopes.
- Potential later lane `adapter-boundary-tests`: may run beside docs-only work
  when it touches only package-boundary source scans and no shared API files.

## Milestones

### 1. [complete] Consolidate the WorkflowSpec Contract

Milestone id: `milestone-001-workflow-spec-contract`
Depends on: none
Intent: Resolve the current split between unindexed `WorkflowSpec` and
`IndexedWorkflowSpec` into a clearer public kernel contract without breaking
moifold compatibility.
Completion signal: core exposes a documented, tested workflow spec surface with
explicit existential boundaries, source/target labels, replay hooks,
permission hooks, terminal semantics, and compatibility adapters for the current
moifold and DocsMigration users.
Parallel lane: default serial
Coordination notes: This milestone should happen before major DSL or external
package work because it defines the contract those layers consume.
Progress: round 025 completed the initial spec inventory and law baseline in
`d07df4c` without changing runtime behavior, event codecs, golden fixtures,
public API shape, or roadmap coordination semantics. Round 026 completed the
first additive indexed compatibility bridge in `a4962d7`, migrating
DocsMigration and the representative PR-review checking adapter through the
bridge with focused parity/source-scan coverage and no event, fixture, daemon,
runtime, roadmap sequencing, or compatibility facade changes. Round 027
completed terminal and observation law hardening in `c964007`, adding
DocsMigration and PR-review checking assertions for indexed/unindexed
observation parity, planned-event/apply consistency, replay determinism,
terminal-state closure, and wrong-phase permission rejection without changing
runtime behavior, event codecs, golden fixtures, package boundaries, roadmap
sequencing, or compatibility facades. With directions 001, 002, and 003
complete, the milestone completion signal is satisfied for the current
documented and tested workflow spec surface.

Candidate directions:

- Direction id: `direction-001-spec-inventory-and-laws`
  Status: complete via round 025, merged as `d07df4c`.
  Summary: inventory current spec users, law tests, and compatibility adapters.
  Why it matters now: the previous roadmap proved indexed routing but left two
  spec surfaces that can drift.
  Preconditions: clean base branch after round 024.
  Parallel hints: serial with all other spec/API work.
  Boundary notes: do not change event codecs, golden fixtures, or live daemon
  routing.
  Extraction notes: guider should extract a read-heavy law/coverage round first
  if API gaps are not already obvious.

- Direction id: `direction-002-indexed-contract-unification`
  Status: complete via round 026, merged as `a4962d7`.
  Summary: introduce the next indexed contract shape or compatibility bridge
  that reduces duplication between `WorkflowSpec` and `IndexedWorkflowSpec`.
  Why it matters now: future package extraction needs one defensible kernel
  vocabulary.
  Preconditions: round 025 inventory/law baseline merged; remaining API gaps
  should be addressed additively against that baseline.
  Parallel hints: serial; touches core API and moifold adapters.
  Boundary notes: keep existing modules available as compatibility imports.
  Extraction notes: prefer an additive bridge and migration tests over a
  repo-wide rewrite in one round.

- Direction id: `direction-003-terminal-and-observation-laws`
  Status: complete via round 027, merged as `c964007`.
  Summary: harden laws for observation consistency, terminal closure, replay
  determinism, and permission soundness across at least one moifold workflow and
  DocsMigration.
  Why it matters now: the framework docs name these as spec obligations.
  Preconditions: current spec law inventory exists; the additive indexed bridge
  from round 026 is available for any helper/API assertions that build on the
  unified spec vocabulary.
  Parallel hints: can run after additive API shape is present.
  Boundary notes: tests should catch semantic drift without changing runtime
  behavior.
  Extraction notes: keep the first round focused on assertions and helper APIs.

### 2. [complete] Stabilize the Workflow DSL As Pure Planning Syntax

Milestone id: `milestone-002-workflow-dsl-stabilization`
Depends on: `milestone-001-workflow-spec-contract`
Intent: Make `WorkflowM`, `Transition`, `advance`, and effect emission useful
for real workflow authors while preserving dry-run and replay guarantees.
Completion signal: at least two transitions, including one non-PR
DocsMigration transition and one moifold transition, are expressed through the
DSL with equal event, state, effect, replay, permission, and dry-run behavior.
Parallel lane: default serial
Coordination notes: DSL work should not introduce `liftIO`; all mutation must
remain typed effects interpreted later.
Progress: round 028 completed the DSL core ergonomics and law slice in
`f3b2280`, adding a pure `failWorkflow` constructor plus focused
`watcher-core-test` coverage for `WorkflowM` effect ordering, failure
short-circuiting, phase-changing `advance`, and planned pre/post commit
projection parity for both moifold and DocsMigration specs. At that point, no
real DocsMigration or moifold transitions were ported yet, so the milestone
remained pending on direction 005. Round 029 completed the transition-port
proof in `15cd4e5`, routing the DocsMigration draft-produced transition and the
moifold issue-planning turn-completed projection through pure DSL helpers with
parity coverage for event, state, effect partitioning, replay, permissions,
action ordering, phase validation, and dry-run reporting. With directions 004
and 005 complete, the milestone completion signal is satisfied for the current
DSL authoring surface.

Candidate directions:

- Direction id: `direction-004-dsl-core-ergonomics`
  Status: complete via round 028, merged as `f3b2280`.
  Summary: tighten the writer-like DSL API and tests around effect
  accumulation, phase-changing `advance`, and post/pre commit projection.
  Why it matters now: the current DSL is intentionally minimal and needs law
  coverage before more transitions use it.
  Preconditions: spec contract direction has settled enough to avoid churn.
  Parallel hints: serial with transition ports.
  Boundary notes: avoid indexed-do complexity unless a round proves it is
  necessary.
  Extraction notes: one round should improve API shape and focused tests only.

- Direction id: `direction-005-dsl-transition-ports`
  Status: complete via round 029, merged as `15cd4e5`.
  Summary: port one DocsMigration transition and one moifold transition to DSL
  helpers while preserving parity.
  Why it matters now: the DSL should prove authoring value outside synthetic
  tests.
  Preconditions: DSL core helper tests pass.
  Parallel hints: DocsMigration and moifold ports may split only if write
  scopes are disjoint and planner authors `worker-plan.json`.
  Boundary notes: do not alter event schemas or effect ordering.
  Extraction notes: reviewer must compare old and DSL transition outputs.

### 3. [complete] Harden Generic Event-Log, Transaction, and Daemon Contracts

Milestone id: `milestone-003-core-runtime-contracts`
Depends on: `milestone-001-workflow-spec-contract`
Intent: Move only genuinely generic runtime contract shapes into
`agent-workflow-core` while keeping moifold process ownership and lifecycle
policy in the main library.
Completion signal: core transaction and daemon types cover replay, commit,
audit, failure classification, dry-run, and action partitioning for moifold and
DocsMigration without importing concrete moifold lifecycle modules.
Parallel lane: default serial
Coordination notes: this milestone may overlap conceptually with DSL work, but
implementation should remain serial unless planner proves non-overlap.
Progress: round 030 completed the transaction-law coverage slice in `7b0b105`,
adding focused `watcher-core-test` coverage for generic transaction failure
stages, commit-boundary audit labels, retry/stop recommendations, pre/post
action partitioning, and dry-run versus execute parity. It also tightened the
moifold and DocsMigration transaction path tests without changing production
code, event schemas, golden fixtures, package ownership, adapter APIs,
compatibility facades, roadmap sequencing, or concrete daemon/runtime
ownership. Round 031 completed the daemon-core boundary slice in `f36a9cc`,
adding an ownership-neutral daemon failure projection to
`agent-workflow-core`, routing the moifold compatibility wrapper through it,
and strengthening focused daemon projection tests plus recursive source scans
that keep child-daemon lifecycle, runtime ownership, filesystem/process
behavior, healthcheck, repair, and concrete watcher event/state policy in
moifold. With directions 006 and 007 complete, the milestone completion signal
is satisfied for the current generic runtime-contract surface.

Candidate directions:

- Direction id: `direction-006-transaction-law-coverage`
  Status: complete via round 030, merged as `7b0b105`.
  Summary: add law and parity tests for transaction failure stages, commit
  boundaries, audit reports, and retryability.
  Why it matters now: event-log and transaction semantics are central framework
  guarantees.
  Preconditions: current transaction core remains additive and buildable.
  Parallel hints: can run after spec inventory; avoid touching DSL files.
  Boundary notes: do not move filesystem writes or process execution into core.
  Extraction notes: include both dry-run and execute-mode fake interpreters.

- Direction id: `direction-007-daemon-core-boundary`
  Status: complete via round 031, merged as `f36a9cc`.
  Summary: identify any reusable daemon tick result or ownership-neutral
  surface that can move to core, and leave concrete child ownership in moifold.
  Why it matters now: the framework docs call for daemon contracts, but round
  024 proved child lifecycle must stay concrete for now.
  Preconditions: transaction law tests cover current behavior.
  Parallel hints: serial with transaction API changes.
  Boundary notes: core must not import `ChildDaemon`, healthcheck, repair, PID,
  lock, runtime-owner, or concrete `WatcherEvent`.
  Extraction notes: source scans are mandatory for every extraction round.

### 4. [complete] Stabilize Codex and GitHub Adapter Package APIs

Milestone id: `milestone-004-adapter-api-stabilization`
Depends on: `milestone-001-workflow-spec-contract`
Intent: Make adapter sublibraries usable as framework layers without leaking
moifold issue/PR lifecycle policy back into adapter packages.
Completion signal: Codex and GitHub adapter APIs have documented ownership,
focused tests, and recursive boundary checks; moifold compatibility reexports
are either still justified or locally removed with proof.
Parallel lane: `adapter-boundary-tests`
Coordination notes: this milestone can be split into Codex and GitHub lanes
only after a planner confirms disjoint write scopes.
Progress: round 032 completed the Codex adapter API stabilization slice in
`2f33153`, adding the typed `agentTurnStartRef` helper, app-server malformed
thread/turn start parser checks, typed turn-reference request coverage, and
stronger recursive boundary scans that keep moifold issue/PR lifecycle policy
out of `agent-workflow-codex`. Round 033 completed the GitHub adapter API
stabilization slice in `ae34398`, adding stable ordering for adapter-owned
GitHub identifiers, adapter-owned GitHub/PR/check field lists and command
rendering parity, merged-PR metadata classification shared by healthcheck, and
focused parser plus recursive boundary coverage that keeps moifold lifecycle,
daemon, runtime, healthcheck, repair, app-server, and compatibility policy out
of `agent-workflow-github`. With directions 008 and 009 complete, the milestone
completion signal is satisfied for the current adapter API surface.

Candidate directions:

- Direction id: `direction-008-codex-agent-adapter-api`
  Status: complete via round 032, merged as `2f33153`.
  Summary: stabilize typed agent roles, turn refs, protocol clients,
  classifiers, and transport-facing helpers in `agent-workflow-codex`.
  Why it matters now: app-server JSON-RPC details should stay outside workflow
  policy.
  Preconditions: no active spec API churn in the same files.
  Parallel hints: may run beside GitHub adapter work if write scopes are
  separate.
  Boundary notes: do not weaken classifier evidence or structured-output field
  requirements.
  Extraction notes: include classifier and protocol tests for complete,
  incomplete, blocked, malformed, problems, and clean outputs when touched.

- Direction id: `direction-009-github-adapter-api`
  Status: complete via round 033, merged as `ae34398`.
  Summary: stabilize GitHub ids, remote metadata parsing, and command rendering
  helpers in `agent-workflow-github`.
  Why it matters now: GitHub assumptions must stay explicit adapter code, not
  hidden core concepts.
  Preconditions: no overlapping command-rendering refactor in moifold.
  Parallel hints: may run beside Codex adapter work if planner assigns separate
  ownership.
  Boundary notes: no imports from moifold state machine, daemon, or lifecycle
  modules.
  Extraction notes: preserve command rendering and healthcheck/parser parity.

### 5. [complete] Prepare External Extraction Readiness

Milestone id: `milestone-005-extraction-readiness`
Depends on: `milestone-002-workflow-dsl-stabilization`,
`milestone-003-core-runtime-contracts`,
`milestone-004-adapter-api-stabilization`
Intent: Convert the stabilized internal libraries and docs into an
extraction-ready package boundary without publishing packages yet.
Completion signal: the repo has an API/readiness report, package-boundary
checklist, example workflows, compatibility-deprecation map, and validation
commands showing that `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github` could be separated without pulling moifold policy into
them.
Parallel lane: `docs-and-examples`
Coordination notes: this is intentionally last; do not run package publishing
or remove broad compatibility wrappers before the readiness report is reviewed.
Progress: round 034 completed the API-freeze documentation slice in `11692a5`,
adding the implemented internal API-freeze page and aligning framework docs for
`WorkflowSpec`, the pure DSL, event-log/transaction contracts, the Codex
adapter, and the GitHub adapter with the current source-backed surfaces. The
docs explicitly keep moifold issue/PR lifecycle policy, runtime ownership,
healthcheck, repair, compatibility files, publication, and deprecation policy
outside the reusable framework contract. Round 035 completed
`direction-011-package-readiness-report` in `61e6a2b`, adding a source-backed
package extraction readiness report and README link that record package
verdicts, import-graph and negative-edge evidence, Cabal dependency ownership,
recursive package-boundary checklist coverage, compatibility-facade and
deprecation-readiness mapping, remaining moifold-owned blockers, and validation
commands. The report also confirms no Cabal, test, source, event-schema,
golden-fixture, publication, or compatibility-facade cleanup was required. With
directions 010 and 011 complete, and the existing DSL/spec docs plus
DocsMigration and moifold parity tests serving as current example-workflow
evidence, the milestone completion signal is satisfied without changing
roadmap sequencing or package publication policy.

Candidate directions:

- Direction id: `direction-010-api-freeze-and-docs`
  Status: complete via round 034, merged as `11692a5`.
  Summary: align framework docs with the implemented API and document the
  stable contract versus remaining moifold-owned surfaces.
  Why it matters now: docs should become an API contract only after the code
  shape is proven.
  Preconditions: preceding API and adapter milestones complete.
  Parallel hints: docs-only work may run beside final boundary scans.
  Boundary notes: keep docs thesis-first and avoid marketing-style feature
  lists.
  Extraction notes: include links from README/correctness docs only if they
  improve navigation.

- Direction id: `direction-011-package-readiness-report`
  Status: complete via round 035, merged as `61e6a2b`.
  Summary: produce a concrete extraction readiness report and any required
  Cabal/package-boundary cleanup.
  Why it matters now: publishing should follow a checklist, not optimism.
  Preconditions: API freeze direction complete or explicitly scoped.
  Parallel hints: serial if it edits Cabal or public module exports.
  Boundary notes: no external release or package publication in this roadmap.
  Extraction notes: include import graphs, dependency ownership, compatibility
  facades, and remaining blockers.
