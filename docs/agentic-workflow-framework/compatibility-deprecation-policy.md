# Compatibility And Deprecation Policy

Status: compatibility and deprecation policy for future external package
candidates, not a code migration, package descriptor migration, release note,
upload approval, package publication decision, deprecation pragma, import
migration, wrapper removal, or compatibility-file migration.

This policy covers the future external package candidates:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

The current source tree still exposes those candidates as internal named
sublibraries of `moifold`. Preferred imports may be documented now, but
moifold-owned compatibility facades stay available until a later selected round
proves that deprecation or removal is safe.

## Evidence Base

Source-backed inputs for this policy:

- `orchestrator/rounds/round-052/import-facade-inventory.md` records the
  selected-facade inventory, current users, Cabal exposure, preferred
  replacements, protecting tests, and unresolved unknowns.
- `orchestrator/rounds/round-054/import-replacement-readiness.md` records the
  selected-facade replacement-readiness scan and conservative `keep`/`defer`
  classifications.
- `orchestrator/rounds/round-056/import-facade-cleanup-policy.md` refreshes
  the selected import scans and Cabal exposure, keeps the round 054
  classifications, and records the gates still missing before deprecation or
  removal.
- `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`
  records the selected runtime compatibility-file inventory, including
  producers, readers, write timing, healthcheck, repair, golden/snapshot
  evidence, protecting tests, and unknowns.
- `orchestrator/rounds/round-055/runtime-file-behavior-gates.md` refreshes
  runtime compatibility-file behavior gates and records conservative
  `keep`/`defer` classifications; no selected runtime surface reached
  `remove-later`.
- `orchestrator/rounds/round-057/runtime-compatibility-cleanup-policy.md`
  refreshes the selected runtime scans and turns the round 053 and round 055
  evidence into this cleanup policy.
- `docs/agentic-workflow-framework/package-extraction-readiness.md` records
  the package ownership split, dependency ownership, current compatibility
  facade status, boundary-test evidence, and remaining moifold-owned blockers.
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
  fixes package names, pre-1.0 version expectations, module namespace policy,
  ownership limits, and the release-gate block.
- `docs/agentic-workflow-framework/release-metadata-policy.md` defines
  metadata, changelog, release-note, and metadata-truth constraints for future
  standalone descriptors and releases.
- `docs/agentic-workflow-framework/implemented-api-freeze.md` freezes the
  implemented internal API surface and the moifold-owned policy boundary.
- `orchestrator/project-contract.md` preserves package ownership,
  compatibility facades, compatibility files, event schemas, golden logs,
  runtime ownership, healthcheck, repair, and release approval as repo-wide
  contracts.
- `moifold.cabal` defines the three internal named sublibraries and exposes
  `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution` as
  product-facing moifold workflow surfaces. It no longer exposes
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, or `CodexWatcher.Workflow.Permission`.
- `src/CodexWatcher/Workflow/Types.hs` and
  `src/CodexWatcher/Workflow/Execution.hs` expose moifold-facing wrappers
  around concrete `MoifoldSpec`, `SomeWatcherState`, concrete effect plans,
  runtime action types, and execution policy.
- `test/Main.hs`, `test/FacadeImportPolicySpec.hs`, and
  `test/BoundaryPolicySpec.hs` contain package-boundary and direct-owner
  assertions for the core, Codex, GitHub, and main moifold library surfaces.

## Preferred Imports

