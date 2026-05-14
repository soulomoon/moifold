# Verification: Highest-Value Cleanup

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-002`

## Baseline Checks

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` when staging is involved

Artifact-only inventory, classification, or roadmap-update rounds may skip
package build/test only when the reviewer records changed-path evidence showing
no production code, test code, package descriptor, runtime compatibility file,
public API, fixture, docs, or behavior surface changed.

## Alignment Checks

- Confirm the round records roadmap lineage for
  `2026-05-11-00-highest-value-cleanup` and active revision `rev-002` after
  this revision is activated.
- Confirm no round treats preferred-import guidance, import reduction, a
  terminal hold, or local absence of users as deprecation or removal approval.
- Confirm removed public wrappers
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission` have no remaining source/app/test imports,
  no main-library exposed-module entries, and docs/policy that point at direct
  owner modules.
- Confirm milestone 003 reviews production `Core.Ids` users only, separating
  tests, docs, `moifold.cabal`, and `src/CodexWatcher/Core/Ids.hs` from the
  production burndown scan.
- Confirm milestone 004 reviews test/fixture `Core.Ids` users only, and
  classifies intentional policy evidence imports instead of forcing fake
  migrations.
- Confirm milestone 005 moved concrete `Workflow.EventLog` and
  `Workflow.Permission` bridge/facade uses to direct owner modules without
  changing event/permission behavior.
- Confirm milestone 006 removed `CodexWatcher.AppServerClient` public facade,
  Cabal exposure, docs, and policy references only after current scans proved
  no source/app/test users.
- Confirm compatibility files keep current names and meanings until fixture,
  old-log, repair, healthcheck, write-timing, operator/downstream, and behavior
  evidence approves an exact migration or removal.
- Confirm large-module splits preserve public exports and behavior unless the
  selected direction explicitly approves a behavior or API change.
- Confirm final deprecation/removal rounds update docs, Haddock or public
  wording, Cabal exposure, fixtures, tests, and policy together when relevant.
- Confirm terminal closeout proves all roadmap-covered compatibility surfaces
  are removed cleanly or migrated away from supported compatibility paths. Any
  kept, deferred, blocked, or hold-only compatibility surface requires roadmap
  milestone expansion, not terminal `done`.
- Confirm `completion-audit.md` maps the user objective to concrete artifact,
  scan, build, test, and runtime-file evidence before any terminal closeout
  claim.
- Confirm downstream runtime-file direct-reader inventory is current before
  removing or renaming `issue-state.json`, `daemon-state.json`,
  `planner-state.json`, PR-review state files, or `block-state.json`.
- Confirm the read-only downstream replacement path remains guarded by
  `healthcheckRuntimeStateMigrationContractTests` before claiming health/status
  consumers can move from direct file reads to `moifold healthcheck`.
- Confirm any downstream daemon migration claim names the exact downstream
  scripts, proves they delegate to Haskell `moifold run-*` commands, and
  validates generated initial event logs with current Haskell replay.
- Confirm local runtime-file candidate decisions remain guarded by
  `localRuntimeFileCandidateDecisionTest` before claiming
  `planning-state.json`, `repair-state.json`, `runtime-owner.json`, or
  live `issue-snapshot.json` have exact removed/keep status.
- Confirm any local compatibility-file writer migration proves normal execute
  paths append event logs without writing `issue-state.json`,
  `daemon-state.json`, `planner-state.json`, PR-review state files, or normal
  `block-state.json`; pure healthcheck/reporting projections do not count as
  file writers.

## Task-Specific Checks

Reviewers should require focused checks matching the selected surface:

- For production `Core.Ids` import burndown: run a selected-file scan proving
  the target production file no longer imports `CodexWatcher.Core.Ids`; run a
  broad remaining-user scan over `src`, `app`, `test`, docs, package
  descriptors, and standalone package candidates; record remaining production
  users separately from tests, docs, Cabal, and the public facade module.
- For `EventLog.Types` or replay-adjacent import/fixture changes: verify event
  JSON `type` stability, schema compatibility, old-log parsing,
  transition/replay parity, selected-file direct-owner imports, and any
  bootstrapped event-log fixture coverage that replaces removed snapshots.
- For `Runtime.Compatibility` or `Healthcheck` import changes: verify current
  runtime compatibility file names, fixture shapes, healthcheck reader/non-reader
  contracts, summary paths, write timing, repair boundaries, and selected-file
  direct-owner imports.
- For domain loop import changes: verify request-id progression, thread/turn
  id rendering, repo/issue/PR rendering, event append order, daemon transition
  behavior, and command/error text for the selected loop.
- For CLI parser/types/fanout import changes: verify option parsing, parser
  error behavior, command rendering, dry-run text, child args, fanout manifest,
  and runtime command behavior as applicable.
- For test/fixture `Core.Ids` imports: preserve assertions, fixtures, PASS
  labels, aggregate wiring, and focused behavior checks. Do not weaken a test
  merely to remove a facade import.
- For policy or parity test classification: record the exact import, why it is
  intentionally retained, and why it does not imply public removal approval.
- For `Workflow.EventLog` or `Workflow.Permission` bridge/facade changes:
  verify direct owner scans, replay/audit or permission validation behavior,
  public facade exposure, and absence of stale qualified facade uses.
- For `AppServerClient` public-surface cleanup: verify endpoint parsing,
  app-server protocol, session handling, command rendering, failure formatting,
  current import scans, docs/policy wording, Cabal exposure, and downstream
  scope as applicable.
- For `Daemon`, `DocsMigration`, `IssueImplement.Indexed`, `EventLog.Types`, or
  `TurnOutput` splits: run focused behavior tests for moved code plus the
  baseline checks.
- For deprecation/removal: verify exact approved surface, downstream/import
  inventory, docs/Haddock/Cabal alignment, behavior evidence, fixture evidence
  when runtime-facing, and final kept/deferred/deprecated/removed sets.

## Manual Checks

- Review every removal or deprecation claim and confirm it names the exact
  module, export, file path, Cabal exposed-module entry, or compatibility
  surface.
- For milestone 003 closeout, verify every remaining production `Core.Ids` user
  is either gone or classified with a concrete reason.
- For milestone 004 closeout, verify every remaining test `Core.Ids` user is
  either gone or classified as policy, parity, or compatibility evidence.
- For milestone 005 closeout, verify remaining EventLog/Permission facade uses
  are only intentional public facade or policy/parity owners.
- For runtime compatibility cleanup, verify operator/runbook/script inventory
  scope is recorded and accepted by the reviewer.
- For large module splits, confirm the new module names communicate ownership
  and do not create import cycles or hidden package-boundary leakage.
- For terminal closeout, verify the final report lists kept, deferred,
  deprecated, removed, migrated, and blocked surfaces, does not imply release
  or package publication approval, and has empty kept, deferred, and blocked
  compatibility-surface sets.
- For roadmap expansion, verify the update names new milestones,
  dependencies, verification gates, and why the work could not be represented
  by existing pending milestones.
- For downstream runtime-file migration, verify the exact downstream repository
  and file readers, the replacement read path or product-contract retention
  decision, and focused validation for both moifold and downstream behavior.
- For the `moifold healthcheck` replacement path, verify the report preserves
  the documented `watchers[].states.*` mapping for planner, issue implementer,
  and PR review state files.
- For downstream daemon migration shims, verify the scripts no longer directly
  read or write the legacy runtime files, fake-launcher smoke checks cover each
  daemon script, and Haskell `moifold replay-events` accepts the initialized
  event logs produced by the shims.
- For local runtime-file candidates, verify the decision artifact names each
  selected file, records `defer` or `keep-as-product`, and is backed by
  source/fixture tests for writer paths, non-reader contracts, and replacement
  gates.
- For local compatibility-file writer removal, run a production source scan for
  stale writer functions and stale `PlannedWriteJson` compatibility outputs,
  and keep separate any retained product files or diagnostics such as
  `repair-state.json`, `runtime-owner.json`, and live `issue-snapshot.json`.

## Roadmap Overrides

- Removal is never a fallback for missing evidence.
- Preferred imports are not deprecation pragmas, Cabal exposure changes, or
  removal approval.
- Import burndown milestones close by migration or explicit classification, not
  by waiting for unrelated public-removal gates.
- Test extraction and test import rounds must not weaken coverage to reduce
  file size or facade counts.
- Runtime compatibility cleanup must not rename or delete files before fixtures
  and reader/writer contracts are explicit.
- Public compatibility facades remain exposed until exact removal gates are
  satisfied and reviewer approval names the surface.
- Exhausting the initial milestone list is not terminal by itself. If reviewed
  evidence reveals more highest-value cleanup, add milestones through a
  reviewed roadmap update or new revision before setting controller state to
  `done`.
- Final success means all compatibility surfaces covered by the family are
  removed cleanly or migrated away from supported compatibility paths. A
  terminal hold, defer, or keep decision is an intermediate blocker record and
  must drive more roadmap work unless the user explicitly approves a new goal
  in a later family.
