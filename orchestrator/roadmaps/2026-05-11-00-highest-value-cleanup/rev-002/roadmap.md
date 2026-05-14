# Highest-Value Cleanup Roadmap

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-002`
Roadmap style: `strategy-backlog`

## Goal

Make the repository easier to evolve by landing concrete cleanup in a sequenced
way: preserve the test evidence base, finish finite import burndowns, split
remaining bridge/facade use where safe, then perform only exact approved public
surface and runtime compatibility cleanup.

## Alignment Summary

- Thesis: cleanup should reduce future risk while still moving toward removal.
  Evidence gates exist to make removal safe; they are not a substitute for
  migration work when a concrete migration is already lawful.
- Outcome: import convergence is split into finite milestone queues so the
  controller can close production import work, test/fixture import work,
  bridge/facade work, and public surface cleanup independently.
- Success criteria: each compatibility surface is either migrated away from a
  supported compatibility path or reaches an exact reviewed removal/migration
  decision. No kept, deferred, blocked, or hold-only set can be treated as
  final success for this family.
- Non-goals: no casual removal of `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, or
  `CodexWatcher.Workflow.Permission`; no compatibility-file rename or deletion
  before fixture and behavior evidence; no event JSON `type` migration; no
  release or publication approval.
- Revision reason: rev-002 replaces the overloaded rev-001 milestone 003 with
  smaller milestones that have finite completion signals. This is a future
  coordination change, not a status-only update.

## Outcome Boundaries

In scope:

- Remaining production `CodexWatcher.Core.Ids` imports under `src/`, excluding
  the public compatibility facade module itself.
- Remaining test and fixture `CodexWatcher.Core.Ids` imports under `test/`.
- Remaining concrete `CodexWatcher.Workflow.EventLog` and
  `CodexWatcher.Workflow.Permission` bridge/facade uses that can be migrated or
  classified without public API cleanup.
- `CodexWatcher.AppServerClient` public facade, Cabal exposure, docs, and
  policy cleanup after direct imports are gone.
- Existing large-module, runtime compatibility, and final removal work from
  rev-001, renumbered after the split import milestones.

Out of scope:

- Package upload, public release, or external publication decisions.
- Removing compatibility facades solely because direct imports exist.
- Removing or renaming compatibility state files solely because production code
  has few local readers.
- Moving concrete moifold lifecycle policy into reusable packages.
- Editing prior used roadmap revisions.

## Global Sequencing Rules

- Split remaining import convergence by surface and risk, not by readiness
  gate alone.
- Production `Core.Ids` imports are handled before test/fixture `Core.Ids`
  imports unless a selected test slice is required as immediate behavior
  evidence for a production migration.
- A milestone may close when every remaining user in its scope is either
  migrated or explicitly classified as a blocker, public-compat surface,
  runtime-compat surface, or policy-evidence surface with reviewer-approved
  reasons.
- Preferred imports, empty local source scans, or successful local validation
  are not public deprecation or removal approval.
- Public compatibility facades and Cabal exposed-module entries remain exposed
  until exact public-surface cleanup directions approve a change.
- Runtime compatibility files keep current names and meanings until fixture,
  healthcheck, repair, write-timing, operator/downstream, and behavior evidence
  approves an exact migration or removal.
- Before terminal closeout, inspect merged evidence for newly discovered
  cleanup fronts. If more cleanup is justified, refine the roadmap through a
  reviewed update or new revision instead of marking the family done.
- Preserve `orchestrator/project-contract.md` invariants for event schemas,
  golden fixtures, compatibility files, dry-run rendering, package ownership,
  runtime ownership, healthcheck, repair, and public facade availability.

## Parallel Lanes

Default execution remains serial with `max_parallel_rounds: 1`.

Candidate lanes after explicit controller authorization:

- Production Core.Ids lane: one production file or tightly coupled family per
  round.
- Test Core.Ids lane: test/fixture imports after production classification, or
  earlier only as direct evidence for a production slice.
- Bridge/facade lane: `Workflow.EventLog`, `Workflow.Permission`, and
  AppServerClient public-surface decisions, kept separate from production
  Core.Ids work.
- Large-module split lane: one module family at a time unless planner evidence
  proves disjoint ownership.

Deprecation/removal remains serial because public API, Cabal exposure, docs,
and downstream evidence must be reviewed per exact surface.

## Milestones

### 1. [completed] Test Topology And Cleanup Inventory

