# Follow-Up Discovery

Round: `round-058`
Milestone: `milestone-004-expand-follow-up-backlog`
Direction: `direction-007-follow-up-discovery`
Extracted item: `round-058-follow-up-discovery`

This artifact is evidence-only. It proposes candidate cleanup or evidence
items for a later roadmap expansion decision. It does not edit or publish a
roadmap revision, change source, rewrite imports, change runtime compatibility
files, change docs policy, add deprecation pragmas, alter Cabal descriptors or
exposed-modules, authorize package publication, authorize migration, or
authorize removal.

## Scope And Non-Goals

In scope:

- read the completed artifacts and reviews from rounds 052-057;
- refresh focused scans for selected import facades and runtime compatibility
  files;
- identify compact, source-backed candidate items for a later roadmap update;
- record blockers and recommended placement before terminal cleanup rounds.

Out of scope:

- no roadmap edits or roadmap revision publication;
- no source, test, fixture, script, docs policy, project-contract, Cabal, or
  import-surface edits;
- no runtime compatibility-file migration, filename change, schema change,
  write-timing change, event JSON `type` change, healthcheck redesign, repair
  redesign, or runtime behavior change;
- no deprecation pragma, removal approval, package upload, or release gate
  claim.

## Inputs Read

- `orchestrator/rounds/round-058/selection.md`
- `orchestrator/rounds/round-058/plan.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`
- `orchestrator/project-contract.md`
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
- `orchestrator/rounds/round-052/import-facade-inventory.md`
- `orchestrator/rounds/round-052/review.md`
- `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`
- `orchestrator/rounds/round-053/review.md`
- `orchestrator/rounds/round-054/import-replacement-readiness.md`
- `orchestrator/rounds/round-054/review.md`
- `orchestrator/rounds/round-055/runtime-file-behavior-gates.md`
- `orchestrator/rounds/round-055/review.md`
- `orchestrator/rounds/round-056/import-facade-cleanup-policy.md`
- `orchestrator/rounds/round-056/review.md`
- `orchestrator/rounds/round-057/runtime-compatibility-cleanup-policy.md`
- `orchestrator/rounds/round-057/review.md`

Focused source/test reads used for confirmation:

- `src/CodexWatcher/Runtime/Compatibility.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/Cli/Command/Replay.hs`
- `src/CodexWatcher/Runtime/Owner/Store.hs`
- `src/CodexWatcher/Runtime/Owner/Cli.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `scripts/restart-watcher`

## Scan Evidence

Import facade scans:

```text
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
```

Current exact selected-facade import counts match rounds 054 and 056:

| Surface | Current exact imports | Standalone package/examples regression |
| --- | ---: | --- |
| `CodexWatcher.AppServerClient` | 28 | none |
| `CodexWatcher.Core.Ids` | 65 | none |
| `CodexWatcher.Workflow.Types` | 10 | none |
| `CodexWatcher.Workflow.EventLog` | 3 | none |
| `CodexWatcher.Workflow.Execution` | 4 | none |
| `CodexWatcher.Workflow.Permission` | 1 | none |

The Cabal exposure scan still shows the six selected facades exposed by the
main `moifold` library and the preferred replacement modules exposed by the
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates. This is evidence for later planning only; it is not a
Cabal change request.

Runtime compatibility-file scans:

```text
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\.json|daemon-state\.json|planning-state\.json|pr-url|pr state|PR URL|pr_url|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|block-state\.json|repair-state\.json|runtime-owner\.json|runtime owner|compatibility snapshot|issue-snapshot\.json|snapshot" src app test scripts docs examples golden orchestrator
rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\.json|Healthcheck|healthcheck|runtime-owner\.json|RuntimeOwner|issue-snapshot\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
```

The filename scan still finds only these selected checked-in compatibility
fixtures:

- `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`
- `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`
- `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`
- `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`
- `golden/pr-review/mlf2-pr6-blocked/block-state.json`

No checked-in fixture named `planning-state.json`, `repair-state.json`,
`runtime-owner.json`, dedicated `*pr-url*`, dedicated `*pr-state*`, or live
`issue-snapshot.json` was found. Source reads confirmed the current producer
and reader shape:

- `src/CodexWatcher/Runtime/Compatibility.hs` writes `planning-state.json`,
  `issue-state.json`, `daemon-state.json`, PR review state files, and
  `block-state.json` through compatibility projections.
- `src/CodexWatcher/Healthcheck.hs` reads `planner-state.json`,
  `issue-state.json`, PR review state files, shared `daemon-state.json`,
  shared `block-state.json`, and shared `runtime-owner.json`; it does not list
  `planning-state.json`, `repair-state.json`, or live `issue-snapshot.json` in
  `stateFileSpecs`.
- `src/CodexWatcher/Cli/Command/Replay.hs` writes `repair-state.json`, then
  rewrites compatibility files, then removes stale `block-state.json` in the
  execute repair path.
- `src/CodexWatcher/Runtime/Owner/Store.hs` writes and reads
  `runtime-owner.json` with a top-level `lease` object, while
  `scripts/restart-watcher` also parses and removes that file.
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` writes live
  `issue-snapshot.json` before planner turn start in execute mode.

