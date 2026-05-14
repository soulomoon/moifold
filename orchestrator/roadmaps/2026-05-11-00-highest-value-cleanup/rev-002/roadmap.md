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
- Non-goals: no casual removal of public wrappers or compatibility files; no
  compatibility-file rename or deletion before fixture and behavior evidence;
  no event JSON `type` migration; no release or publication approval. The
  current direct cleanup removed only surfaces whose gates are recorded in
  `completion-audit.md`.
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
  until exact public-surface cleanup directions approve a change. The removed
  wrappers are listed in `completion-audit.md`; this rule still applies to any
  remaining product-facing surfaces.
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
Completion signal: selected runtime-state fixture slices and the former
`planner-state.json` versus `planning-state.json` contract have reviewed
evidence; later runtime cleanup removed the obsolete `planning-state.json`
projection while preserving `planner-state.json`.
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
  Summary: Remove the old `CodexWatcher.GoldenReplay`/`CodexWatcher.Snapshot`
  bridge after migrating its compatibility evidence to event-log fixtures.
  Why it matters now: checked-in compatibility snapshots were a cleanup blocker;
  event-log fixtures now carry the retained behavior coverage directly.
  Preconditions: fixture-by-fixture bootstrapped event-log validation.
  Parallel hints: serial with EventLog.Types and runtime compatibility work.
  Boundary notes: no event JSON `type` change; bootstrapped fixtures must replay
  to the same domain and phase as the removed snapshots.
  Extraction notes: completed by direct cleanup after the import-only round.
  The old snapshot modules and `golden/pr-review/*` plus
  `golden/issue-implement/*` compatibility snapshot JSON fixtures were removed;
  `golden/event-log/bootstrapped/*` now preserves the retained replay evidence.

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

### 4. [completed] Core.Ids Test And Fixture Import Burndown

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
Current status: completed by rounds 187 through 195. Round 187 migrated
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
Round 194 migrated `test/RuntimeCompatibilityFixtureSpec.hs` from
`CodexWatcher.Core.Ids` to direct `CodexWatcher.Workflow.Agent.Ids (ThreadId,
TurnId)` and `CodexWatcher.Workflow.GitHub.Ids (BranchName, IssueNumber,
PrNumber, RepoName)` imports. The reviewer approved the round-194 import-only
diff after `cabal build all`, `cabal test watcher-core-test`, git diff checks,
selected-file no-`Core.Ids` scan, selected-file direct-owner imports,
selected-file diff inspection, aggregate/policy/public-surface unchanged
checks, and broad remaining-user classification all passed. The
`direction-011i-runtime-compatibility-fixture-core-ids-import` extracted item
is complete. Direction 011i runtime/CLI test imports are complete: the current
broad scan finds no remaining safe runtime or CLI test `Core.Ids` imports.
Round 195 originally classified the only remaining test `Core.Ids` imports as
intentional evidence surfaces. The direct cleanup pass after round 195 removed
those final test imports too: `test/FacadeImportPolicySpec.hs` now imports
direct agent/GitHub id owners and `test/Main.hs` imports direct agent/GitHub id
owners. Direction 011j and milestone 004 are complete: every safe test/fixture
`Core.Ids` import has migrated and no app, reusable package, production `src`,
or test users remain. Later public-surface cleanup removed the public facade,
Cabal exposure, and stale docs/policy claims. This status does not approve
runtime compatibility cleanup, release approval, or package publication.

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
  direction 011i runtime/CLI test imports are also complete; continue
  milestone 004 with direction 011j policy/aggregator classification.

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
  `test/RuntimeCompatibilityFixtureSpec.hs` was completed by round 194 as an
  import-only direct-owner migration; this completed extracted item is
  `direction-011i-runtime-compatibility-fixture-core-ids-import`. Direction
  011i runtime/CLI test imports are complete; continue milestone 004 with
  direction 011j policy/aggregator classification.

- Direction id: `direction-011j-core-ids-policy-and-aggregator-classification`
  Summary: Classify remaining facade-policy or aggregation imports such as
  `test/FacadeImportPolicySpec.hs` and `test/Main.hs`.
  Why it matters now: intentional policy evidence should not keep the import
  burndown milestone open forever.
  Preconditions: safe test migrations have run.
  Parallel hints: artifact-only or narrow test-only round.
  Boundary notes: no public facade removal or policy weakening.
  Extraction notes: completed by round 195 as artifact-only classification
  evidence, then superseded by the direct cleanup pass after round 195.
  `test/FacadeImportPolicySpec.hs` and `test/Main.hs` now import direct
  agent/GitHub id owners instead of `CodexWatcher.Core.Ids`. Focused scans find
  no remaining test or fixture `Core.Ids` imports. This completes direction
  011j and milestone 004 without approving runtime compatibility cleanup,
  release approval, or package publication.