Milestone id: `milestone-001-test-topology-inventory`
Depends on: none
Intent: Make the cleanup evidence base navigable by inventorying facade,
fixture, package-boundary, and large-module risks, then extracting the
highest-value reusable test helpers out of `test/Main.hs`.
Completion signal: focused test modules own reusable package-boundary scanners,
facade/import-policy checks, and workflow behavior coverage; `test/Main.hs` is
measurably smaller; the test-suite wiring still reaches moved behavior tests.
Parallel lane: complete
Coordination notes: Completed detail lives in rev-001 and round artifacts.
Current status: completed by rounds 083 through 086; see
`roadmap-history.md` and the round artifacts for detailed evidence.

Candidate directions:

- Direction id: `direction-001-through-004-test-topology-completed`
  Summary: Completed cleanup inventory and focused test-module splits from
  rev-001.
  Why it matters now: this is the evidence base for the remaining cleanup.
  Preconditions: none; completed.
  Parallel hints: none; completed.
  Boundary notes: does not approve production import convergence, public
  deprecation, facade removal, Cabal exposure removal, runtime
  compatibility-file removal, or compatibility-file rename/deletion.
  Extraction notes: no further extraction from this completed milestone.

### 2. [completed] Compatibility Fixtures And Runtime-State Contracts

Milestone id: `milestone-002-compatibility-fixtures-contracts`
Depends on: `milestone-001-test-topology-inventory`
Intent: Add the selected fixture and healthcheck evidence needed before later
runtime compatibility cleanup and keep state-file semantics explicit.
Completion signal: selected runtime-state fixture slices and the
`planner-state.json` versus `planning-state.json` contract have reviewed
evidence; runtime compatibility migration/removal decisions are deferred to the
dedicated runtime cleanup milestone.
Parallel lane: complete
Coordination notes: Remaining runtime compatibility decisions now belong to
`milestone-008-runtime-compatibility-cleanup-gates`, not to import burndown.
Current status: completed for the selected fixture and contract evidence by
rounds 087 through 096; see `roadmap-history.md` and the round artifacts for
detailed evidence. This does not approve runtime compatibility-file deletion,
rename, migration, healthcheck behavior changes, repair behavior changes,
release approval, terminal completion, or public compatibility removal.

Candidate directions:

- Direction id: `direction-005-through-008-runtime-contracts-completed`
  Summary: Completed selected fixture, planner/planning contract, and
  healthcheck read/non-read evidence from rev-001.
  Why it matters now: later runtime cleanup must build on these contracts
  rather than reopening fixture inventory as an import-burndown blocker.
  Preconditions: none; completed.
  Parallel hints: none; completed.
  Boundary notes: runtime cleanup decisions remain pending in milestone 008.
  Extraction notes: no further extraction from this completed milestone.

### 3. [completed] Core.Ids Production Import Burndown

Milestone id: `milestone-003-core-ids-production-import-burndown`
Depends on: `milestone-001-test-topology-inventory`
Intent: Finish safe production `CodexWatcher.Core.Ids` direct-owner
split-imports while keeping the public `Core.Ids` compatibility facade exposed.
Completion signal: every safe production direct-owner candidate has been
migrated, and every remaining production `Core.Ids` user is explicitly
classified as a blocker, public-compat surface, or runtime-compat surface with
reviewer-approved reasons. A source scan must separate migrated production
files from `src/CodexWatcher/Core/Ids.hs`, docs, Cabal exposure, and tests.
Parallel lane: production Core.Ids lane
Coordination notes: this milestone is about production imports only. It does
not include test/fixture imports, public facade removal, Cabal exposure cleanup,
docs cleanup, or runtime compatibility-file cleanup.
Current status: completed by rounds 098 through 103 and 152 through 186.
Latest evidence: round 186 migrated
`src/CodexWatcher/Domain/IssueImplement/Loop.hs` from
`CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber)` imports. The reviewer approved the import-only diff after
`cabal build all`, full `cabal test watcher-core-test`, `git diff --check`,
selected-file no-`Core.Ids` scan, selected-file direct-owner scan, broad
remaining `Core.Ids` classification, and focused issue-implementation behavior
evidence all passed. The broad scan found no remaining production `Core.Ids`
users under `src/` beyond `src/CodexWatcher/Core/Ids.hs`, the public
compatibility facade. Remaining matches are tests/fixtures, docs, and Cabal
exposure outside this milestone. This status does not approve public facade
deprecation/removal, Cabal exposure cleanup, docs cleanup, runtime
compatibility cleanup, release approval, terminal completion, or public
compatibility removal.