| Package candidate | Preferred reusable-package imports | Compatibility or product-facing imports | Policy |
| --- | --- | --- | --- |
| `agent-workflow-core` | Prefer implemented generic `CodexWatcher.Workflow.*` core modules from the package candidate, including `Spec`, `Indexed.Spec`, `DSL`, `Codec`, `EventLog.Core`, `EventLog.File.Core`, `EventLog.Commit.Core`, `Execution.Core`, `Permission.Core`, `Transaction.Core`, `Audit`, `Daemon.Core`, and `Failure`. | `CodexWatcher.Workflow.Types` and `CodexWatcher.Workflow.Execution` remain moifold product-facing surfaces when they expose `MoifoldSpec`, `SomeWatcherState`, concrete effects, or runtime action types. The old `Workflow.EventLog` and `Workflow.Permission` wrappers are removed. | New reusable core code should import the generic core modules directly. Existing moifold code may continue using the remaining product-facing modules. |
| `agent-workflow-codex` | Prefer `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent`, `CodexWatcher.Workflow.Agent.Ids`, `CodexWatcher.Workflow.Agent.Types`, `CodexWatcher.Workflow.Agent.Codex`, `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Interpreter`, `CodexWatcher.Workflow.Agent.Codex.Protocol`, `CodexWatcher.Workflow.Agent.Codex.Transport`, and `CodexWatcher.Workflow.Observation.Agent`. | The old `CodexWatcher.AppServerClient` wrapper is removed from the main library. | New reusable Codex-adapter guidance should point at the adapter modules directly. |
| `agent-workflow-github` | Prefer `CodexWatcher.Workflow.GitHub.Ids`, `CodexWatcher.Workflow.GitHub.Remote`, and `CodexWatcher.Workflow.GitHub.Command`. | The old `CodexWatcher.Core.Ids` combined convenience wrapper is removed from the main library. | New reusable GitHub-adapter code should import GitHub modules directly. |

Preferred-import guidance is now code-backed for the removed wrappers: current
moifold source and tests use direct owner modules. Runtime compatibility-file
policy is unchanged.

## Runtime Direct-Reader Inventory Refresh

The 2026-05-14 direct cleanup audit refreshed local and downstream
runtime-file readers before terminal closeout. The local scan used:

`rg -n "issue-state\\.json|daemon-state\\.json|planner-state\\.json|planning-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json" . --glob '!dist-newstyle/**' --glob '!orchestrator/worktrees/**' --glob '!orchestrator/rounds/**' --glob '!orchestrator/roadmap-updates/**'`

The downstream scan used `gh search code "\"<file-name>\"" --owner soulomoon
--limit 20`. It found direct readers in `soulomoon/pr-review-watcher-tool` for
`issue-state.json`, `daemon-state.json`, `planner-state.json`,
`watcher-state.json`, `checker-state.json`, `agent-state.json`,
`reviewer-state.json`, and `block-state.json`. It did not find owner-scoped
downstream hits for `planning-state.json`, `repair-state.json`,
`runtime-owner.json`, or `issue-snapshot.json`, but local repo evidence still
shows active producers/readers or operator paths for `runtime-owner.json` and
`issue-snapshot.json`.

This inventory converts the previous external-reader unknown into a concrete
cleanup blocker for the directly read runtime files. Removing or renaming those
files now requires a selected downstream migration, replacement API, or
owner retention decision before the moifold compatibility contract can be
removed cleanly.

## Compatibility Facade Status

