# Verification Contract

Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
Roadmap revision: `rev-002`

## Baseline Checks

- Command: `cabal build all`
  Why: Builds moifold plus the current standalone workflow package candidates.
- Command: `cabal test watcher-core-test`
  Why: Runs the regression suite covering replay, package boundaries,
  compatibility facades, golden fixtures, healthcheck, repair, runtime owner
  behavior, and workflow behavior.
- Command: `scripts/validate-workflow-packages.sh`
  Why: Confirms package descriptors, `cabal check`, and local source
  distribution artifacts remain valid after compatibility-surface work.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when staging is involved.

Artifact-only roadmap-update rounds may skip the Cabal and package baseline
commands when the diff is limited to roadmap and round-local orchestrator
artifacts. The reviewer must require the baseline if the diff escapes that
allowed artifact set.

## Rev-002 Artifact Checks

- Confirm these files exist and are readable:
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`,
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`,
  and
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`.
- Confirm `orchestrator/rounds/round-059/plan.md` exists.
- Confirm no `orchestrator/rounds/round-059/worker-plan.json` exists unless a
  later reviewed plan explicitly introduces worker fan-out.
- Grep/read back the roadmap id
  `2026-05-09-01-compatibility-surface-cleanup`, roadmap revision `rev-002`,
  roadmap style `strategy-backlog`, and activation metadata for
  `roadmap_revision`: `rev-002` and the `rev-002` roadmap directory.
- Read back that milestones 001-004 are complete with progress pointers
  through rounds 052-059.
- Read back that import-facade follow-up evidence, runtime compatibility
  follow-up evidence, and external operator/downstream inventory are ordered
  before gated removals.
- Read back that removals remain dependency-gated after the new evidence
  milestones and require explicit reviewer approval.
- Confirm `rev-001` remains intact unless the update intentionally records
  moved history in `roadmap-history.md`.

## Forbidden-Diff Checks For Artifact-Only Updates

For round 059 and similar artifact-only roadmap updates, inspect:

```text
git diff --name-only
git status --short
```

The diff must not include production source, tests, Cabal descriptors, docs
policy files, fixtures, scripts, runtime compatibility files, import surfaces,
`orchestrator/project-contract.md`, `orchestrator/state.json`, or
controller/review/merge artifacts outside the selected round's allowed
orchestrator artifacts. If a forbidden path appears, the reviewer must reject
or require the full relevant baseline and an updated plan.

## Alignment Checks

- Evidence before policy: policy updates must cite current import scans,
  producer/consumer inventories, or runtime compatibility evidence.
- Policy before removal: no compatibility surface may be removed before a
  reviewed policy classifies that surface as a removal candidate.
- Follow-up evidence before removal: rev-002 requires import-facade evidence,
  runtime compatibility evidence, and external operator/downstream inventory
  before final selected removal work.
- Runtime compatibility: rounds touching compatibility files must preserve
  event JSON `type` fields, schema versions, golden logs, repair behavior,
  healthcheck behavior or explicit non-healthcheck policy, write timing,
  fixture behavior, and operator recovery unless an explicit selected
  direction authorizes a proven migration.
- Import compatibility: rounds touching import facades must provide recursive
  import scans, replacement paths, Cabal exposed-module analysis when
  relevant, public/downstream-user review, and package-boundary test evidence.
- Removal approval: final removal rounds must name the exact surfaces removed,
  list every satisfied gate, and receive reviewer approval before merge.

## Task-Specific Checks

- Import-facade evidence rounds must scan source, tests, examples, package
  docs, Cabal descriptors, public package docs, and downstream/operator
  evidence where available.
- `CodexWatcher.Core.Ids` evidence must distinguish agent-id ownership from
  GitHub-id ownership before any import migration or facade narrowing.
- `CodexWatcher.AppServerClient` evidence must group uses by
  client/transport/parser ownership and prove behavior parity before any
  production import migration.
- `CodexWatcher.Workflow.EventLog` evidence must protect old-log and golden
  replay behavior before helper movement or facade narrowing.
- `CodexWatcher.Workflow.Permission` evidence must treat public API exposure
  and concrete permission behavior as first-class gates.
- Runtime compatibility evidence rounds must scan read sites, write sites,
  repair code, healthcheck code, golden fixtures, snapshots, CLI replay paths,
  operator scripts, and runbook references.
- Runtime follow-up rounds must cover weakly represented files named by round
  058: `planning-state.json`, `repair-state.json`, `runtime-owner.json`,
  active/stopped `daemon-state.json`, PR URL/state external paths,
  repair-failure `block-state.json`, and live `issue-snapshot.json`.
- External inventory must record whether evidence is observed, unavailable, or
  blocked on operator approval; local repository absence is not enough to
  approve removal.
- Removal rounds must update source, tests, docs, and Cabal exposed modules in
  the same reviewed slice when a removed surface is public.

## Manual Checks

- Reviewers must inspect every compatibility surface classified as removable
  and confirm the replacement or unsupported-user decision is explicit.
- Reviewers must inspect old-log, golden replay, repair, healthcheck or
  non-healthcheck policy, fixture, write-timing, and operator evidence before
  approving runtime compatibility-file removal.
- Reviewers must inspect public docs for overclaims: cleanup readiness is not
  package publication, deprecation policy is not removal approval, and package
  extraction does not move moifold lifecycle policy into reusable packages.
- Reviewers must verify that rev-002 does not upgrade any round-058 candidate
  to current migration, deprecation, removal, package publication, upload, or
  release approval.

## Roadmap Overrides

- This family is `strategy-backlog`; round selection and review records must
  record `milestone_id`, `direction_id`, and `extracted_item_id`.
- Runtime rounds should remain serial unless a planner-authored
  `worker-plan.json` proves import-facade and runtime-file ownership is
  disjoint.
- Compatibility removal is allowed only in
  `milestone-008-gated-compatibility-removals`, and only for selected surfaces
  whose gates are satisfied after milestones 005-007.
- The controller must not mark this family done solely because a roadmap list
  is exhausted. It must confirm no live rounds, no pending roadmap update, and
  no newly discovered unrepresented cleanup items remain.
