# Compatibility Surface Cleanup Roadmap

Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
Roadmap revision: `rev-001`
Roadmap style: `strategy-backlog`

## Goal

Prepare, verify, and eventually perform selected compatibility surface cleanup
for moifold's workflow package split while preserving event schemas, golden
fixtures, runtime compatibility files, healthcheck, repair behavior, and
current package boundaries.

## Alignment Summary

- Thesis: compatibility cleanup must be evidence-first. The repo should not
  remove import facades or runtime compatibility files until it has a
  source-backed inventory, replacement map, behavior evidence, and explicit
  reviewer approval for each removed surface.
- Success criteria: reviewers can see every compatibility import facade and
  runtime compatibility file, understand who still uses it, know the preferred
  replacement or keep decision, see tests that protect behavior, and review a
  final removal candidate list before any code removal happens.
- Non-goals: no package publication work, no event schema migration, no
  incidental prompt/runtime/healthcheck/repair redesign, no generic prompt
  runner, no workflow `liftIO`, and no removal before the selected final
  removal milestone.
- Chosen strategy: staged compatibility cleanup. Inventory both public import
  facades and runtime compatibility files first, build readiness evidence and
  missing tests, write policy from the evidence, expand the roadmap near the
  end of the initial todo list if new work is discovered, then perform only
  explicitly approved removals.
- Deferred alternatives: readiness-only cleanup is too weak because the user
  wants removal at the end. Immediate removal is too risky because the
  compatibility files and import facades are part of the current product
  contract.

## Outcome Boundaries

- In scope: import-facade inventory, runtime compatibility-file inventory,
  preferred replacement paths, downstream source scans, old-log and golden
  replay evidence, healthcheck and repair behavior evidence, deprecation
  readiness classification, removal candidate selection, roadmap expansion
  before terminal cleanup, and gated removal rounds.
- Out of scope: package upload, public release approval, event JSON `type`
  changes, compatibility-file schema migration, healthcheck or repair
  redesign, daemon ownership changes, app-server startup policy changes, and
  broad package API redesign unrelated to compatibility cleanup.

## Global Sequencing Rules

- Inventory before policy. Policy must cite current source evidence rather
  than desired cleanup shape.
- Policy before removal. A surface may become a removal candidate only after
  replacement paths, users, tests, and compatibility consequences are known.
- Runtime compatibility files require old-log, golden, repair, and healthcheck
  evidence before removal or behavior changes.
- Import facade cleanup requires recursive import scans and package-boundary
  tests before any deprecation or removal.
- Near the end of the initial pending list, the guider must run a follow-up
  discovery and roadmap-update round. If the work reveals additional cleanup
  items, publish a new roadmap revision instead of forcing terminal closure.
- Gated removals are allowed only in the final cleanup milestone and only when
  a selected direction names the surfaces and a reviewer approves the exact
  removal evidence.

## Parallel Lanes

- Default lane: serial. Compatibility cleanup touches shared contracts and
  should stay ordered until evidence proves disjoint ownership.
- Potential lane `import-facades`: source scans, replacement maps, and tests
  for Haskell compatibility modules.
- Potential lane `runtime-compatibility`: compatibility-file inventory,
  old-log, healthcheck, repair, and write-timing evidence.
- Potential lane `docs-policy`: documentation and policy updates after the
  two evidence lanes produce stable facts.

## Milestones

### 1. [complete] Inventory Compatibility Surfaces

