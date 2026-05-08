# Verification Contract

Roadmap id: `2026-05-09-00-external-package-extraction`
Roadmap revision: `rev-001`

## Baseline Checks

- Command: `cabal build all`
  Why: Builds moifold plus the current workflow package candidates.
- Command: `cabal test watcher-core-test`
  Why: Runs the regression suite covering replay, package-boundary scans,
  framework contracts, adapters, healthcheck, repair, and workflow behavior.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when staging is involved.

## Alignment Checks

- Release gate: no round may upload or publish packages unless the selected
  direction explicitly authorizes a release action and the reviewer approves
  the release evidence.
- Package ownership: `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github` must preserve the ownership split recorded in
  `orchestrator/project-contract.md` and the package extraction readiness
  report.
- Moifold consumer behavior: moifold must remain the product/runtime owner and
  must continue to build and pass `watcher-core-test` after package layout or
  dependency changes.
- Compatibility: current compatibility modules and files remain available
  unless a selected deprecation/removal direction proves safe removal with
  import, build, and behavior evidence.
- Event compatibility: event JSON `type` fields, schema versions, golden logs,
  replay policy, dry-run rendering, request-id progression, prompt schemas, and
  structured-output requirements must not change as incidental package work.
- Metadata truth: package metadata, version policy, changelogs, README/Haddock
  docs, and source distributions must describe implemented APIs and remaining
  moifold-owned policy accurately.

## Task-Specific Checks

- Package identity or metadata rounds must inspect package names, versions,
  license/source metadata, changelog policy, and release-gate text.
- Package layout rounds must run package-specific build/check commands for
  touched packages when descriptors exist, plus `cabal build all` and
  `cabal test watcher-core-test`.
- Source distribution rounds must run `cabal check` and source distribution
  validation for every package candidate they touch, and must record the exact
  commands and artifact paths.
- CI rounds must show that the configured matrix covers moifold plus package
  candidate build/test/check paths without dropping existing watcher tests.
- Docs rounds must compare package READMEs, Haddock/module docs, examples,
  changelog entries, and release notes against implemented APIs and public
  non-goals.
- Release-gate rounds must verify package artifacts, validation results, docs,
  changelog, compatibility/deprecation policy, and explicit go/no-go approval.

## Manual Checks

- Reviewers must inspect changed package descriptors or `cabal.project` wiring
  by hand when package layout changes.
- Reviewers must inspect generated source distributions or release-candidate
  artifacts when a round claims package readiness.
- Reviewers must verify any externally visible publication command before it is
  run; absence of explicit approval means no publication.
- Reviewers must check that docs and release notes do not imply moifold
  lifecycle, healthcheck, repair, runtime ownership, prompt policy, or event
  schemas are part of the reusable packages.

## Roadmap Overrides

- This family is `strategy-backlog`; round selection and review records must
  record `milestone_id`, `direction_id`, and `extracted_item_id`.
- Runtime rounds should remain serial unless a planner-authored
  `worker-plan.json` proves package-specific or docs/CI ownership is disjoint.
- Package publication is allowed only in the terminal release-gate direction
  and only after explicit review approval of the release plan. Other directions
  may prepare artifacts but must not upload them.