Candidate directions:

- Direction id: `direction-011a-core-ids-eventlog-types-production-import`
  Summary: Move `src/CodexWatcher/EventLog/Types.hs` from the combined
  `Core.Ids` facade to direct GitHub and agent id owners.
  Why it matters now: event constructors and codecs are central compatibility
  surfaces, and this file is a high-value remaining production user.
  Preconditions: golden replay, old-log parsing, event JSON `type` stability,
  and watcher-core event-log coverage must be selected for the touched ids.
  Parallel hints: serial with golden replay and runtime compatibility work.
  Boundary notes: no event constructor, codec, schema-version, metadata label,
  JSON field, or export change.
  Extraction notes: completed by round 182 as an import-only direct-owner
  migration. Keep this as status evidence only; it does not approve event
  behavior edits, fixture edits, public facade deprecation/removal, Cabal
  cleanup, docs cleanup, runtime compatibility cleanup, release approval,
  milestone completion, terminal completion, or public compatibility removal.

- Direction id: `direction-011b-core-ids-golden-replay-production-import`
  Summary: Move `src/CodexWatcher/GoldenReplay.hs` from `Core.Ids` to direct id
  owners.
  Why it matters now: golden replay is compatibility evidence for later event
  and runtime cleanup, so its imports should be explicit before removal gates.
  Preconditions: focused golden replay and snapshot normalization validation.
  Parallel hints: serial with EventLog.Types and runtime compatibility work.
  Boundary notes: no snapshot normalization, replay warning, bootstrap event,
  or old fixture behavior change.
  Extraction notes: completed by round 178 as an import-only direct-owner
  migration. Keep this as status evidence only; it does not approve replay
  behavior edits, fixture edits, public facade deprecation/removal, Cabal
  cleanup, docs cleanup, runtime compatibility cleanup, release approval,
  milestone completion, terminal completion, or public compatibility removal.

- Direction id: `direction-011c-core-ids-runtime-compatibility-production-classification`
  Summary: Migrate or classify `src/CodexWatcher/Runtime/Compatibility.hs`
  after proving compatibility-write behavior stays stable.
  Why it matters now: runtime compatibility writes are a removal gate, not a
  reason to leave import work unbounded.
  Preconditions: selected fixture parity for touched writer branches and
  current compatibility file names.
  Parallel hints: serial with healthcheck and runtime cleanup milestones.
  Boundary notes: no compatibility file deletion, rename, write timing change,
  JSON shape migration, or repair/healthcheck behavior change.
  Extraction notes: completed by round 183 as an import-only direct-owner
  migration. Keep this as status evidence only; it does not approve
  compatibility file deletion or rename, write timing changes, JSON shape
  migration, repair behavior changes, healthcheck behavior changes, public
  facade deprecation/removal, Cabal cleanup, docs cleanup, runtime
  compatibility cleanup, release approval, milestone completion, terminal
  completion, or public compatibility removal.

- Direction id: `direction-011d-core-ids-healthcheck-production-import`
  Summary: Move or classify the remaining `src/CodexWatcher/Healthcheck.hs`
  `Core.Ids` import.
  Why it matters now: healthcheck is an operator-facing reader and a remaining
  production user with clear direct owner modules.
  Preconditions: focused healthcheck parsing/rendering and runtime-state
  reader evidence for touched ids.
  Parallel hints: serial with runtime compatibility work.
  Boundary notes: no healthcheck JSON shape, summary path, reader set, command
  rendering, or app-server behavior change.
  Extraction notes: completed by round 184 as an import-only direct-owner
  migration. Keep this as status evidence only; it does not approve
  healthcheck behavior edits, runtime compatibility-file deletion or rename,
  repair behavior changes, public facade deprecation/removal, Cabal cleanup,
  docs cleanup, runtime compatibility cleanup, release approval, milestone
  completion, terminal completion, or public compatibility removal.

