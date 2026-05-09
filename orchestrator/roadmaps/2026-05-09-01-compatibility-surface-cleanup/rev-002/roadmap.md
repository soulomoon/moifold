# Compatibility Surface Cleanup Roadmap

Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
Roadmap revision: `rev-002`
Roadmap style: `strategy-backlog`

## Goal

Prepare, verify, and eventually perform selected compatibility surface cleanup
for moifold's workflow package split while preserving event schemas, golden
fixtures, runtime compatibility files, healthcheck, repair behavior, and
current package boundaries.

## Activation Metadata

After this revision is merged and accepted by update-roadmap, the controller
should activate:

- `roadmap_id`: `2026-05-09-01-compatibility-surface-cleanup`
- `roadmap_revision`: `rev-002`
- `roadmap_dir`:
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

## Alignment Summary

- Thesis: compatibility cleanup remains evidence-first. Round 058 found
  source-backed follow-up gaps, so rev-002 expands the backlog before gated
  removals instead of treating the initial todo list as exhaustive.
- Success criteria: reviewers can see the completed evidence from rounds
  052-059, then review additional import-facade, runtime compatibility, and
  external operator/downstream evidence before any exact removal slice is
  selected.
- Non-goals: no package publication work, no event schema migration, no
  incidental prompt/runtime/healthcheck/repair redesign, no generic prompt
  runner, no workflow `liftIO`, no deprecation pragma, no migration, no
  exposed-module removal, and no cleanup approval merely because a surface is
  listed in this revision.
- Chosen strategy: staged compatibility cleanup with an expanded evidence
  backlog. Inventory, readiness, policy, and follow-up discovery are complete;
  rev-002 adds follow-up evidence gates and keeps removals behind explicit
  reviewer approval.
- Deferred alternatives: terminal cleanup now is too risky because round 058
  identified missing import ownership maps, fixture coverage, healthcheck or
  non-healthcheck policy, and external operator/downstream inventory.

## Outcome Boundaries

- In scope: import-facade follow-up evidence, runtime compatibility-file
  follow-up evidence, external operator/downstream inventory, later selected
  removal planning, final reporting, and explicit done-or-hold closeout.
- Out of scope: package upload, public release approval, event JSON `type`
  changes, compatibility-file schema migration, healthcheck or repair
  redesign, daemon ownership changes, app-server startup policy changes,
  production import rewrites, Cabal exposure changes, broad package API
  redesign, and actual removals outside a later selected gated-removal round.

## Global Sequencing Rules

- Inventory before policy. Policy must cite current source evidence rather
  than desired cleanup shape.
- Policy before removal. A surface may become a removal candidate only after
  replacement paths, users, tests, and compatibility consequences are known.
- Rev-002 adds follow-up evidence before removal. Round 058 candidates are
  evidence gaps, not removal approvals.
- Runtime compatibility files require old-log, golden, repair, healthcheck or
  explicit non-healthcheck policy, write-timing, fixture, and operator evidence
  before removal or behavior changes.
- Import facade cleanup requires recursive import scans, per-surface ownership
  evidence, public/downstream-user review, and package-boundary tests before
  any deprecation or removal.
- Gated removals are allowed only after milestones 005-007 complete and only
  when a selected direction names exact surfaces, lists satisfied gates, and a
  reviewer approves the exact removal evidence.

## Parallel Lanes

- Default lane: serial. Compatibility cleanup touches shared contracts and
  should stay ordered until evidence proves disjoint ownership.
- Potential lane `import-facades`: source scans, replacement maps,
  per-import ownership maps, public API review, and package-boundary evidence.
- Potential lane `runtime-compatibility`: compatibility-file fixtures,
  old-log, healthcheck or non-healthcheck policy, repair, write-timing, and
  operator-script evidence.
- Potential lane `external-inventory`: manual operator/downstream inventory
  across public imports, state-file paths, docs, scripts, and runbooks.

## Milestones

### 1. [complete] Inventory Compatibility Surfaces