Milestone id: `milestone-001-inventory-compatibility-surfaces`
Depends on: none
Intent: Build a complete source-backed inventory of public import facades and
runtime compatibility files before policy or removal work begins.
Completion signal: the repo has reviewable docs or artifacts listing every
in-scope import facade, runtime compatibility file, current producer, current
consumer, tests protecting it, and unknowns.
Parallel lane: serial by default; `import-facades` and `runtime-compatibility`
may run in parallel only if the planner assigns disjoint files and artifacts.
Coordination notes: inventory rounds must not remove, deprecate, or rename
surfaces. Unknown ownership should be recorded as risk, not silently filled in.
Progress: round 052 completed the import-facade inventory in `2179bb4`,
recording the six selected public compatibility import facades, current
repo-local users, preferred replacement imports, Cabal exposure, protecting
tests, source scans, and unresolved unknowns without changing production code,
descriptors, imports, runtime compatibility files, deprecation status, or
removal status. Round 053 completed the runtime compatibility-file inventory
in `9e34917`, recording selected runtime compatibility files, current
producers and consumers, write timing, healthcheck and repair use, golden and
old-log assumptions, protecting tests, and explicit unknowns without changing
file names, schemas, compatibility write behavior, runtime behavior,
deprecation status, or removal status. Milestone 001 is complete because both
inventory directions now have approved, source-backed artifacts covering the
milestone completion signal.

Candidate directions:

- Direction id: `direction-001-import-facade-inventory`
  Status: complete via round 052, merged as `2179bb4`.
  Summary: inventory Haskell compatibility import facades and current users.
  Why it matters now: import facades are the lowest-risk cleanup candidates,
  but removal still requires proof of user coverage and replacement paths.
  Preconditions: current package split and boundary tests remain green.
  Parallel hints: may run beside runtime-file inventory if artifacts are
  disjoint.
  Boundary notes: no deprecation pragmas and no import rewrites in this
  direction.
  Extraction notes: cover `CodexWatcher.AppServerClient`,
  `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.Types`,
  `CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Execution`, and
  `CodexWatcher.Workflow.Permission`.

- Direction id: `direction-002-runtime-compatibility-file-inventory`
  Status: complete via round 053, merged as `9e34917`.
  Summary: inventory runtime compatibility files, write sites, read sites,
  repair use, healthcheck use, and old-log assumptions.
  Why it matters now: runtime files are user-visible and operationally
  sensitive, so cleanup cannot proceed from import scans alone.
  Preconditions: current golden fixtures and `watcher-core-test` pass.
  Parallel hints: may run beside import-facade inventory with separate docs.
  Boundary notes: no file name, field, timing, or compatibility write behavior
  changes.
  Extraction notes: cover `issue-state.json`, `daemon-state.json`,
  `planning-state.json`, PR URL/state files, block state, repair state,
  runtime owner files, and compatibility snapshots.

### 2. [complete] Prove Replacement Paths And Behavior Gates

Milestone id: `milestone-002-replacement-paths-and-behavior-gates`
Depends on: `milestone-001-inventory-compatibility-surfaces`
Intent: Convert inventory into testable readiness evidence: preferred imports,
replacement APIs, old-log behavior, write timing, repair, healthcheck, and
golden replay protections.
Completion signal: each cleanup candidate has a keep/defer/remove-later
classification with required tests or manual evidence identified, and missing
tests are added before the candidate can advance.
Parallel lane: limited to proven-disjoint candidate groups.
Coordination notes: this milestone may add tests and docs. It still must not
remove compatibility surfaces.
Progress: round 054 completed import replacement readiness in `2c2771c`,
recording recursive selected-facade import scans, preferred replacement
imports, Cabal exposure, package-boundary assertions, protecting tests,
missing evidence, and conservative keep/defer classifications for the six
selected public compatibility import facades without changing production
imports, public exposure, runtime compatibility-file behavior gates, cleanup
policy, deprecation status, or removal status. Milestone 002 remained pending
until `direction-004-runtime-file-behavior-gates` provided runtime
compatibility-file behavior evidence before cleanup policy or removal work
could advance. Round 055 completed runtime compatibility-file
behavior gates in `e6bc2ee`, recording golden replay, repair, healthcheck,
write-timing, old snapshot/file evidence, protecting tests, missing evidence,
and conservative keep/defer classifications for the selected runtime
compatibility surfaces without changing schemas, filenames, write timing,
runtime behavior, policy, roadmap revision, or removal status. Milestone 002
is complete because both replacement-readiness and runtime behavior-gate
directions now have approved evidence and missing tests or manual evidence are
identified before any candidate can advance.

Candidate directions:

- Direction id: `direction-003-import-replacement-readiness`
  Status: complete via round 054, merged as `2c2771c`.
  Summary: prove preferred package-facing imports and add tests or scans that
  prevent accidental fallback to compatibility facades.
  Why it matters now: imports can only be cleaned when replacements are clear
  and enforceable.
  Preconditions: import-facade inventory is complete.
  Parallel hints: can run with runtime behavior gates if source ownership is
  disjoint.
  Boundary notes: no wrapper removal; internal import migrations are allowed
  only when scoped to evidence and behavior stays unchanged.
  Extraction notes: prefer recursive `rg`-backed scans and exact Cabal/package
  boundary assertions over hand-maintained lists.

- Direction id: `direction-004-runtime-file-behavior-gates`
  Status: complete via round 055, merged as `e6bc2ee`.
  Summary: prove compatibility-file behavior through golden replay, repair,
  healthcheck, write-timing, and old snapshot evidence.
  Why it matters now: runtime cleanup must not strand existing watcher state or
  break operator diagnostics.
  Preconditions: runtime compatibility-file inventory is complete.
  Parallel hints: serial when touching shared fixtures or repair behavior.
  Boundary notes: no file schema migration or removal in this direction.
  Extraction notes: name each fixture, command, or healthcheck path that guards
  a future cleanup candidate.

### 3. [pending] Write Cleanup Policy From Evidence

Milestone id: `milestone-003-evidence-backed-cleanup-policy`
Depends on: `milestone-002-replacement-paths-and-behavior-gates`
Intent: Turn readiness evidence into a concrete compatibility cleanup policy
that classifies each surface and names the gates for deprecation or removal.
Completion signal: docs and project contract accurately state which surfaces
stay, which may be deprecated later, which may be removed at the end of this
family, and which evidence is required per surface.
Parallel lane: `docs-policy`
Coordination notes: policy must quote current source evidence. It must not
claim removal approval by itself.

Candidate directions:

- Direction id: `direction-005-import-facade-cleanup-policy`
  Summary: document preferred imports, deprecation readiness, and removal gates
  for Haskell import facades.
  Why it matters now: later removal rounds need a reviewed surface-by-surface
  contract, not broad cleanup intent.
  Preconditions: import replacement readiness evidence exists.
  Parallel hints: can run with runtime policy if docs ownership is separated.
  Boundary notes: no deprecation pragma or removal unless a later selected
  removal direction approves it.
  Extraction notes: distinguish compatibility-only wrappers from product-facing
  specs such as `CodexWatcher.Workflow.Types`.

- Direction id: `direction-006-runtime-compatibility-cleanup-policy`
  Summary: document keep/defer/remove-later policy for runtime compatibility
  files and snapshots.
  Why it matters now: runtime file cleanup has operational consequences beyond
  build-time imports.
  Preconditions: runtime behavior gates are known.
  Parallel hints: can run with import policy if documents are disjoint.
  Boundary notes: no file migration or removal.
  Extraction notes: record required old-log, repair, healthcheck, and
  write-timing evidence for every candidate.

### 4. [pending] Expand Follow-Up Backlog Before Terminal Cleanup

Milestone id: `milestone-004-expand-follow-up-backlog`
Depends on: `milestone-003-evidence-backed-cleanup-policy`
Intent: Re-scan the evidence near the end of the initial todo list and expand
the roadmap with newly discovered cleanup items before final removals begin.
Completion signal: a roadmap-update round either creates a new revision with
additional cleanup milestones/directions or records that no additional items
are justified by current evidence.
Parallel lane: serial
Coordination notes: this milestone implements the user's instruction to expand
work near the end rather than treating the first todo list as exhaustive.

Candidate directions:

- Direction id: `direction-007-follow-up-discovery`
  Summary: review inventories, policy docs, tests, TODOs, and reviewer notes to
  find follow-up cleanup items before removal rounds.
  Why it matters now: compatibility cleanup tends to reveal secondary callers
  and stale docs after initial evidence lands.
  Preconditions: cleanup policy is reviewed.
  Parallel hints: serial because it may revise future coordination.
  Boundary notes: no removal during discovery.
  Extraction notes: produce a compact candidate list with source evidence and
  recommended milestone placement.

