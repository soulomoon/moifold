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
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`,
  `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`
  from the main moifold library.
- `src/CodexWatcher/AppServerClient.hs` reexports
  `CodexWatcher.Workflow.Agent.Codex.Client` and
  `CodexWatcher.Workflow.Agent.Codex.Transport`.
- `src/CodexWatcher/Core/Ids.hs` reexports
  `CodexWatcher.Workflow.Agent.Ids` and
  `CodexWatcher.Workflow.GitHub.Ids`.
- `src/CodexWatcher/Workflow/Types.hs`,
  `src/CodexWatcher/Workflow/EventLog.hs`,
  `src/CodexWatcher/Workflow/Execution.hs`, and
  `src/CodexWatcher/Workflow/Permission.hs` expose moifold-facing wrappers
  around concrete `MoifoldSpec`, `WatcherEvent`, `SomeWatcherState`,
  concrete effect plans, runtime action types, replay behavior, and phase
  permission validation.
- `test/Main.hs` contains recursive package-boundary and facade assertions for
  the core, Codex, GitHub, and main moifold library surfaces.

## Preferred Imports

| Package candidate | Preferred reusable-package imports | Compatibility or product-facing imports | Policy |
| --- | --- | --- | --- |
| `agent-workflow-core` | Prefer implemented generic `CodexWatcher.Workflow.*` core modules from the package candidate, including `Spec`, `Indexed.Spec`, `DSL`, `Codec`, `EventLog.Core`, `EventLog.File.Core`, `EventLog.Commit.Core`, `Execution.Core`, `Permission.Core`, `Transaction.Core`, `Audit`, `Daemon.Core`, and `Failure`. | `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission` are moifold product or adapter facades when they expose `MoifoldSpec`, `WatcherEvent`, `SomeWatcherState`, concrete effects, runtime action types, phase validation, or compatibility behavior. | New reusable core code should import the generic core modules directly. Existing moifold code may continue using the product-facing modules. This policy does not add deprecation pragmas or authorize removal. |
| `agent-workflow-codex` | Prefer `CodexWatcher.AppServerProtocol`, `CodexWatcher.Workflow.Agent`, `CodexWatcher.Workflow.Agent.Ids`, `CodexWatcher.Workflow.Agent.Types`, `CodexWatcher.Workflow.Agent.Codex`, `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Interpreter`, `CodexWatcher.Workflow.Agent.Codex.Protocol`, `CodexWatcher.Workflow.Agent.Codex.Transport`, and `CodexWatcher.Workflow.Observation.Agent`. | `CodexWatcher.AppServerClient` is a moifold-owned compatibility facade over `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. | New reusable Codex-adapter guidance should point at the adapter modules directly. Existing imports through `CodexWatcher.AppServerClient` remain allowed until a later deprecation or removal round proves safety. |
| `agent-workflow-github` | Prefer `CodexWatcher.Workflow.GitHub.Ids`, `CodexWatcher.Workflow.GitHub.Remote`, and `CodexWatcher.Workflow.GitHub.Command`. | `CodexWatcher.Core.Ids` is a moifold convenience facade over agent ids and GitHub ids, not the preferred public import for standalone reusable package consumers. | New reusable GitHub-adapter code should import GitHub modules directly. Existing moifold code may keep using `CodexWatcher.Core.Ids` where the combined id facade is useful. |

Preferred-import guidance is documentation only. It is not an import migration,
not a Cabal descriptor migration, not a deprecation warning, and not a
compatibility promise that old paths can be removed. It is guidance for
reusable package consumers; existing moifold imports may continue using the
compatibility or product-facing modules while the relevant `keep` or `defer`
classification remains in force.

## Compatibility Facade Status