- Direction id: `direction-011e-core-ids-domain-loop-production-imports`
  Summary: Split `Core.Ids` imports in
  `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` and
  `src/CodexWatcher/Domain/IssueImplement/Loop.hs`.
  Why it matters now: the loops are high-traffic runtime behavior but their id
  ownership can still be explicit once request/thread/repo ids are separated.
  Preconditions: focused planning/implementation loop tests or existing
  watcher-core behavior evidence for request-id threading, thread/turn ids,
  repo/issue/PR rendering, and failure text.
  Parallel hints: one loop per round unless the planner proves disjoint
  behavior and verification.
  Boundary notes: no daemon-loop state transition, event append order,
  app-server turn classification, request-id progression, or command rendering
  change.
  Extraction notes: `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` was
  completed by round 185 as an import-only direct-owner migration.
  `src/CodexWatcher/Domain/IssueImplement/Loop.hs` was completed by round 186
  as an import-only direct-owner migration. Direction-011e domain-loop
  production imports are complete. This does not approve public facade
  deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility
  cleanup, release approval, terminal completion, or public compatibility
  removal.

- Direction id: `direction-011f-core-ids-cli-production-imports`
  Summary: Split `Core.Ids` imports in CLI parser/types/fanout modules:
  `src/CodexWatcher/Cli/Parser/Common.hs`, `src/CodexWatcher/Cli/Types.hs`,
  and `src/CodexWatcher/Cli/Command/IssueFanout.hs`.
  Why it matters now: CLI parsing and child-launch rendering are concrete
  user-facing surfaces and a finite remaining production import set.
  Preconditions: focused parser/rendering checks for repo, issue, review
  thread, thread, turn, branch, and request ids as applicable.
  Parallel hints: one CLI file per round by default.
  Boundary notes: no option name, parser error, dry-run text, fanout manifest,
  child args, or runtime command behavior change.
  Extraction notes: direct-owner import movement only; add a package
  dependency only if the compiler proves the target needs it.
  `src/CodexWatcher/Cli/Parser/Common.hs` was completed by round 179 as an
  import-only direct-owner migration. `src/CodexWatcher/Cli/Types.hs` was
  completed by round 180 as an import-only direct-owner migration.
  `src/CodexWatcher/Cli/Command/IssueFanout.hs` was completed by round 181 as
  an import-only direct-owner migration. Direction-011f CLI production imports
  are now complete for Parser/Common, Cli/Types, and IssueFanout. This does
  not approve public facade deprecation/removal, Cabal cleanup, docs cleanup,
  runtime compatibility cleanup, release approval, milestone completion,
  terminal completion, or public compatibility removal.

- Direction id: `direction-011g-core-ids-production-closeout-classification`
  Summary: Close the production Core.Ids burndown by scanning and classifying
  any remaining production users.
  Why it matters now: milestone 003 needs a finite closeout that does not wait
  for test, docs, Cabal, or public removal work.
  Preconditions: all safe production migration slices above have either landed
  or been reviewed as blocked.
  Parallel hints: artifact-only evidence round is acceptable when changed paths
  are roadmap artifacts only.
  Boundary notes: no production code, public facade, Cabal, docs, or runtime
  compatibility-file change unless selected separately.
  Extraction notes: round 186 reviewer evidence supplied the closeout
  production scan/classification: no remaining production `Core.Ids` users
  under `src/` beyond `src/CodexWatcher/Core/Ids.hs`, the public compatibility
  facade. Remaining matches are tests/fixtures, docs, and Cabal exposure
  outside milestone 003. A separate artifact-only closeout round is not needed
  for milestone 003, but this does not approve public facade
  deprecation/removal, Cabal cleanup, docs cleanup, runtime compatibility
  cleanup, release approval, terminal completion, or public compatibility
  removal.

### 4. [in-progress] Core.Ids Test And Fixture Import Burndown