## Candidate Cleanup Items

### 1. `CodexWatcher.Core.Ids` Split-Import Evidence

- Surface: `CodexWatcher.Core.Ids`
- Evidence source paths: `orchestrator/rounds/round-052/import-facade-inventory.md`,
  `orchestrator/rounds/round-054/import-replacement-readiness.md`,
  `orchestrator/rounds/round-056/import-facade-cleanup-policy.md`, refreshed
  import count scan.
- Current classification: `defer`
- Blocker: 65 current repo-local imports still use the combined facade, and no
  per-import split plan exists for agent ids versus GitHub ids.
- Recommended later milestone/direction type: add an import-facade evidence
  direction before terminal removal, focused on a per-import ownership map and
  migration-risk report.
- Why this is not current migration or removal approval: the combined facade is
  still public, still widely used, and later work must prove behavior and
  downstream compatibility before changing imports or exposure.

### 2. `CodexWatcher.AppServerClient` Migration-Readiness Evidence

- Surface: `CodexWatcher.AppServerClient`
- Evidence source paths: rounds 052, 054, and 056 artifacts; refreshed import
  count scan; `test/Main.hs`, `test/AppServerSpec.hs`, and `test/CliSpec.hs`
  cited by round 056.
- Current classification: `defer`
- Blocker: 28 current repo-local imports still use the facade; the current
  evidence proves adapter ownership and replacement module exposure, not a
  complete production import migration.
- Recommended later milestone/direction type: add a dry-run migration-readiness
  direction that groups each use by client/transport/parser type ownership.
- Why this is not current migration or removal approval: the facade remains the
  moifold compatibility path until a later selected round proves migration
  safety and behavior parity.

### 3. `CodexWatcher.Workflow.EventLog` Concrete Helper Boundary

- Surface: `CodexWatcher.Workflow.EventLog`
- Evidence source paths: rounds 052, 054, and 056 artifacts; refreshed import
  count scan; `src/CodexWatcher/Workflow/EventLog.hs`.
- Current classification: `defer`
- Blocker: only three current selected-facade imports remain, but the module
  owns concrete moifold helpers around `WatcherEvent`, replay policy, and
  failure formatting; old-log and golden behavior evidence is still required.
- Recommended later milestone/direction type: add an event-log concrete-helper
  boundary direction that proves which helpers, if any, can move behind
  preferred core imports while preserving replay/golden behavior.
- Why this is not current migration or removal approval: low import count is
  not enough evidence; event-log behavior and old fixtures are compatibility
  contracts.

### 4. `CodexWatcher.Workflow.Permission` Public API Review

- Surface: `CodexWatcher.Workflow.Permission`
- Evidence source paths: rounds 052, 054, and 056 artifacts; refreshed import
  count scan; `test/Main.hs`.
- Current classification: `defer`
- Blocker: repo-local production imports are absent, but the module remains
  public and bridges concrete moifold permission policy over `MoifoldSpec`.
- Recommended later milestone/direction type: add a public-API review direction
  for downstream-user inventory and concrete permission behavior parity.
- Why this is not current migration or removal approval: a public exposed
  module with concrete behavior cannot be treated as removable solely because
  production imports are low.

### 5. `planning-state.json` Fixture And Healthcheck Policy Evidence

- Surface: `planning-state.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Runtime/Compatibility.hs`;
  `src/CodexWatcher/EffectInterpreter.hs`; `src/CodexWatcher/Healthcheck.hs`.