### 5. [completed] EventLog And Permission Bridge Burndown

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
Current status: completed by the direct cleanup pass after round 195. Focused
source/app/test scans found no concrete `CodexWatcher.Workflow.EventLog` or
`CodexWatcher.Workflow.Permission` imports beyond the policy/parity test and
public wrapper modules. `test/FacadeImportPolicySpec.hs` now uses
`CodexWatcher.Workflow.EventLog.Core` and
`CodexWatcher.Workflow.Permission.Core` directly, preserving replay and
permission parity assertions. The public wrapper modules were then removed in
milestone 006/final public-surface cleanup. Event JSON `type` fields, replay
behavior, permission validation behavior, fixtures, and runtime compatibility
files are unchanged.

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
  Extraction notes: completed by direct-owner migration rather than retained
  facade classification. No retained EventLog or Permission facade import
  remains in source/app/test code.

### 6. [completed] AppServerClient Public Surface Cleanup

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
Current status: completed by the direct cleanup pass after round 195. Current
source/app/test scans found no concrete imports through
`CodexWatcher.AppServerClient`; the main Cabal exposed-module entry and thin
wrapper module were removed, and docs/policy now point consumers at
`CodexWatcher.Workflow.Agent.Codex.Client` and
`CodexWatcher.Workflow.Agent.Codex.Transport` directly. App-server endpoint
parsing, session handling, command rendering, failure formatting, runtime
compatibility files, and package publication status are unchanged.

Candidate directions:

- Direction id: `direction-010z-appserverclient-public-surface-decision`
  Summary: Remove `CodexWatcher.AppServerClient` from the main public surface
  after proving no concrete source/app/test users remain.
  Why it matters now: source imports are gone, so the remaining question is the
  public compatibility contract.
  Preconditions: current import scan, docs/policy scan, Cabal exposed-module
  scan, and downstream/operator scope.
  Parallel hints: serial.
  Boundary notes: no deprecation pragma, docs warning, or Cabal exposure change
  unless the exact decision is approved.
  Extraction notes: completed as removal. The wrapper module and Cabal exposure
  are gone; docs/policy point consumers at direct Codex client and transport
  owner modules.

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

### 7. [completed] Large Runtime Module Decomposition

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
Current status: completed by the direct cleanup pass after round 195. The pass
extracted `CodexWatcher.Daemon.Types`, `CodexWatcher.TurnOutput.Schema`,
`CodexWatcher.Workflow.Moifold.IssueImplement.Indexed.Types`,
`CodexWatcher.Workflow.DocsMigration.Types`, and
`CodexWatcher.EventLog.Types.Core` while preserving existing public exports
from `CodexWatcher.Daemon`, `CodexWatcher.TurnOutput`,
`CodexWatcher.Workflow.Moifold.IssueImplement.Indexed`,
`CodexWatcher.Workflow.DocsMigration`, and `CodexWatcher.EventLog.Types`.
`cabal build all` and `cabal test watcher-core-test` passed after these
splits.

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
  Extraction notes: completed for daemon type/result ownership by extracting
  `CodexWatcher.Daemon.Types` while preserving the `CodexWatcher.Daemon`
  public export surface.

- Direction id: `direction-014-docs-migration-module-split`
  Summary: Split `Workflow.DocsMigration` into smaller parsing, planning, and
  replay/application owners.
  Why it matters now: docs migration has golden and replay behavior that should
  be isolated before cleanup.
  Preconditions: current docs migration tests and golden replay evidence.
  Parallel hints: serial unless only test support moves.
  Boundary notes: preserve docs migration event schemas and golden behavior.
  Extraction notes: completed for docs migration type/model ownership by
  extracting `CodexWatcher.Workflow.DocsMigration.Types` while keeping
  `DocsMigrationSpec` instances and public exports in
  `CodexWatcher.Workflow.DocsMigration`.

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
  Extraction notes: completed for indexed type/projection ownership by
  extracting
  `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed.Types` while leaving
  concrete moifold transition policy in the existing module.

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
  Extraction notes: completed for event/codec ownership by moving the existing
  implementation into `CodexWatcher.EventLog.Types.Core` and preserving
  `CodexWatcher.EventLog.Types` as the stable public wrapper.

- Direction id: `direction-017-turn-output-module-split`
  Summary: Split `CodexWatcher.TurnOutput` into structured-output, prompt
  version, and rendering owners.
  Why it matters now: turn output and prompt compatibility are user-visible and
  should be isolated before cleanup.
  Preconditions: focused output/prompt tests for touched behavior.
  Parallel hints: serial with prompt or app-server output changes.
  Boundary notes: preserve structured-output requirements and prompt schema
  compatibility.
  Extraction notes: completed for structured output schema ownership by
  extracting `CodexWatcher.TurnOutput.Schema` while preserving prompt text,
  app-server protocol, and output parsing behavior.