Milestone id: `milestone-001-inventory-compatibility-surfaces`
Depends on: none
Intent: Build a complete source-backed inventory of public import facades and
runtime compatibility files before policy or removal work begins.
Completion signal: the repo has reviewable docs or artifacts listing every
in-scope import facade, runtime compatibility file, current producer, current
consumer, tests protecting it, and unknowns.
Progress: round 052 completed import-facade inventory in `2179bb4`; round 053
completed runtime compatibility-file inventory in `9e34917`. The milestone is
complete with source-backed artifacts and no production, descriptor, runtime,
deprecation, or removal changes.

Candidate directions:

- Direction id: `direction-001-import-facade-inventory`
  Status: complete via round 052, merged as `2179bb4`.
  Summary: inventory Haskell compatibility import facades and current users.
  Boundary notes: no deprecation pragmas and no import rewrites.

- Direction id: `direction-002-runtime-compatibility-file-inventory`
  Status: complete via round 053, merged as `9e34917`.
  Summary: inventory runtime compatibility files, write sites, read sites,
  repair use, healthcheck use, and old-log assumptions.
  Boundary notes: no file name, field, timing, or compatibility write changes.

### 2. [complete] Prove Replacement Paths And Behavior Gates

Milestone id: `milestone-002-replacement-paths-and-behavior-gates`
Depends on: `milestone-001-inventory-compatibility-surfaces`
Intent: Convert inventory into testable readiness evidence: preferred imports,
replacement APIs, old-log behavior, write timing, repair, healthcheck, and
golden replay protections.
Completion signal: each cleanup candidate has a keep/defer/remove-later
classification with required tests or manual evidence identified, and missing
tests are added before the candidate can advance.
Progress: round 054 completed import replacement readiness in `2c2771c`;
round 055 completed runtime compatibility-file behavior gates in `e6bc2ee`.
The milestone is complete with conservative classifications and missing
evidence recorded before any candidate can advance.

Candidate directions:

- Direction id: `direction-003-import-replacement-readiness`
  Status: complete via round 054, merged as `2c2771c`.
  Summary: prove preferred package-facing imports and add tests or scans that
  prevent accidental fallback to compatibility facades.
  Boundary notes: no wrapper removal.

- Direction id: `direction-004-runtime-file-behavior-gates`
  Status: complete via round 055, merged as `e6bc2ee`.
  Summary: prove compatibility-file behavior through golden replay, repair,
  healthcheck, write-timing, and old snapshot evidence.
  Boundary notes: no file schema migration or removal.

### 3. [complete] Write Cleanup Policy From Evidence

Milestone id: `milestone-003-evidence-backed-cleanup-policy`
Depends on: `milestone-002-replacement-paths-and-behavior-gates`
Intent: Turn readiness evidence into a concrete compatibility cleanup policy
that classifies each surface and names the gates for deprecation or removal.
Completion signal: docs and project contract accurately state which surfaces
stay, which may be deprecated later, which may be removed at the end of this
family, and which evidence is required per surface.
Progress: round 056 completed import-facade cleanup policy in `8a6bcf6`;
round 057 completed runtime compatibility-file cleanup policy in `10b3191`.
The milestone is complete because both policy directions preserve future gates
and do not approve removals.

Candidate directions:

- Direction id: `direction-005-import-facade-cleanup-policy`
  Status: complete via round 056, merged as `8a6bcf6`.
  Summary: document preferred imports, deprecation readiness, and removal gates
  for Haskell import facades.
  Boundary notes: no deprecation pragma or removal.

- Direction id: `direction-006-runtime-compatibility-cleanup-policy`
  Status: complete via round 057, merged as `10b3191`.
  Summary: document keep/defer/remove-later policy for runtime compatibility
  files and snapshots.
  Boundary notes: no file migration or removal.

### 4. [complete] Expand Follow-Up Backlog Before Terminal Cleanup