- Current classification: `defer`
- Blocker: no checked-in old `planning-state.json` fixture was found, and
  healthcheck does not read this file by current design.
- Recommended later milestone/direction type: add a runtime evidence direction
  to choose between explicit non-healthcheck policy plus fixture evidence, or
  healthcheck ownership evidence if behavior changes are separately selected.
- Why this is not current migration or removal approval: write paths are active
  and tested; missing fixture/healthcheck evidence blocks stronger cleanup
  claims.

### 6. `repair-state.json` Fixture, Reader, And Healthcheck Policy Evidence

- Surface: `repair-state.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Cli/Command/Replay.hs`; `src/CodexWatcher/Healthcheck.hs`.
- Current classification: `defer`
- Blocker: execute repair writes the file, but no production reader,
  healthcheck reader, or checked-in fixture was found.
- Recommended later milestone/direction type: add a repair-output evidence
  direction that records fixture round-trip coverage and an explicit
  healthcheck or non-healthcheck policy.
- Why this is not current migration or removal approval: the repair write order
  is a protected behavior, and missing reader/fixture evidence must stay
  visible before any later cleanup proposal.

### 7. `runtime-owner.json` Fixture And Operator Script Inventory

- Surface: `runtime-owner.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Runtime/Owner/Store.hs`;
  `src/CodexWatcher/Runtime/Owner/Cli.hs`; `src/CodexWatcher/Healthcheck.hs`;
  `scripts/restart-watcher`; `docs/watcher-agent-runbook/project-watch/01-preflight.md`;
  `docs/watcher-agent-runbook/checklists/operator-checklist.md`.
- Current classification: `keep`
- Blocker: no checked-in owner fixture exists; healthcheck reads
  `runtimeOwner`, writer emits `lease.runtime`, and shell/operator consumers
  still parse or mention the file.
- Recommended later milestone/direction type: add a runtime-owner evidence
  direction for checked-in fixture coverage, field-path readback, and operator
  script/runbook inventory.
- Why this is not current migration or removal approval: this file is live
  daemon ownership state and must remain stable unless a later selected round
  proves every ownership and operator gate.

### 8. `daemon-state.json` Active/Stopped Fixture Evidence

- Surface: `daemon-state.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Runtime/Compatibility.hs`;
  `src/CodexWatcher/Healthcheck.hs`; `scripts/restart-watcher`.
- Current classification: `keep`
- Blocker: the checked-in incomplete issue fixture covers an older tolerated
  shape, but there is still no checked-in active daemon fixture with current
  active fields and no stopped daemon fixture.
- Recommended later milestone/direction type: add a daemon-state fixture
  evidence direction before any terminal cleanup involving daemon summaries.
- Why this is not current migration or removal approval: current healthcheck,
  repair, restart cleanup, and compatibility projection still use the file.

### 9. PR URL/State External Path Inventory

- Surface: PR review state files and PR URL fields, including absent dedicated
  `*pr-url*` and `*pr-state*` paths.
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Runtime/Compatibility.hs`;
  `src/CodexWatcher/Snapshot.hs`; golden PR-review fixtures.
- Current classification: `keep` for current PR review state files and `defer`
  for absent dedicated PR URL file wording.
- Blocker: no dedicated PR URL/state file producer was found, but external
  operator or downstream path expectations have not been inventoried.
- Recommended later milestone/direction type: add an external-path inventory
  direction that checks runbooks, scripts, and downstream/operator references
  before concluding the absent paths need no compatibility handling.
- Why this is not current migration or removal approval: current PR review
  state files remain active compatibility outputs, and absent path evidence is
  a discovery question, not a deletion decision.

### 10. `block-state.json` Repair-Failure Fixture Evidence

- Surface: `block-state.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Runtime/Compatibility.hs`;
  `src/CodexWatcher/EffectInterpreter.hs`;
  `src/CodexWatcher/AutomaticLoop/Runner.hs`; `src/CodexWatcher/Healthcheck.hs`.
- Current classification: `keep`
- Blocker: checked-in blocked fixtures exist for normal blocked paths, but no
  checked-in fixture for the runner repair-failure `block-state.json` shape was
  found.
- Recommended later milestone/direction type: add a focused fixture-evidence
  direction for repair-failure block-state output.
- Why this is not current migration or removal approval: direct blocked writes,
  compatibility projection, healthcheck reads, and repair-success stale-block
  cleanup are all current behavior.

### 11. Live `issue-snapshot.json` Fixture And Write-Timing Evidence

- Surface: live `issue-snapshot.json`
- Evidence source paths: rounds 053, 055, and 057 artifacts; refreshed filename
  scan; `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`; `test/Main.hs`.
- Current classification: `defer`
- Blocker: write timing before planner turn start is tested, but there is no
  checked-in live `issue-snapshot.json` fixture and no healthcheck reader.
- Recommended later milestone/direction type: add a live-snapshot evidence
  direction for fixture coverage and explicit write-timing migration gates.
- Why this is not current migration or removal approval: issue-planning
  snapshot timing is a live workflow contract and must remain stable.

### 12. External Operator/Downstream Compatibility Inventory

- Surface: cross-cutting import facades and runtime compatibility files.
- Evidence source paths: rounds 052-057 artifacts and
  `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