Milestone id: `milestone-004-core-ids-test-and-fixture-import-burndown`
Depends on: `milestone-003-core-ids-production-import-burndown`
Intent: Migrate safe test/fixture `CodexWatcher.Core.Ids` users or classify
them as policy evidence surfaces after production users are resolved.
Completion signal: every safe test/fixture `Core.Ids` import has migrated to
direct owners, and every remaining test import is explicitly classified as a
policy, parity, or compatibility-facade evidence owner with reviewer-approved
reasons.
Parallel lane: test Core.Ids lane
Coordination notes: test policy surfaces may intentionally import facades, but
that classification must be explicit and finite.
Current status: in progress. Round 187 migrated
`test/TestSupport/Workflow.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, TurnId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. Round 188 migrated
`test/WorkflowEventLogSpec.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. Round 189 migrated
`test/WorkflowAgentSpec.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, TurnId, nextRequestId)`
and `CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. Round 190 migrated
`test/WorkflowExecutionSpec.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. Round 191 migrated
`test/WorkflowIndexedSpec.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (RequestId, ThreadId, TurnId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. Round 192 migrated
`test/CliSpec.hs` from `CodexWatcher.Core.Ids` to direct
`CodexWatcher.Workflow.Agent.Ids (ThreadId)` and
`CodexWatcher.Workflow.GitHub.Ids (IssueNumber, RepoName)` imports. The
reviewer approved the round-192 import-only diff after `cabal build all`,
`cabal test watcher-core-test`, git diff checks, selected-file no-`Core.Ids`
scan, selected-file direct-owner imports, selected-file diff inspection,
aggregate-wiring scan, and broad remaining-user classification all passed.
Direction 011h workflow test imports are complete: no workflow spec remains on
`CodexWatcher.Core.Ids`. The
`direction-011i-cli-spec-core-ids-import` extracted item is complete.
Round 193 migrated `test/RuntimeSpec.hs` from `CodexWatcher.Core.Ids` to
direct `CodexWatcher.Workflow.Agent.Ids (ThreadId)` and
`CodexWatcher.Workflow.GitHub.Ids (BranchName, CommitSha, IssueNumber,
PrNumber, RepoName, ReviewThreadId)` imports. The reviewer approved the
round-193 import-only diff after `cabal build all`,
`cabal test watcher-core-test`, git diff checks, selected-file no-`Core.Ids`
scan, selected-file direct-owner imports, selected-file diff inspection,
aggregate-wiring scan, and broad remaining-user classification all passed. The
`direction-011i-runtime-spec-core-ids-import` extracted item is complete.
Remaining `Core.Ids` test users are the runtime compatibility fixture test
(`test/RuntimeCompatibilityFixtureSpec.hs`) and policy/aggregator candidates
(`test/FacadeImportPolicySpec.hs`, `test/Main.hs`). No app, reusable package,
or production `src` users remain beyond the public facade module. Docs, Cabal
exposure, and the public facade remain for later milestones or public-surface
decisions. This status does not approve public facade deprecation/removal,
Cabal exposure cleanup, docs cleanup, runtime compatibility cleanup, milestone
004 completion, release approval, terminal completion, or public compatibility
removal.

Candidate directions:

- Direction id: `direction-011h-core-ids-workflow-test-imports`
  Summary: Migrate safe workflow test imports in files such as
  `test/WorkflowAgentSpec.hs`, `test/WorkflowEventLogSpec.hs`,
  `test/WorkflowExecutionSpec.hs`, `test/WorkflowIndexedSpec.hs`, and
  `test/TestSupport/Workflow.hs`.
  Why it matters now: once production users are resolved, workflow tests should
  either follow direct owners or be classified as policy evidence.
  Preconditions: production classification from milestone 003.
  Parallel hints: one test family per round.
  Boundary notes: preserve assertions, fixtures, PASS labels, and aggregate
  wiring.
  Extraction notes: direct-owner import split only unless a test helper move is
  explicitly selected. `test/TestSupport/Workflow.hs` was completed by round
  187 as an import-only direct-owner migration. `test/WorkflowEventLogSpec.hs`
  was completed by round 188 as an import-only direct-owner migration.
  `test/WorkflowAgentSpec.hs` was completed by round 189 as an import-only
  direct-owner migration. `test/WorkflowExecutionSpec.hs` was completed by
  round 190 as an import-only direct-owner migration.
  `test/WorkflowIndexedSpec.hs` was completed by round 191 as an import-only
  direct-owner migration. Direction 011h workflow test imports are complete;
  continue milestone 004 with direction 011i runtime/CLI tests and direction
  011j policy/aggregator classification.

- Direction id: `direction-011i-core-ids-runtime-cli-test-imports`
  Summary: Migrate safe runtime and CLI test imports such as
  `test/RuntimeSpec.hs`, `test/RuntimeCompatibilityFixtureSpec.hs`, and
  `test/CliSpec.hs`.
  Why it matters now: runtime and CLI tests should mirror the production
  ownership split after the production queue closes.
  Preconditions: relevant production runtime/CLI users migrated or classified.
  Parallel hints: one behavior area per round.
  Boundary notes: preserve fixture JSON, parser/rendering expectations, and
  runtime behavior assertions.
  Extraction notes: keep fixture data unchanged unless selected by a runtime
  compatibility milestone. `test/CliSpec.hs` was completed by round 192 as an
  import-only direct-owner migration; this completed extracted item is
  `direction-011i-cli-spec-core-ids-import`. `test/RuntimeSpec.hs` was
  completed by round 193 as an import-only direct-owner migration; this
  completed extracted item is `direction-011i-runtime-spec-core-ids-import`.
  Continue direction 011i with `test/RuntimeCompatibilityFixtureSpec.hs` if it
  still imports `CodexWatcher.Core.Ids`.

- Direction id: `direction-011j-core-ids-policy-and-aggregator-classification`
  Summary: Classify remaining facade-policy or aggregation imports such as
  `test/FacadeImportPolicySpec.hs` and `test/Main.hs`.
  Why it matters now: intentional policy evidence should not keep the import
  burndown milestone open forever.
  Preconditions: safe test migrations have run.
  Parallel hints: artifact-only or narrow test-only round.
  Boundary notes: no public facade removal or policy weakening.
  Extraction notes: record exact intentional facade users and why each remains.

### 5. [pending] EventLog And Permission Bridge Burndown

Milestone id: `milestone-005-eventlog-permission-bridge-burndown`
Depends on: `milestone-001-test-topology-inventory`
Intent: Split or classify remaining `Workflow.EventLog` and
`Workflow.Permission` bridge/facade uses where safe, using the direction 012
evidence as a starting point.
Completion signal: concrete code/test imports that can move to
`Workflow.EventLog.Core`, `Workflow.EventLog.File.Core`,
`Workflow.EventLog.Commit.Core`, `Workflow.Audit`, or
`Workflow.Permission.Core` have moved; any remaining facade import is named as
public-compat, policy-parity, or bridge behavior with reasons.
Parallel lane: bridge/facade lane
Coordination notes: this is migration/classification work, not just readiness.
Public facade/Cabal/docs cleanup remains separate.
Current status: pending. Prior rounds moved most concrete EventLog and
Permission usages; current exact facade imports appear concentrated in
facade-policy/parity surfaces and public facade modules, but the milestone must
verify that before closeout.

Candidate directions:

- Direction id: `direction-012a-eventlog-bridge-closeout`
  Summary: Verify and finish remaining concrete `Workflow.EventLog` bridge uses
  or classify them as policy/public facade owners.
  Why it matters now: EventLog bridge cleanup is nearly finite and should not
  stay hidden under generic import convergence.
  Preconditions: current EventLog facade scan and focused replay/audit evidence
  for any moved use.
  Parallel hints: serial with event-log production changes.
  Boundary notes: no event JSON `type`, replay, old-log, public facade, Cabal,
  or docs cleanup change.
  Extraction notes: prefer direct-owner migration where behavior is already
  proven; otherwise record the exact parity owner.

- Direction id: `direction-012b-permission-bridge-closeout`
  Summary: Verify and finish remaining concrete `Workflow.Permission` bridge
  uses or classify them as policy/public facade owners.
  Why it matters now: Permission facade use should converge toward
  `Workflow.Permission.Core` where it is reusable and concrete behavior is
  already covered.
  Preconditions: current Permission facade scan and focused validation evidence
  for any moved use.
  Parallel hints: serial with permission behavior tests.
  Boundary notes: no permission policy behavior, phase validation, public
  facade, Cabal, or docs cleanup change.
  Extraction notes: preserve `MoifoldSpec` behavior and validation error text.

- Direction id: `direction-012c-eventlog-permission-policy-classification`
  Summary: Record the intentional policy/parity owners for any remaining
  EventLog or Permission facade imports.
  Why it matters now: policy evidence imports should be explicit closeout
  facts, not open-ended blockers.
  Preconditions: safe EventLog and Permission migration candidates resolved.
  Parallel hints: artifact-only or narrow test-policy round.
  Boundary notes: no facade exposure, Cabal, docs, or public API change.
  Extraction notes: include exact scans and the reason each retained facade
  import remains lawful.

### 6. [pending] AppServerClient Public Surface Cleanup

Milestone id: `milestone-006-appserverclient-public-surface-cleanup`
Depends on: `milestone-001-test-topology-inventory`
Intent: Handle `CodexWatcher.AppServerClient` public facade, Cabal exposure,
docs, and policy cleanup after direct source/app/test imports have moved away.
Completion signal: current scans prove there are no concrete source/app/test
imports through `CodexWatcher.AppServerClient` except intentional policy or
public facade surfaces; the public facade/Cabal/docs decision is recorded as
keep, deprecate, migrate, or remove with exact evidence.
Parallel lane: bridge/facade lane
Coordination notes: direct import migration is not enough to remove the public
facade. Public compatibility cleanup needs docs, Cabal, and downstream scope.
Current status: pending. Current scans show no concrete source/app/test imports
through `CodexWatcher.AppServerClient` beyond the facade module itself and
policy/docs/Cabal references, but public-surface cleanup has not been approved.

Candidate directions:

- Direction id: `direction-010z-appserverclient-public-surface-decision`
  Summary: Decide whether `CodexWatcher.AppServerClient` remains, receives
  deprecation wording, or can move toward removal.
  Why it matters now: source imports are gone, so the remaining question is the
  public compatibility contract.
  Preconditions: current import scan, docs/policy scan, Cabal exposed-module
  scan, and downstream/operator scope.
  Parallel hints: serial.
  Boundary notes: no deprecation pragma, docs warning, or Cabal exposure change
  unless the exact decision is approved.
  Extraction notes: record kept/deprecated/removed candidate state and blockers.

- Direction id: `direction-010y-appserverclient-cabal-doc-policy-alignment`
  Summary: Align Cabal exposure, docs, and compatibility policy for the
  approved AppServerClient public-surface decision.
  Why it matters now: public API cleanup must be consistent across code,
  package metadata, and docs.
  Preconditions: direction 010z approval naming the exact surface and decision.
  Parallel hints: serial.
  Boundary notes: no unrelated facade or runtime compatibility cleanup.
  Extraction notes: update only the named public-surface artifacts and preserve
  behavior validation.

### 7. [pending] Large Runtime Module Decomposition

Milestone id: `milestone-007-large-module-decomposition`
Depends on: `milestone-001-test-topology-inventory`
Intent: Split the largest runtime and workflow modules behind focused tests so
future behavior changes are reviewable.
Completion signal: each selected module has a smaller, named ownership split;
focused tests cover the moved behavior; public exports remain stable unless a
specific reviewed direction approves a change; and baseline build/test checks
pass after each split.
Parallel lane: large-module split lane
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

### 8. [pending] Runtime Compatibility Cleanup Gates

Milestone id: `milestone-008-runtime-compatibility-cleanup-gates`
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
  Preconditions: milestone 002 evidence and any new runtime compatibility
  classifications from milestone 003.
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
  Summary: Remove only compatibility files whose removal gates are all
  approved.
  Why it matters now: deletion is the final cleanup action, not the first.
  Preconditions: reviewer approval naming exact file paths and satisfied gates.
  Parallel hints: serial.
  Boundary notes: no broad runtime compatibility cleanup by implication.
  Extraction notes: include old-log, fixture, healthcheck, repair,
  write-timing, operator/downstream, and baseline evidence.

### 9. [pending] Final Deprecation And Removal Campaign

Milestone id: `milestone-009-final-deprecation-removal`
Depends on:
`milestone-003-core-ids-production-import-burndown`,
`milestone-004-core-ids-test-and-fixture-import-burndown`,
`milestone-005-eventlog-permission-bridge-burndown`,
`milestone-006-appserverclient-public-surface-cleanup`,
`milestone-008-runtime-compatibility-cleanup-gates`
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
  Extraction notes: record removed-surface set, retained-surface set,
  build/test evidence, focused behavior evidence, and policy updates.

- Direction id: `direction-024-terminal-cleanup-report`
  Summary: Prove compatibility removal is complete or expand the roadmap with
  the next cleanup milestones.
  Why it matters now: a broad cleanup family must not silently finish by
  exhausting tasks while compatibility surfaces remain.
  Preconditions: deprecation/removal rounds complete and every roadmap-covered
  compatibility surface has a reviewed removed or migrated final state.
  Parallel hints: serial.
  Boundary notes: a hold is valid as interim evidence only; it is not terminal
  success. If any compatibility surface remains kept, deferred, blocked, or
  hold-only, terminal closeout is not ready.
  Extraction notes: include kept, deferred, deprecated, removed, migrated, and
  blocked surface sets plus validation commands. The kept, deferred, and
  blocked compatibility-surface sets must be empty for terminal approval.