Milestone id: `milestone-004-expand-follow-up-backlog`
Depends on: `milestone-003-evidence-backed-cleanup-policy`
Intent: Re-scan the evidence near the end of the initial todo list and expand
the roadmap with newly discovered cleanup items before final removals begin.
Completion signal: a roadmap-update round either creates a new revision with
additional cleanup milestones/directions or records that no additional items
are justified by current evidence.
Progress: round 058 completed follow-up discovery in `ada64b6`, identifying
import-facade evidence candidates, runtime compatibility evidence candidates,
and external operator/downstream inventory gaps without approving migration,
deprecation, removal, publication, upload, or release. Round 059 publishes
this rev-002 expansion and keeps all discovered candidates as evidence gates
before removals. Milestone 004 is complete once this revision is approved and
activated.

Candidate directions:

- Direction id: `direction-007-follow-up-discovery`
  Status: complete via round 058, merged as `ada64b6`.
  Summary: review inventories, policy docs, tests, TODOs, and reviewer notes to
  find follow-up cleanup items before removal rounds.
  Boundary notes: no removal during discovery.

- Direction id: `direction-008-roadmap-expansion-update`
  Status: complete via round 059.
  Summary: publish rev-002 with additional evidence milestones before gated
  removal work.
  Boundary notes: this update changes active revision metadata only after
  merge/update-roadmap; it does not approve cleanup.

### 5. [complete] Complete Import-Facade Follow-Up Evidence

Milestone id: `milestone-005-import-facade-follow-up-evidence`
Depends on: `milestone-004-expand-follow-up-backlog`
Intent: Convert the import-facade candidates from round 058 into surface-level
evidence that can support a later keep/defer/removal selection.
Completion signal: each selected facade has refreshed import scans,
replacement ownership, public/downstream-user review, package-boundary
evidence, and explicit remaining blockers before any final removal round.
Coordination notes: this milestone must not add deprecation pragmas, remove
facades, change Cabal exposure, or migrate production imports except where a
selected evidence direction explicitly proves behavior-preserving readiness.
Progress: round 060 completed `direction-009-core-ids-split-import-evidence`,
merged as `329e827`, with refreshed `CodexWatcher.Core.Ids` import scans,
split agent/GitHub ownership evidence, package-boundary exposure assertions,
and conservative migration blockers. Round 061 completed
`direction-010-app-server-client-migration-readiness`, merged as `ef04cd3`,
with refreshed `CodexWatcher.AppServerClient` import counts, caller grouping by
client/parser, transport/session, protocol/request, and product-policy
ownership, replacement module exposure evidence, current app-server behavior
coverage readback, and conservative blockers for later migration or cleanup.
Round 062 completed
`direction-011-event-log-concrete-helper-boundary`, merged as `da13d68`, with
refreshed `CodexWatcher.Workflow.EventLog` import/reference scans, helper
ownership classification, package exposure readback, old-log/golden replay
coverage notes, and conservative blockers for any later helper movement,
facade narrowing, migration, deprecation, or removal decision. Round 063
completed `direction-012-workflow-permission-public-api-review`, merged as
`b7d5eff`, with public `CodexWatcher.Workflow.Permission` exposure readback,
import/reference inventory, focused permission behavior evidence, replacement
and ownership notes, and downstream/operator blockers before any later
cleanup. The milestone is complete because directions 009 through 012 are now
complete.

Candidate directions:

- Direction id: `direction-009-core-ids-split-import-evidence`
  Status: complete via round 060, merged as `329e827`.
  Summary: produce a per-import ownership map for `CodexWatcher.Core.Ids`,
  separating agent ids from GitHub ids and recording migration risks.
  Preconditions: refreshed recursive import scan and current package-boundary
  assertions.
  Boundary notes: the combined facade remains public until a later selected
  round proves downstream compatibility and reviewer approval.

- Direction id: `direction-010-app-server-client-migration-readiness`
  Status: complete via round 061, merged as `ef04cd3`.
  Summary: group each `CodexWatcher.AppServerClient` use by
  client/transport/parser ownership and record dry-run migration readiness.
  Preconditions: refreshed import count, current tests for app-server client
  behavior, and replacement module exposure evidence.
  Boundary notes: no production import migration or facade removal by this
  evidence direction alone.