### 8. [completed] Runtime Compatibility Cleanup Gates

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
Current status: completed for the selected local cleanup surfaces. The direct
cleanup moved healthcheck to event-replay projections, removed normal local
compatibility-file writers, removed the obsolete `planning-state.json`
projection and fixture, removed the repair-failure `block-state.json` writer
and fixture, migrated checked-in compatibility snapshots to bootstrapped
event-log fixtures, and removed restart/operator dependence on stale
compatibility files. `repair-state.json`, `runtime-owner.json`, and live
`issue-snapshot.json` are documented as retained product contracts outside the
compatibility-file removal goal. Downstream direct readers were migrated by
merged PR `soulomoon/pr-review-watcher-tool#1`; no runtime-compatibility
cleanup blocker remains.

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
  Extraction notes: completed by the direct cleanup audit and policy refresh.
  Current classifications are recorded in
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` and
  `docs/agentic-workflow-framework/local-runtime-file-candidates.md`.

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
  Extraction notes: completed locally for selected surfaces: healthcheck now
  projects compatibility state from event replay, checked-in snapshots were
  migrated to bootstrapped event-log fixtures, and the downstream audit branch
  `codex/moifold-healthcheck-migration` commit `c2a14af` carries the external
  consumer migration pending owner acceptance.

- Direction id: `direction-020-selected-compatibility-file-removal`
  Summary: Remove only compatibility files whose removal gates are all
  approved.
  Why it matters now: deletion is the final cleanup action, not the first.
  Preconditions: reviewer approval naming exact file paths and satisfied gates.
  Parallel hints: serial.
  Boundary notes: no broad runtime compatibility cleanup by implication.
  Extraction notes: completed locally for approved removal slices:
  `planning-state.json`, normal local compatibility-file writers,
  repair-failure `block-state.json`, stale snapshot readers/fixtures, and
  restart/operator stale-file cleanup. Downstream acceptance remains the only
  terminal gate for the runtime compatibility files still observed outside
  this repo.

### 9. [completed] Final Deprecation And Removal Campaign

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
Current status: completed. Public wrapper removals landed
for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
`CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`, with
direct-owner imports, Cabal exposure cleanup, docs/policy updates, and
`cabal build all` and `cabal test watcher-core-test` evidence. The 2026-05-14
completion audit found direct downstream readers in
`soulomoon/pr-review-watcher-tool` for `issue-state.json`,
`daemon-state.json`, `planner-state.json`, PR-review state files, and
`block-state.json`; local healthcheck now projects the replacement state shape
from event replay instead of reading those compatibility files directly. PR
`soulomoon/pr-review-watcher-tool#1` migrated those downstream readers and
daemon scripts and was accepted by merge on 2026-05-14. Normal local
compatibility-file writers have also been removed: launch/fanout,
daemon-transaction, daemon-loop idle/terminal, repair, PR-review handoff, and
`RecordBlocked` paths no longer write those compatibility files. The
invalid-event-log repair-failure `block-state.json` writer/fixture, checked-in
compatibility snapshot bridge, and restart/operator stale-file cleanup were
removed after the normal writer cleanup. Retained product files are explicitly
outside the compatibility-file removal goal. The roadmap-covered kept,
deferred, and blocked compatibility-removal sets are empty.

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

### 10. [completed] Downstream Runtime-File Migration Front

Milestone id: `milestone-010-downstream-runtime-file-migration`
Depends on: `milestone-008-runtime-compatibility-cleanup-gates`
Blocks: `milestone-009-final-deprecation-removal`
Intent: Turn the newly confirmed downstream direct-reader inventory into
concrete migration work before any terminal cleanup claim.
Completion signal: every downstream direct reader of `issue-state.json`,
`daemon-state.json`, `planner-state.json`, PR-review state files, and
`block-state.json` has either migrated to a supported replacement API/path or
is explicitly retained as a product contract outside the compatibility-removal
goal with updated docs, tests, and owner approval. The runtime compatibility
policy must list no unknown downstream direct-reader gate for these surfaces.
Parallel lane: serial
Coordination notes: this milestone is not optional terminal paperwork. The
2026-05-14 audit found live direct readers in `soulomoon/pr-review-watcher-tool`,
so local moifold deletion would break known downstream code.
Current status: completed after the local replacement read contract, local
runtime-file candidate classification, and downstream migration acceptance
landed.
`docs/agentic-workflow-framework/downstream-runtime-state-migration.md`
defines the supported read-only migration path through
`moifold healthcheck --state-root /workspace/artifacts --repo owner/name`, and
`healthcheckRuntimeStateMigrationContractTests` guard the legacy state
projection keys under `watchers[].states.*`. Healthcheck now derives those
compatibility-state entries from event replay rather than direct
compatibility-file reads. That completes the read-only replacement mapping for
health/status consumers. The direct cleanup pass also implemented a local
downstream-audit patch in `/tmp/pr-review-watcher-tool-audit`
that routes read-only status/healthcheck commands through `moifold
healthcheck` and replaces the legacy Node daemon bodies with launchers for the
Haskell `moifold run-* --execute --loop` commands. `npm run check`,
fake-`moifold` health/status smokes, fake-`moifold` daemon launcher smokes, and
`moifold replay-events` checks for the generated initial event logs passed
there. PR `soulomoon/pr-review-watcher-tool#1` accepted that patch by merge on
2026-05-14. The local runtime-file migration is completed by the separate
candidate classification:
`docs/agentic-workflow-framework/local-runtime-file-candidates.md` classifies
the local no-downstream-hit files and `localRuntimeFileCandidateDecisionTest`
guards that decision.
Normal local Haskell compatibility-file producers have now been removed,
checked-in compatibility snapshot readers/fixtures have been migrated to
bootstrapped event-log fixtures and removed, and operator restart/runbook paths
no longer depend on stale compatibility files. The retained product files are
documented as product contracts outside the compatibility-removal goal. The
repair-failure `block-state.json` writer and fixture have been removed locally.

