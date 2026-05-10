# Verification: Highest-Value Cleanup

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-001`

## Baseline Checks

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` when staging is involved

Artifact-only inventory or roadmap-update rounds may skip package build/test
only when the reviewer records changed-path evidence showing no production
code, test code, package descriptor, runtime compatibility file, public API,
fixture, docs, or behavior surface changed.

## Alignment Checks

- Confirm the round records roadmap lineage for
  `2026-05-11-00-highest-value-cleanup` and does not append work to
  `2026-05-10-00-facade-removal-readiness` or any older family.
- Confirm no round treats preferred-import guidance, import reduction, a
  terminal hold, or local absence of users as deprecation or removal approval.
- Confirm `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission` remain available and exposed until an
  exact reviewed gate names the surface.
- Confirm compatibility files keep current names and meanings until fixture,
  old-log, repair, healthcheck, write-timing, operator/downstream, and behavior
  evidence approves an exact migration or removal.
- Confirm `planner-state.json` and `planning-state.json` are treated as
  distinct compatibility surfaces until a reviewed contract says otherwise.
- Confirm large-module splits preserve public exports and behavior unless the
  selected direction explicitly approves a behavior or API change.
- Confirm package-boundary cleanup moves reusable-package-oriented code toward
  direct owner modules without moving concrete moifold lifecycle policy into
  reusable packages.
- Confirm final deprecation/removal rounds update docs, Haddock or public
  wording, Cabal exposure, fixtures, tests, and policy together when relevant.
- Confirm terminal closeout first inspects merged evidence for additional
  high-value cleanup. If new cleanup fronts remain, require a reviewed roadmap
  update or new revision with added milestones instead of approving `done`.

## Task-Specific Checks

Reviewers should require focused checks matching the selected surface:

- For `test/Main.hs` splits: prove the same tests are still reachable from
  `watcher-core-test`, preserve assertions and failure messages where
  practical, and record the before/after line count or module ownership.
- For package-boundary scanners: run the extracted scanner tests and verify
  reusable packages do not import moifold-owned modules or compatibility
  facades unless a reviewed exception exists.
- For compatibility fixtures: validate fixture parsing, old/current JSON shape
  behavior, replay behavior when applicable, and fixture paths checked into the
  expected directory.
- For `planner-state.json` / `planning-state.json`: verify producer names,
  healthcheck reader behavior, docs policy, and compatibility write timing.
- For facade import convergence: run current import scans over `src`, `app`,
  `test`, docs, package descriptors, and standalone package candidates; record
  remaining facade users and blockers.
- For `AppServerClient` changes: verify endpoint parsing, app-server protocol,
  session handling, command rendering, and failure formatting as applicable.
- For `Core.Ids` changes: verify parsers/renderers for repo names, branch
  names, commit SHAs, PR numbers, issue numbers, thread ids, turn ids, request
  ids, and review thread ids as applicable.
- For `Workflow.EventLog` or `EventLog.Types` changes: verify golden replay,
  event JSON `type` stability, schema compatibility, old-log parsing, and
  transition/replay parity.
- For `Workflow.Permission` changes: verify permission soundness,
  phase-validation errors, state/effect validation, and concrete `MoifoldSpec`
  behavior.
- For `Daemon`, `DocsMigration`, `IssueImplement.Indexed`, or `TurnOutput`
  splits: run focused behavior tests for moved code plus the baseline checks.
- For deprecation/removal: verify exact approved surface, downstream/import
  inventory, docs/Haddock/Cabal alignment, behavior evidence, fixture evidence
  when runtime-facing, and final kept/deferred/deprecated/removed sets.

## Manual Checks

- Review every removal or deprecation claim and confirm it names the exact
  module, export, file path, Cabal exposed-module entry, or compatibility
  surface.
- For runtime compatibility cleanup, verify operator/runbook/script inventory
  scope is recorded and accepted by the reviewer.
- For large module splits, confirm the new module names communicate ownership
  and do not create import cycles or hidden package-boundary leakage.
- For terminal closeout, verify the final report lists kept, deferred,
  deprecated, removed, migrated, and blocked surfaces, and does not imply
  release or package publication approval.
- For roadmap expansion, verify the update names new milestones, dependencies,
  verification gates, and why the work could not be represented by existing
  pending milestones.

## Roadmap Overrides

- Removal is never a fallback for missing evidence.
- Preferred imports are not deprecation pragmas, Cabal exposure changes, or
  removal approval.
- Test extraction rounds must not weaken coverage to reduce file size.
- Runtime compatibility cleanup must not rename or delete files before fixtures
  and reader/writer contracts are explicit.
- Public compatibility facades remain exposed until exact removal gates are
  satisfied and reviewer approval names the surface.
- Exhausting the initial milestone list is not terminal by itself. If reviewed
  evidence reveals more highest-value cleanup, add milestones through a
  reviewed roadmap update or new revision before setting controller state to
  `done`.