- Direction id: `direction-008-roadmap-expansion-update`
  Summary: publish the roadmap-update artifact and, when justified, a new
  active revision containing additional cleanup items.
  Why it matters now: final removal should start only after known follow-ups
  are either represented or explicitly deferred.
  Preconditions: follow-up discovery is complete.
  Parallel hints: serial update-roadmap stage.
  Boundary notes: preserve used roadmap revisions as immutable history.
  Extraction notes: state clearly whether expansion changed `roadmap_id`,
  `roadmap_revision`, or `roadmap_dir` activation metadata.

### 5. [pending] Perform Gated Compatibility Removals

Milestone id: `milestone-005-gated-compatibility-removals`
Depends on: `milestone-004-expand-follow-up-backlog`
Intent: Remove only selected compatibility surfaces whose gates have passed
and whose removal has explicit reviewer approval.
Completion signal: approved removal rounds land with import scans, build/test
evidence, old-log/golden evidence where relevant, updated docs, and no
unapproved compatibility behavior drift.
Parallel lane: serial unless the planner proves disjoint surfaces and
independent verification.
Coordination notes: this is the first milestone where removal is allowed. Each
round must name exactly which surfaces it removes and why the gate is
satisfied.

Candidate directions:

- Direction id: `direction-009-remove-approved-import-facades`
  Summary: remove or narrow only import facades that policy and evidence mark
  as safe removal candidates.
  Why it matters now: successful package extraction should eventually reduce
  duplicate public entry points where they are no longer needed.
  Preconditions: import-facade policy approved; scans show no unsupported
  remaining users; behavior and package-boundary tests pass.
  Parallel hints: keep serial unless selected facades are fully independent.
  Boundary notes: product-facing specs may be kept even when wrapper-only
  modules are removed.
  Extraction notes: update docs, Cabal exposed modules, imports, and tests in
  one coherent slice.

- Direction id: `direction-010-remove-approved-runtime-compatibility-surfaces`
  Summary: remove or migrate only runtime compatibility files/snapshots that
  policy and evidence mark as safe removal candidates.
  Why it matters now: compatibility files should not remain forever if they no
  longer serve live operators or old state.
  Preconditions: old-log/golden, repair, healthcheck, runtime-owner, and
  write-timing gates pass for the selected files.
  Parallel hints: serial by default.
  Boundary notes: no event schema migration unless a later roadmap explicitly
  authorizes it; preserve operator recovery for supported old states.
  Extraction notes: include before/after file ownership, fallback behavior, and
  repair instructions in the round evidence.

### 6. [pending] Close The Cleanup Family

Milestone id: `milestone-006-close-cleanup-family`
Depends on: `milestone-005-gated-compatibility-removals`
Intent: Finalize the compatibility cleanup family with current docs, validation
evidence, and an explicit done-or-hold decision.
Completion signal: the final roadmap update records remaining compatibility
surfaces, removed surfaces, deferred surfaces, validation commands, and whether
more cleanup requires a new family.
Parallel lane: serial
Coordination notes: completion requires no live rounds, no pending roadmap
updates, no unexplained pending cleanup items, and current validation evidence.

Candidate directions:

- Direction id: `direction-011-final-compatibility-surface-report`
  Summary: produce a final report of kept, removed, and deferred compatibility
  surfaces with validation evidence.
  Why it matters now: future package/release work needs a precise compatibility
  baseline.
  Preconditions: removal rounds and expansion updates are complete.
  Parallel hints: serial.
  Boundary notes: do not imply package publication or release approval.
  Extraction notes: include exact commands run and any remaining blockers.

- Direction id: `direction-012-terminal-cleanup-gate`
  Summary: mark the family complete or hold it with explicit blockers.
  Why it matters now: controller terminal state should reflect evidence, not an
  exhausted initial list.
  Preconditions: final report reviewed.
  Parallel hints: serial terminal direction.
  Boundary notes: no silent done when pending or newly discovered items remain.
  Extraction notes: re-read `orchestrator/state.json` and the active roadmap
  bundle before deciding terminal status.