- Direction id: `direction-011-event-log-concrete-helper-boundary`
  Status: complete via round 062, merged as `da13d68`.
  Summary: prove which `CodexWatcher.Workflow.EventLog` helpers are concrete
  moifold compatibility helpers versus preferred reusable event-log imports.
  Preconditions: old-log and golden replay evidence for any helper movement.
  Boundary notes: low import count is not removal evidence; event-log behavior
  and fixtures are compatibility contracts.

- Direction id: `direction-012-workflow-permission-public-api-review`
  Status: complete via round 063, merged as `b7d5eff`.
  Summary: review `CodexWatcher.Workflow.Permission` as a public API surface,
  including downstream-user inventory and concrete permission behavior parity.
  Preconditions: public exposure readback and permission behavior tests or
  manual evidence.
  Boundary notes: absence of production imports does not make a public exposed
  module removable.

### 6. [complete] Complete Runtime Compatibility Follow-Up Evidence

Milestone id: `milestone-006-runtime-compatibility-follow-up-evidence`
Depends on: `milestone-005-import-facade-follow-up-evidence`
Intent: Fill the runtime compatibility evidence gaps found in round 058 before
any runtime file, snapshot, or operator path is selected for cleanup.
Completion signal: weakly represented runtime files have checked-in fixture or
manual old-state evidence, explicit healthcheck or non-healthcheck policy,
repair/write-timing evidence where applicable, and operator-script/readback
inventory.
Coordination notes: this milestone does not change filenames, schemas, event
types, write timing, healthcheck behavior, repair behavior, or compatibility
projection behavior unless a later selected round explicitly authorizes a
proven migration.
Progress: round 064 completed
`direction-013-planning-state-fixture-policy`, merged as `d3a7897`, with
source-backed evidence for `planning-state.json` producers, current
non-healthcheck status, behavior-test coverage, missing checked-in fixture
coverage, and conservative blockers before any later cleanup, migration,
schema, timing, healthcheck, projection, or removal decision. Round 065
completed `direction-014-repair-state-fixture-reader-policy`, merged as
`580e4b3`, with source-backed evidence for `repair-state.json` repair execute
ordering, compatibility rewrite ordering, summary fields, production-reader
inventory, current non-healthcheck status, missing checked-in fixture coverage,
existing source-order test coverage, and conservative blockers before any
later cleanup, migration, schema, timing, healthcheck, repair, projection,
stale-block-cleanup, or removal decision. Round 066 completed
`direction-015-runtime-owner-fixture-operator-inventory`, merged as
`4139015`, with source-backed evidence for `runtime-owner.json` schema and CLI
behavior, automatic-loop timing, healthcheck reads and field-path mismatch,
PR-review launch reuse, `scripts/restart-watcher` parsing and cleanup
behavior, runbook and policy references, missing checked-in fixture coverage,
current `keep` classification, and conservative blockers before any later
cleanup, migration, schema, lease-field, healthcheck, daemon ownership,
restart-script, projection, publication, upload, release, or removal decision.
Round 067 completed `direction-016-daemon-state-active-stopped-fixtures`,
merged as `8782e33`, with source-backed evidence for `daemon-state.json`
active, stopped, and idle projection shapes, old-shape fixture tolerance,
snapshot and golden replay readback, healthcheck, repair, restart cleanup,
current `keep` classification, and conservative blockers before any later
cleanup, removal, migration, schema, healthcheck, daemon, restart-script,
projection, publication, upload, or release decision. Round 068 completed
`direction-017-pr-state-external-path-inventory`, merged as `c0bfb23`, with
source-backed evidence for PR review compatibility state files, issue PR URL
field usage, absent checked-in dedicated PR URL/state paths, snapshot and
healthcheck readback, runbook/script/operator expectations, test and golden
fixture coverage, current `keep`/`defer` classifications, and conservative
blockers before any later cleanup, migration, schema, healthcheck, repair,
projection, publication, upload, or release decision. Round 069 completed
`direction-018-block-state-repair-failure-fixture`, merged as `4c297c8`, with
source-backed evidence for repair-failure `block-state.json` writer shape,
normal blocked writes, compatibility projection, healthcheck/snapshot/golden
readback, stale-block cleanup, restart cleanup, fixture inventory, existing
assertions, current `keep` classification, and conservative blockers before
any later cleanup, removal, migration, schema, write-timing, healthcheck,
repair, projection, stale-cleanup, restart, publication, upload, or release
decision. Round 070 completed
`direction-019-live-issue-snapshot-fixture-timing`, merged as `93e9e55`, with
source-backed evidence for live `issue-snapshot.json` execute-mode writer
timing before planner turn start, prompt/path contract, scoped and closed-scope
snapshot behavior, focused timing tests, absent checked-in live fixture
coverage, no current healthcheck/repair/restart/replay reader, current `defer`
classification, and conservative blockers before any later cleanup, removal,
migration, schema, filename, event-type, write-timing, planner-turn,
projection, healthcheck, repair, replay, publication, upload, release, or
operator behavior decision. The milestone is complete because directions 013
through 019 are complete.