- Current classification: mixed `keep` and `defer`; no selected surface is
  classified as `remove-later`.
- Blocker: local scans cover the repository, examples, package candidates, and
  checked-in docs/fixtures, but external operator scripts and downstream users
  are repeatedly named as missing evidence.
- Recommended later milestone/direction type: add a manual external-inventory
  direction before terminal cleanup selection.
- Why this is not current migration or removal approval: local evidence alone
  cannot prove that old public imports, state-file paths, and operator
  workflows are unused outside this worktree.

## Rejected Or Deferred Non-Candidates

- `CodexWatcher.Workflow.Types`: keep as product-facing `MoifoldSpec` owner.
  Candidate work may later document its owner role, but current evidence does
  not support treating it as a removal candidate.
- `CodexWatcher.Workflow.Execution`: keep as concrete execution bridge for
  moifold effect compilation, runtime request ids, dry-run/execute reports,
  action reports, and failure classification.
- `issue-state.json`: keep as a current operator/runtime contract. A later
  evidence item may gather old live state-directory matrices, but this round
  does not propose migration or removal.
- Checked-in compatibility snapshots: defer as a broad class. Any future item
  should be fixture-by-fixture rather than a blanket cleanup.
- Package publication, package upload, release notes, deprecation warning
  policy, exposed-module removal, event schema changes, and compatibility-file
  schema changes are non-candidates for this discovery round.

## Blockers And Required Evidence

Cross-cutting blockers before any later deprecation, migration, or removal
selection:

- refreshed exact import scans and package-boundary checks for selected import
  facades;
- downstream/public-user inventory for public facades;
- per-import ownership maps for mixed facades such as `CodexWatcher.Core.Ids`;
- old-log and golden replay evidence for event-log or snapshot behavior;
- checked-in fixture coverage for weakly represented runtime files:
  `planning-state.json`, `repair-state.json`, `runtime-owner.json`, active and
  stopped `daemon-state.json`, repair-failure `block-state.json`, and live
  `issue-snapshot.json`;
- explicit healthcheck ownership or non-healthcheck policy for files not read
  by `src/CodexWatcher/Healthcheck.hs`;
- repair behavior evidence where `repair-invalid-state --execute` writes,
  rewrites, or removes compatibility files;
- write-timing evidence for daemon compatibility projection, runtime-owner
  lease timing, and live issue snapshot creation;
- external operator/runbook/script inventory for direct file readers and shell
  parsers.

## Recommended Milestone Placement

Recommended roadmap expansion shape:

- add a small import-facade follow-up milestone before
  `milestone-005-gated-compatibility-removals`, covering candidates 1-4;
- add a runtime compatibility evidence milestone before terminal cleanup,
  covering candidates 5-11;
- add one cross-cutting external operator/downstream inventory direction before
  any final selected removal round, covering candidate 12;
- keep final removal work in the existing gated-removal milestone only after a
  reviewer accepts the exact surface evidence for that later selected item.

## Roadmap Expansion Handoff Notes

The next roadmap-update role should preserve these constraints:

- candidates are proposals for later roadmap expansion only;
- no selected surface from rounds 056-057 is upgraded to deprecation,
  migration, or removal readiness by this artifact;
- current classifications remain `keep` or `defer`; no selected runtime
  compatibility surface is `remove-later`;
- local validation in this artifact is not a future release gate;
- any later terminal cleanup direction must name exact surfaces and required
  gates rather than using this discovery artifact as blanket approval.
