# Verification Contract

Roadmap id: `2026-05-08-00-framework-kernel-migration`
Roadmap revision: `rev-001`

## Baseline Checks

- Command: `cabal build all`
  Why: Builds every internal library, executable, and test target across the
  current moifold package split.
- Command: `cabal test watcher-core-test`
  Why: Runs the core regression suite, including replay, package-boundary,
  workflow spec, indexed spec, DSL, daemon, execution, adapter, classifier,
  repair, healthcheck, and fanout tests.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when staging is involved.

## Alignment Checks

- Framework thesis: touched workflow surfaces must preserve
  `State -> Event -> Decision -> EffectPlan -> Interpreter`; workflow code must
  not gain direct IO authority.
- Event-log truth: event codecs, golden fixtures, replay determinism, and
  transition failure reporting must stay stable unless a round explicitly
  introduces a versioned migration with old-log coverage.
- Observation boundary: agent output remains classified observation data before
  it becomes durable workflow state. Classifier evidence must not be weakened.
- Effect data boundary: effects remain inspectable, dry-runnable,
  permission-checked data before interpretation. Dry-run must not call runtime
  interpreters.
- Package ownership: `agent-workflow-core` must not import moifold lifecycle
  policy, Codex app-server transport, GitHub adapters, Aeson event codecs,
  daemon/runtime interpreters, filesystem ownership, PID/lock handling, or
  concrete `WatcherEvent` / `SomeWatcherState`.
- Adapter ownership: `agent-workflow-codex` must not import moifold issue/PR
  lifecycle modules; `agent-workflow-github` must not import moifold state
  machine or daemon modules.
- Compatibility: daemon result constructors, dry-run rendering, action
  ordering, request-id progression, compatibility write timing, runtime command
  rendering, prompt schemas, and structured-output requirements are stable
  unless a selected milestone explicitly authorizes a tested change.

## Task-Specific Checks

- Spec/API rounds must add focused law or parity tests for every newly exposed
  kernel surface, including replay determinism, observation consistency,
  permission soundness, dry-run safety, and terminal closure where applicable.
- DSL rounds must prove old and DSL-authored transitions emit the same event,
  next state, pre-commit effects, post-commit effects, replay result,
  permission result, action ordering, and dry-run reports.
- Core transaction or daemon rounds must cover failure stages, commit
  boundaries, audit reports, retryability, pre/post action partitioning, and
  both dry-run and execute behavior with fake interpreters.
- Adapter rounds must add protocol, parser, command-rendering, or classifier
  tests matching the touched adapter surface, and must keep recursive boundary
  source scans passing.
- Extraction-readiness rounds may be artifact-only, but their reviewer must
  verify roadmap, docs, package-boundary, import-graph, and compatibility-map
  evidence directly.

## Manual Checks

- For API-shape changes, reviewers must inspect exported module lists in
  `moifold.cabal` and confirm compatibility modules remain available or have a
  tested removal path.
- For docs/readiness rounds, reviewers must check that the docs distinguish
  implemented APIs from design goals and do not imply package publication.
- For any round touching workflow framework docs, reviewers must compare the
  change against `orchestrator/project-contract.md` and the active roadmap's
  non-goals.

## Roadmap Overrides

- This family explicitly migrates the control plane to `strategy-backlog`.
  Round selection and review records must record `milestone_id`,
  `direction_id`, and `extracted_item_id`; `roadmap_item_id` is only a legacy
  compatibility mirror when needed.
- Runtime rounds should remain serial unless a planner-authored
  `worker-plan.json` proves disjoint write scopes and conforms to
  `orchestrator/worker-plan-schema.md`.
- Do not publish packages in this roadmap family. The final milestone may only
  prepare extraction readiness evidence and package-boundary cleanup.