Candidate directions:

- Direction id: `direction-013-planning-state-fixture-policy`
  Status: complete via round 064, merged as `d3a7897`.
  Summary: add evidence for `planning-state.json`, including fixture coverage
  or explicit non-healthcheck policy for its current write-only projection.
  Preconditions: current producer readback and healthcheck state-file readback.
  Boundary notes: active writes remain protected.

- Direction id: `direction-014-repair-state-fixture-reader-policy`
  Status: complete via round 065, merged as `580e4b3`.
  Summary: add fixture, reader, and healthcheck or non-healthcheck evidence for
  `repair-state.json` and repair execution ordering.
  Preconditions: replay repair write-order evidence and compatibility rewrite
  evidence.
  Boundary notes: repair write order must not change.

- Direction id: `direction-015-runtime-owner-fixture-operator-inventory`
  Status: complete via round 066, merged as `4139015`.
  Summary: record checked-in fixture coverage, `lease` field-path readback,
  healthcheck behavior, and operator script/runbook inventory for
  `runtime-owner.json`.
  Preconditions: current runtime owner store, CLI, healthcheck, and
  `scripts/restart-watcher` evidence.
  Boundary notes: this file remains live daemon ownership state.

- Direction id: `direction-016-daemon-state-active-stopped-fixtures`
  Status: complete via round 067, merged as `8782e33`.
  Summary: add active and stopped `daemon-state.json` fixture evidence and
  preserve existing tolerated old-shape evidence.
  Preconditions: current compatibility projection, healthcheck, repair, and
  restart cleanup readback.
  Boundary notes: daemon summary compatibility stays stable.

- Direction id: `direction-017-pr-state-external-path-inventory`
  Status: complete via round 068, merged as `c0bfb23`.
  Summary: inventory PR review state files, PR URL fields, absent dedicated
  PR URL/state paths, runbooks, scripts, and downstream/operator expectations.
  Preconditions: current PR review compatibility outputs and golden fixture
  readback.
  Boundary notes: current PR review state files remain active compatibility
  outputs.

- Direction id: `direction-018-block-state-repair-failure-fixture`
  Status: complete via round 069, merged as `4c297c8`.
  Summary: add focused evidence for repair-failure `block-state.json` output
  shape, direct blocked writes, healthcheck reads, and stale-block cleanup.
  Preconditions: current runner, effect interpreter, compatibility projection,
  and healthcheck readback.
  Boundary notes: normal blocked fixtures are not enough for repair-failure
  cleanup claims.

- Direction id: `direction-019-live-issue-snapshot-fixture-timing`
  Status: complete via round 070, merged as `93e9e55`.
  Summary: add live `issue-snapshot.json` fixture and write-timing evidence for
  issue-planning snapshot creation before planner turn start.
  Preconditions: current issue planning write path and timing tests.
  Boundary notes: live snapshot timing is a workflow contract.