Candidate directions:

- Direction id: `direction-025-downstream-state-file-migration-plan`
  Summary: Define replacement reads or product-contract retention for the
  `soulomoon/pr-review-watcher-tool` direct state-file readers.
  Why it matters now: terminal cleanup is blocked by known downstream readers,
  not by speculative risk.
  Preconditions: current `gh search code` direct-reader inventory and local
  runtime-file reader/writer inventory.
  Parallel hints: serial.
  Boundary notes: no local file removal until the replacement reader path is
  implemented and validated.
  Extraction notes: completed for the local read-only replacement contract.
  `docs/agentic-workflow-framework/downstream-runtime-state-migration.md`
  maps `issue-state.json`, `daemon-state.json`, `planner-state.json`,
  PR-review state files, and `block-state.json` to `moifold healthcheck`
  `watchers[].states.*` paths. A local downstream-audit patch implements the
  read-only command migration for status/healthcheck commands and replaces the
  legacy daemon scripts with compatibility launchers for the Haskell
  `moifold run-*` loops. PR `soulomoon/pr-review-watcher-tool#1` accepted this
  migration by merge on 2026-05-14. No downstream direct-reader blocker
  remains.

- Direction id: `direction-026-local-runtime-file-removal-candidates`
  Summary: Separately evaluate locally produced runtime files without known
  downstream code-search hits: `planning-state.json`, `repair-state.json`,
  `runtime-owner.json`, and live `issue-snapshot.json`.
  Why it matters now: these files have different ownership. Some may be
  removable compatibility projections; others are live product/operator
  contracts.
  Preconditions: focused local reader/writer scan, fixture evidence, healthcheck
  evidence, repair evidence, and operator runbook/script inventory.
  Parallel hints: serial by file.
  Boundary notes: `runtime-owner.json` and live `issue-snapshot.json` are
  operator/runtime behavior until a selected replacement is implemented.
  Extraction notes: completed for local classification. The decision artifact
  `docs/agentic-workflow-framework/local-runtime-file-candidates.md` classifies
  `planning-state.json` as `removed`, `repair-state.json` as
  `keep-as-product`, `runtime-owner.json` as `keep-as-product`, and live
  `issue-snapshot.json` as `keep-as-product`. The aggregate
  `localRuntimeFileCandidateDecisionTest` plus existing fixture/source tests
  guard the decision. This direction removed only the obsolete
  `planning-state.json` compatibility projection; the kept product files still
  require selected replacement work before any removal. A follow-up direct
  cleanup also removed normal compatibility-file producers for
  `issue-state.json`, `daemon-state.json`, `planner-state.json`, PR-review
  state files, and normal `block-state.json`; a follow-up direct cleanup
  migrated checked-in compatibility snapshots to event-log fixtures and removed
  the snapshot bridge; another follow-up removed restart/operator dependence on
  stale compatibility files. The retained product files are documented outside
  the compatibility-removal goal. The repair-failure `block-state.json` writer
  and fixture were removed as a follow-up local cleanup slice.

- Direction id: `direction-027-runtime-compatibility-terminal-report`
  Summary: Re-run terminal closeout after downstream and local runtime-file
  migration work lands.
  Why it matters now: milestone 009 cannot close until known direct readers are
  migrated or the goal changes.
  Preconditions: directions 025 and 026 completed or explicitly superseded by
  a new roadmap revision.
  Parallel hints: serial.
  Boundary notes: no terminal `done` while kept, deferred, or blocked
  compatibility-surface sets remain.
  Extraction notes: update `completion-audit.md`, compatibility policy, docs,
  and verification evidence together.