| Surface | Current source evidence | Preferred import direction | Allowed current use | Evidence classification | Deprecation and removal status |
| --- | --- | --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | Removed from `moifold.cabal` and source after scans found no concrete source/app/test users. | Reusable Codex adapter users import `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` directly. | None in the current tree. | `removed` | Removed public wrapper; runtime compatibility files unaffected. |
| `CodexWatcher.Core.Ids` | Removed from `moifold.cabal` and source after production and test import burndown migrated safe users to direct agent and GitHub id owners. | Reusable agent code imports `CodexWatcher.Workflow.Agent.Ids`; reusable GitHub code imports `CodexWatcher.Workflow.GitHub.Ids`. | None in the current tree. | `removed` | Removed public wrapper; id newtypes remain available from direct owner modules. |
| `CodexWatcher.Workflow.Types` | Main-library module defines `MoifoldSpec` over `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, concrete effects, replay, and phase validation; round 056 still finds 10 selected-facade imports. | Generic reusable workflow code should import `CodexWatcher.Workflow.Spec` and other core modules directly. | Moifold lifecycle code may continue using this product spec as the concrete bridge from generic workflow contracts to moifold state and events. | `keep` | Not a removal candidate. No deprecation or removal unless a later round proves an approved replacement for the concrete `MoifoldSpec` owner role and behavior parity. |
| `CodexWatcher.Workflow.EventLog` | Removed from `moifold.cabal` and source after remaining policy/parity tests moved to direct event-log core helpers. | Reusable code imports `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit` as needed. | None in the current tree. | `removed` | Removed public wrapper; event JSON `type` fields, replay behavior, and compatibility files are unchanged. |
| `CodexWatcher.Workflow.Execution` | Main-library module bridges generic execution-core metadata to concrete effects, action executors, runtime configs, command reports, and request ids; round 056 still finds 4 selected-facade imports. | Reusable execution code should import `CodexWatcher.Workflow.Execution.Core`. | Existing moifold runtime and effect-interpreter code may keep using the concrete execution facade. | `keep` | Not a removal candidate. Concrete runtime action types and command/report behavior remain product-owned. |
| `CodexWatcher.Workflow.Permission` | Removed from `moifold.cabal` and source after remaining policy/parity tests moved to `CodexWatcher.Workflow.Permission.Core` and `WorkflowSpec` policy helpers. | Reusable permission code imports `CodexWatcher.Workflow.Permission.Core`. | None in the current tree. | `removed` | Removed public wrapper; phase validation behavior is unchanged. |

## Runtime Compatibility-File Cleanup Policy

The event log remains workflow truth. Runtime compatibility files are
moifold-owned operator/runtime contracts derived from event-log state,
runtime ownership state, repair execution, or live issue-planning snapshots.
They are not reusable-package APIs, and package extraction does not move their
names, schemas, field meanings, write timing, repair behavior, healthcheck
behavior, or operator recovery policy into `agent-workflow-core`,
`agent-workflow-codex`, or `agent-workflow-github`.

This policy classifies cleanup readiness only. It does not approve migration,
removal, filename changes, schema changes, write-timing changes, event JSON
`type` changes, repair redesign, healthcheck redesign, runtime behavior
changes, roadmap expansion, import-facade changes, or removal approval.

| Surface | Classification | Evidence basis | Missing gates before later deprecation, migration, or removal |
| --- | --- | --- | --- |
| `issue-state.json` | `migrated; downstream-accepted` | Normal local file writers were removed: launch/fanout/reconciliation/PR-handoff/daemon transaction paths append event logs and keep only pure healthcheck projections. Healthcheck projects `issueState` from event replay instead of reading this file directly. The old checked-in issue-implementation compatibility snapshots and `CodexWatcher.Snapshot`/`CodexWatcher.GoldenReplay` bridge were removed after fixture-by-fixture event-log bootstrap coverage was added under `golden/event-log/bootstrapped`. The 2026-05-14 inventory found direct downstream readers in `soulomoon/pr-review-watcher-tool`; those readers migrated in merged PR `soulomoon/pr-review-watcher-tool#1`. | No remaining downstream gate for terminal cleanup. |
| `daemon-state.json` | `migrated; downstream-accepted` | Normal local file writers were removed from daemon transactions, daemon-loop idle/terminal paths, launch/reconciliation paths, and repair execution. Healthcheck projects `daemonState` from event replay instead of reading this file directly. Active/stopped runtime-compatibility fixtures remain as current projection fixtures, while old snapshot readers were deleted. `scripts/restart-watcher` no longer removes the stale legacy file. The 2026-05-14 inventory found direct downstream readers in `soulomoon/pr-review-watcher-tool`; those readers migrated in merged PR `soulomoon/pr-review-watcher-tool#1`. | No remaining downstream gate for terminal cleanup. |
| `planner-state.json` | `migrated; downstream-accepted` | Round 087 records this as the issue-planning summary/status surface. Normal local file writers were removed; the remaining production path is a pure event-replay projection surfaced under healthcheck `plannerState`. The 2026-05-14 inventory found direct downstream readers in `soulomoon/pr-review-watcher-tool`; those readers migrated in merged PR `soulomoon/pr-review-watcher-tool#1`. | No remaining downstream gate for terminal cleanup. |
| `planning-state.json` | `removed` | No owner-scoped downstream hits were found; healthcheck never read it; `RecordPlanningGraph` now compiles to no runtime write; issue-planning compatibility projection writes only `planner-state.json`; the checked-in `planning-state.json` fixture was deleted; tests guard the absence of direct and projection writes. Planning graph truth remains in the event log through `IssuePlanningGraphUpdated` and replayed watcher state. | No remaining removal gate for this file. Restoring it would require a selected compatibility round with a supported reader contract, old-log evidence, and fixture coverage. |
| PR review state files and PR URL fields | `migrated; downstream-accepted` | Round 053 maps the selected surface to current `watcher-state.json`, `checker-state.json`, optional `agent-state.json`, `reviewer-state.json`, `issue-state.json` `pr_url`, and PR review config `prUrl`; no dedicated `pr-url` or `pr-state` file producer was found. Normal local file writers for these PR-review state files were removed; healthcheck now projects PR-review `states` keys from event replay. Old golden PR-review compatibility snapshots were migrated to explicit bootstrapped event-log fixtures covering merged, unresolved, blocked, and clean-ready states. The 2026-05-14 inventory found direct downstream readers in `soulomoon/pr-review-watcher-tool`; those readers migrated in merged PR `soulomoon/pr-review-watcher-tool#1`. | No remaining downstream gate for terminal cleanup. No dedicated PR URL/state path exists in current producers. |
| `block-state.json` | `migrated; downstream-accepted` | Direct `RecordBlocked` planned writes, normal compatibility-file writes, and the automatic-loop invalid-event-log repair-failure writer were removed. Healthcheck projects normal blocked state from event replay instead of reading this file directly. Successful repair still removes stale block state left by older runs, but `scripts/restart-watcher` no longer removes or relies on the stale legacy file. Old checked-in blocked snapshots were migrated to event-log fixtures; the dedicated repair-failure fixture was deleted with the writer. The 2026-05-14 inventory found direct downstream readers in `soulomoon/pr-review-watcher-tool`; those readers migrated in merged PR `soulomoon/pr-review-watcher-tool#1`. | No remaining downstream gate for terminal cleanup. |
| `repair-state.json` | `keep-as-product` | The single producer in `repair-invalid-state --execute` archives the invalid log, writes repaired `events.jsonl`, writes `repair-state.json`, then removes stale `block-state.json`; it no longer rewrites compatibility files. Round 055 records no production reader, no healthcheck reader, and no checked-in fixture; tests protect dry-run/execute source-order behavior. Round 065 records the explicit current non-healthcheck policy: healthcheck does not read this repair summary output. The 2026-05-14 local candidate decision classifies it as a moifold repair diagnostic, not a compatibility alias. | No removal is required for public facade cleanup. Any future replacement must preserve repair execute-order diagnostics or explicitly replace that product contract. |
| `runtime-owner.json` | `keep-as-product` | Round 053 records runtime owner store and CLI producers/readers, automatic-loop validation and renewal, healthcheck surfacing, and `scripts/restart-watcher` shell parsing/removal. Tests protect current lease JSON parsing, rejection of old owner-only shapes, running-lease rejection, and current-process cleanup. Round 055 keeps this as live daemon ownership state. Round 089 records the current healthcheck contract without changing behavior: healthcheck reads this file as `runtimeOwner` for issue planning, issue implementation, and PR review; runtime-owner production writes lease-shaped JSON under top-level `lease`; and summary owner lookup remains `["runtimeOwner","owner"]`, not `["runtimeOwner","lease","runtime"]`. The 2026-05-14 local candidate decision classifies it as the live daemon lease contract. | Retain until a selected replacement lease mechanism lands with healthcheck, restart, runtime owner, and automatic-loop evidence. |
| Checked-in compatibility snapshots | `removed` | The old `golden/pr-review/*` and `golden/issue-implement/*` compatibility snapshot JSON fixtures were migrated to explicit bootstrapped event-log fixtures under `golden/event-log/bootstrapped`, and `CodexWatcher.Snapshot` plus `CodexWatcher.GoldenReplay` were removed from source, Cabal exposure, and tests. `goldenEventLogCases` now replays those bootstrapped fixtures directly. | No remaining removal gate for checked-in compatibility snapshots. Restoring snapshot-reader support would require a selected compatibility round with new owner approval. |
| Live `issue-snapshot.json` | `keep-as-product` | Round 053 records live issue-planning snapshot production before planner turn start, and tests protect snapshot write timing plus closed-scope completion without starting a planner turn. Round 055 records no checked-in live `issue-snapshot.json` fixture and no healthcheck reader. The 2026-05-14 local candidate decision classifies it as live planner input because prompt rendering tells planners to read this file and tests protect the deterministic shape. | Retain until a selected replacement planner-input path lands with write-timing, prompt, fixture, and closed-scope behavior evidence. |