### 7. [pending] Complete External Operator And Downstream Inventory

Milestone id: `milestone-007-external-operator-downstream-inventory`
Depends on: `milestone-006-runtime-compatibility-follow-up-evidence`
Intent: Check external operator and downstream expectations before selecting
any public import facade or runtime compatibility path for removal.
Completion signal: the roadmap has explicit evidence for public imports,
state-file paths, shell/operator consumers, runbooks, downstream users, and
unsupported-user decisions.
Coordination notes: local repository scans are not sufficient removal
approval. This milestone may record a deliberate hold if external evidence is
unavailable or if operator approval is required.

Candidate directions:

- Direction id: `direction-020-external-operator-downstream-inventory`
  Summary: inventory external scripts, operator runbooks, downstream imports,
  state-file path readers, and known unsupported-user decisions across the
  import-facade and runtime compatibility surfaces.
  Preconditions: milestones 005 and 006 evidence is current.
  Boundary notes: this direction produces evidence only; it does not approve
  deprecation, migration, removal, package publication, upload, or release.

### 8. [pending] Perform Gated Compatibility Removals

Milestone id: `milestone-008-gated-compatibility-removals`
Depends on: `milestone-007-external-operator-downstream-inventory`
Intent: Remove only selected compatibility surfaces whose gates have passed
and whose removal has explicit reviewer approval.
Completion signal: approved removal rounds land with import scans, build/test
evidence, old-log/golden evidence where relevant, updated docs, and no
unapproved compatibility behavior drift.
Coordination notes: this is the first milestone where removal is allowed. Each
round must name exactly which surfaces it removes, why every gate is
satisfied, what old-log/golden/repair/healthcheck/import evidence applies, and
where reviewer approval is recorded.

Candidate directions:

- Direction id: `direction-021-remove-approved-import-facades`
  Summary: remove or narrow only import facades that policy, follow-up
  evidence, external inventory, and reviewer approval mark as safe removal
  candidates.
  Preconditions: milestone 005 and milestone 007 complete; scans show no
  unsupported remaining users; behavior and package-boundary tests pass.
  Boundary notes: product-facing specs may be kept even when wrapper-only
  modules are removed.

- Direction id: `direction-022-remove-approved-runtime-compatibility-surfaces`
  Summary: remove or migrate only runtime compatibility files or snapshots
  that policy, follow-up evidence, external inventory, and reviewer approval
  mark as safe removal candidates.
  Preconditions: milestone 006 and milestone 007 complete; old-log/golden,
  repair, healthcheck or non-healthcheck, runtime-owner, fixture, operator, and
  write-timing gates pass for the selected files.
  Boundary notes: no event schema migration unless a later roadmap explicitly
  authorizes it; preserve operator recovery for supported old states.

### 9. [pending] Close The Cleanup Family

Milestone id: `milestone-009-close-cleanup-family`
Depends on: `milestone-008-gated-compatibility-removals`
Intent: Finalize the compatibility cleanup family with current docs,
validation evidence, and an explicit done-or-hold decision.
Completion signal: the final roadmap update records remaining compatibility
surfaces, removed surfaces, deferred surfaces, validation commands, and whether
more cleanup requires a new family.
Coordination notes: completion requires no live rounds, no pending roadmap
updates, no unexplained pending cleanup items, and current validation evidence.
If removal rounds are not approved or external evidence is unavailable, this
milestone should record an explicit hold rather than implying cleanup is done.

Candidate directions:

- Direction id: `direction-023-final-compatibility-surface-report`
  Summary: produce a final report of kept, removed, and deferred compatibility
  surfaces with validation evidence.
  Preconditions: removal rounds are complete or an explicit hold decision is
  selected.
  Boundary notes: do not imply package publication or release approval.

- Direction id: `direction-024-terminal-cleanup-gate`
  Summary: mark the family complete or hold it with explicit blockers.
  Preconditions: final report reviewed and active roadmap bundle re-read.
  Boundary notes: no silent done when pending or newly discovered items remain.