| Surface | Current source evidence | Preferred import direction | Allowed current use | Evidence classification | Deprecation and removal status |
| --- | --- | --- | --- | --- | --- |
| `CodexWatcher.AppServerClient` | Main-library module reexports `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; round 056 still finds 28 selected-facade imports and no selected-facade imports under standalone package candidates or examples. | Reusable Codex adapter users should import `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport` directly. | Existing moifold and downstream imports may continue through the old facade. | `defer` | No deprecation pragma, import migration requirement, Cabal exposure change, or removal approval. A later selected round must satisfy the gates. |
| `CodexWatcher.Core.Ids` | Main-library module reexports `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids`; round 056 still finds 65 selected-facade imports. | Reusable agent code should import `CodexWatcher.Workflow.Agent.Ids`; reusable GitHub code should import `CodexWatcher.Workflow.GitHub.Ids`. | Existing moifold code may continue using the combined convenience facade. | `defer` | No deprecation or removal until combined-facade users have split-import evidence, behavior checks, and reviewer approval. |
| `CodexWatcher.Workflow.Types` | Main-library module defines `MoifoldSpec` over `SomeWatcherState`, `WatcherEvent`, `DaemonObservation`, concrete effects, replay, and phase validation; round 056 still finds 10 selected-facade imports. | Generic reusable workflow code should import `CodexWatcher.Workflow.Spec` and other core modules directly. | Moifold lifecycle code may continue using this product spec as the concrete bridge from generic workflow contracts to moifold state and events. | `keep` | Not a removal candidate. No deprecation or removal unless a later round proves an approved replacement for the concrete `MoifoldSpec` owner role and behavior parity. |
| `CodexWatcher.Workflow.EventLog` | Main-library module exposes generic event-log helpers plus moifold-specific helpers such as `initializeMoifoldWorkflow`, `applyMoifoldWorkflowEvent`, and `replayMoifoldWorkflowEvents`; round 056 still finds 3 selected-facade imports. | Reusable code should import `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit` as needed. | Existing moifold code may continue using the facade for concrete event-log and audit behavior. | `defer` | No deprecation or removal while concrete `WatcherEvent`, replay policy, old-log, golden-fixture, and compatibility behavior evidence remains missing. |
| `CodexWatcher.Workflow.Execution` | Main-library module bridges generic execution-core metadata to concrete effects, action executors, runtime configs, command reports, and request ids; round 056 still finds 4 selected-facade imports. | Reusable execution code should import `CodexWatcher.Workflow.Execution.Core`. | Existing moifold runtime and effect-interpreter code may keep using the concrete execution facade. | `keep` | Not a removal candidate. Concrete runtime action types and command/report behavior remain product-owned. |
| `CodexWatcher.Workflow.Permission` | Main-library module bridges `CodexWatcher.Workflow.Permission.Core` to concrete moifold phase validation, `SomeWatcherState`, `EffectPlan`, and `MoifoldSpec`; round 056 still finds 1 selected-facade import in tests and public exposure remains. | Reusable permission code should import `CodexWatcher.Workflow.Permission.Core`. | Existing moifold code may continue using `validateMoifoldEffectPlan`, `moifoldPermissionPolicy`, and concrete validation helpers. | `defer` | No deprecation or removal until public API, downstream-user, and behavior evidence is reviewed. |

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
| `issue-state.json` | `keep` | Round 053 records current producers in compatibility projection, repair rewrite, fanout, startup/reconciliation, and PR-review handoff paths; healthcheck reads `issueState`; golden issue fixtures cover blocked, plan-ready, and incomplete snapshots; tests protect PR URL projection, golden replay/bootstrap, daemon write order, and compatibility parity. Round 055 keeps this as a current operator/runtime contract. | Exhaustive old live state-directory fixtures for field combinations and external operator/downstream direct-reader inventory are still missing. |
| `daemon-state.json` | `keep` | Round 053 records compatibility projection producers for idle, active, stopped, and concrete daemon summaries; healthcheck reads shared `daemonState`; repair rewrites daemon state through repaired replay compatibility writes; the incomplete issue fixture covers an older tolerated `lastCompletedTurn` shape. Round 055 keeps the file because it remains an operator contract. | Active and stopped daemon fixtures and external operator/downstream direct-reader inventory are still missing. |
| `planning-state.json` | `defer` | Round 053 records two producer shapes: direct `RecordPlanningGraph` planned writes and compatibility projection from waiting-ready-issues planning state. Tests protect direct graph recording, canonical graph recording, indexed planning parity, and daemon compatibility writes. Round 055 records no healthcheck reader and no checked-in `planning-state.json` fixture. Round 064 confirms the producer readback and records explicit current non-healthcheck policy for this write-only compatibility projection. | Old snapshot/file fixture coverage, external operator/downstream direct-reader inventory, and a reviewed behavior-change selection for any future healthcheck surfacing are missing. |
| PR review state files and PR URL fields | `keep` for current PR review state files; `defer` for absent dedicated PR URL file wording | Round 053 maps the selected surface to current `watcher-state.json`, `checker-state.json`, optional `agent-state.json`, `reviewer-state.json`, `issue-state.json` `pr_url`, and PR review config `prUrl`; no dedicated `pr-url` or `pr-state` file producer was found. Golden PR-review snapshots cover merged, unresolved, blocked, and clean-ready shapes; healthcheck reads PR-review state files; tests protect PR-review compatibility and PR URL projection. | External operator/downstream inventory is still required before concluding no user expects a dedicated PR URL/state path. |
| `block-state.json` | `keep` | Round 053 records direct `RecordBlocked` planned writes, compatibility projection for blocked state, and runner repair-failure block-state writes. Healthcheck reads blocked state across issue planning, issue implementation, and PR review; successful repair removes stale block state after compatibility rewrite; golden PR-review blocked fixture and blocked event-log fixtures exist. Round 055 keeps the file as a current operator contract. | A checked-in fixture for runner repair-failure block-state JSON and external operator/downstream direct-reader inventory are still missing. |
| `repair-state.json` | `defer` | Round 053 records the single producer in `repair-invalid-state --execute`: archive invalid log, write repaired `events.jsonl`, write `repair-state.json`, rewrite compatibility files, then remove stale `block-state.json`. Round 055 records no production reader, no healthcheck reader, and no checked-in fixture; tests protect dry-run/execute source-order behavior. | Fixture round-trip coverage, healthcheck or explicit non-healthcheck policy, production-reader expectations, and external operator/downstream direct-reader inventory are missing. |
| `runtime-owner.json` | `keep` | Round 053 records runtime owner store and CLI producers/readers, automatic-loop validation and renewal, healthcheck surfacing, and `scripts/restart-watcher` shell parsing/removal. Tests protect current lease JSON parsing, rejection of old owner-only shapes, running-lease rejection, and current-process cleanup. Round 055 keeps this as live daemon ownership state. | Checked-in fixture coverage, healthcheck field-path mismatch resolution or explicit policy, and external operator/downstream script inventory are still missing. |
| Checked-in compatibility snapshots | `defer` | Round 053 records golden PR-review and issue-implementation snapshot directories plus golden event-log replay/bootstrap coverage. Round 055 separates checked-in compatibility snapshots from live `issue-snapshot.json` and records replay/bootstrap tests as the current evidence. | Any removal or migration needs fixture-by-fixture old-log/golden proof and reviewer approval that the snapshot is no longer required. |
| Live `issue-snapshot.json` | `defer` | Round 053 records live issue-planning snapshot production before planner turn start, and tests protect snapshot write timing plus closed-scope completion without starting a planner turn. Round 055 records no checked-in live `issue-snapshot.json` fixture and no healthcheck reader. | Old live snapshot fixture coverage, external operator/downstream direct-reader inventory, and explicit write-timing migration evidence are missing. |

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
  checked-in compatibility snapshots;
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
- Compatibility files keep their current names and meanings, including
  `issue-state.json`, `daemon-state.json`, `planning-state.json`, PR URL
  files, block state, repair state, runtime owner files, and compatibility
  snapshots.
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

This round satisfies none of those gates for any specific deprecation pragma
because it intentionally changes documentation only.

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
means the compatibility surface remains available.

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