## Downstream Runtime-State Migration Contract

The supported read-only migration path for downstream status or health tooling
is `moifold healthcheck --state-root /workspace/artifacts --repo owner/name`.
The report preserves the legacy runtime-state projection shape under stable
`watchers[].states.*` keys, now deriving compatibility state from event replay
instead of direct compatibility-file reads. The exact file-to-JSON mapping and
downstream reader classification are recorded in
`docs/agentic-workflow-framework/downstream-runtime-state-migration.md` and
guarded by `healthcheckRuntimeStateMigrationContractTests`.

This replacement path covers read-only health/status consumers. The downstream
audit patch routes both read-only health/status commands and legacy daemon
launchers through the Haskell moifold healthcheck and `run-*` commands, and was
accepted in merged PR `soulomoon/pr-review-watcher-tool#1`. Local moifold
healthcheck no longer directly reads compatibility files, and normal plus
repair-failure local compatibility-file writers have been removed; checked-in
compatibility snapshot readers/fixtures have also been removed after migration
to bootstrapped event-log fixtures. `scripts/restart-watcher` and the operator
runbook no longer depend on stale compatibility files. The remaining product
files, `repair-state.json`, `runtime-owner.json`, and live
`issue-snapshot.json`, are explicitly retained product contracts outside the
compatibility-file removal goal. No downstream runtime-file blocker remains
for terminal cleanup.

