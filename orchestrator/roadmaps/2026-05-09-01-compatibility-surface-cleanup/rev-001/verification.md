# Verification Contract

Roadmap id: `2026-05-09-01-compatibility-surface-cleanup`
Roadmap revision: `rev-001`

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

## Alignment Checks

- Evidence before policy: policy updates must cite current import scans,
  producer/consumer inventories, or runtime compatibility evidence.
- Policy before removal: no compatibility surface may be removed before a
  reviewed policy classifies that surface as a removal candidate.
- Runtime compatibility: rounds touching compatibility files must preserve
  event JSON `type` fields, schema versions, golden logs, repair behavior,
  healthcheck behavior, write timing, and operator recovery unless an explicit
  selected direction authorizes a proven migration.
- Import compatibility: rounds touching import facades must provide recursive
  import scans, replacement paths, Cabal exposed-module analysis when relevant,
  and package-boundary test evidence.
- Roadmap expansion: before final removals, a selected round must inspect the
  evidence and either expand the roadmap with newly discovered cleanup items or
  record why no expansion is needed.
- Removal approval: final removal rounds must name the exact surfaces removed,
  list every satisfied gate, and receive reviewer approval before merge.

## Task-Specific Checks

- Import-facade inventory rounds must scan source, tests, examples, package
  docs, Cabal descriptors, and public package docs for compatibility imports
  and preferred replacements.
- Runtime compatibility-file inventory rounds must scan read sites, write
  sites, repair code, healthcheck code, golden fixtures, snapshots, CLI replay
  paths, and operator runbook references.
- Readiness rounds must add or identify focused tests for any future removal
  candidate; missing tests should block removal classification.
- Policy rounds must keep `orchestrator/project-contract.md` and
  `docs/agentic-workflow-framework/*` wording aligned with current code.
- Removal rounds must update source, tests, docs, and Cabal exposed modules in
  the same reviewed slice when a removed surface is public.

## Manual Checks

- Reviewers must inspect every compatibility surface classified as removable
  and confirm the replacement or unsupported-user decision is explicit.
- Reviewers must inspect old-log, golden replay, repair, and healthcheck
  evidence before approving runtime compatibility-file removal.
- Reviewers must inspect public docs for overclaims: cleanup readiness is not
  package publication, deprecation policy is not removal approval, and package
  extraction does not move moifold lifecycle policy into reusable packages.
- Reviewers must verify that a late-roadmap expansion check ran before final
  removal work starts.

## Roadmap Overrides

- This family is `strategy-backlog`; round selection and review records must
  record `milestone_id`, `direction_id`, and `extracted_item_id`.
- Runtime rounds should remain serial unless a planner-authored
  `worker-plan.json` proves import-facade and runtime-file ownership is
  disjoint.
- Compatibility removal is allowed only in
  `milestone-005-gated-compatibility-removals`, and only for selected surfaces
  whose gates are satisfied.
- The controller must not mark this family done solely because the initial
  roadmap list is exhausted. It must confirm no live rounds, no pending
  roadmap update, and no newly discovered unrepresented cleanup items remain.