## Local Runtime-File Candidate Decisions

The local runtime-file candidates without owner-scoped downstream search hits
are classified in
`docs/agentic-workflow-framework/local-runtime-file-candidates.md` and guarded
by `localRuntimeFileCandidateDecisionTest`.

- `planning-state.json` is `removed`; planning graph persistence is event-log
  and replay state, not a runtime compatibility file.
- `repair-state.json` is `keep-as-product` as a repair diagnostic output.
- `runtime-owner.json` is `keep-as-product` as the live daemon lease contract.
- `issue-snapshot.json` is `keep-as-product` as live planner input.

Future rounds must preserve the round 055 classifications unless refreshed
source, fixture, old-log, repair, healthcheck, write-timing, and external
operator evidence proves a stronger classification. `remove-later` means only
that a later selected removal round may be proposed; it is not removal
approval. The current evidence classifies no selected runtime compatibility
surface as `remove-later`.

Before any runtime compatibility-file deprecation, migration, or removal is
selected, the future round must name the exact file, field, or snapshot
surface and prove every applicable gate:

- old-log and golden replay/bootstrap behavior for historical event logs and
  any retained bootstrapped event-log fixtures;
- repair behavior, including `repair-invalid-state --execute` ordering,
  compatibility rewrite behavior, and stale `block-state.json` handling;
- healthcheck behavior, including read-only reporting or an explicit reviewed
  reason the selected file is not healthcheck-owned;
- write timing, including event append ordering, launch/fanout ordering,
  startup/reconciliation ordering, runtime-owner lease timing, and live
  snapshot-before-turn-start timing when applicable;
- fixture coverage for every old and current JSON shape that remains
  supported or is intentionally rejected;
- external operator, runbook, script, and downstream direct-reader inventory;
- focused behavior tests and baseline build/test validation;
- reviewer approval that names the exact surface and confirms this policy is
  satisfied.

## Compatibility Rules

- Compatibility wrappers stay available until a later selected deprecation or
  removal round proves safety and receives reviewer approval.
- A preferred-import policy is not a deprecation pragma, not a warning policy,
  not an import migration, not wrapper removal approval, and not standalone
  package publication approval.
- Remaining compatibility files keep their current names and meanings,
  including `issue-state.json`, `daemon-state.json`, PR URL files, block state,
  repair state, and runtime owner files. The removed `planning-state.json`
  runtime file and checked-in compatibility snapshots are no longer supported
  compatibility surfaces.
- Event schemas, event JSON `type` fields, schema versions, golden logs,
  replay policy, dry-run rendering, action ordering, request-id progression,
  prompt schemas, structured-output compatibility, runtime ownership,
  healthcheck, repair, and operator recovery remain moifold-owned.
- Reusable packages may document and expose typed workflow, adapter, parser,
  command-spec, permission, transaction, and effect-plan contracts. They do not
  inherit moifold lifecycle authority by being extracted.
- Package descriptors, release metadata, source-distribution artifacts, public
  documentation, release notes, and changelog entries must preserve this
  ownership split.

## Deprecation Readiness Gates

Before adding any deprecation pragma, warning, migration warning, or public
deprecation note for a wrapper, facade, compatibility file, or old import path,
a future round must prove:

- preferred imports are documented for the affected surface;
- current source import coverage is known, including internal moifold imports
  and any downstream consumers in scope for the round;
- consumers have a concrete migration path with replacement imports and any
  required behavior notes;
- package descriptors, README/Haddock docs, changelog policy, and release-note
  text agree on the surface status;
- compatibility files and event schemas are unaffected, or their migration is
  separately selected and proven;
- behavior checks still pass, including focused compatibility tests when the
  surface affects replay, runtime execution, permissions, dry-run rendering, or
  command rendering;
- reviewer approval explicitly names the surface as ready for deprecation.

The removed public wrappers skipped deprecation pragmas because the selected
cleanup removed the exposed modules outright after current import scans and
direct-owner migrations. Remaining runtime compatibility files still require
the gates below.

## Removal Gates

Before removing any wrapper module, facade, compatibility file, old import
path, exposed module, descriptor entry, or compatibility behavior, a future
round must be selected specifically for removal and must provide:

- import-scan evidence showing no unsupported remaining users of the old path;
- build evidence for the relevant package candidates and moifold product;
- focused behavior evidence for the affected compatibility path;
- old-log and golden-fixture evidence when event logs, replay, schemas, or
  compatibility files are relevant;
- dry-run rendering, action ordering, prompt schema, structured-output, command
  rendering, healthcheck, or repair evidence when those contracts are touched;
- changelog and release-note evidence when the change is externally visible;
- package descriptor and documentation evidence when exposed modules or package
  surfaces change;
- reviewer approval that names the removed surface and confirms every required
  gate is satisfied.

Removal is blocked unless every applicable gate is satisfied. Missing evidence
means a remaining compatibility surface stays available.

## Release-Note Constraints

Future release notes may describe preferred imports and compatibility status
only after this policy exists and only when the described implementation has
landed. Release notes must:

- call out pre-1.0 package status for `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`;
- distinguish reusable package APIs from moifold-owned lifecycle, runtime,
  prompt, healthcheck, repair, compatibility-file, event-schema, and release
  policy;
- state compatibility-facade status accurately, including whether a facade is
  still available, merely documented as compatibility-only, deprecated, or
  removed by an approved later round;
- avoid implying package upload, source-distribution approval, CI readiness,
  public API stability beyond the approved contract, deprecation pragma
  readiness, import migration completion, or facade removal unless a
  release-gate round has approved that exact claim.

Release notes are metadata. They cannot by themselves authorize deprecation,
removal, descriptor migration, source movement, package upload, or public
release.
