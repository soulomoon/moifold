# Verification Contract

## Baseline Checks

- Command: `cabal build all`
  Why: Builds every internal library, executable, and test target across the moifold package split.
- Command: `cabal test watcher-core-test`
  Why: Runs the core regression suite, including golden replay, package-boundary, workflow-facade, daemon, execution, indexed-spec, and adapter tests.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when a round stages changes before review or merge.

## Task-Specific Checks

- Add focused tests for the selected roadmap item before relying on new behavior.
- For every indexed PR-review port, prove old compatibility planning and indexed planning emit the same event, source label, target label, next state label, pre-commit effect plan, post-commit effect plan, observed effects, replay result, and permission result.
- For classifier-backed transitions, keep classifier evidence at least as strong as the compatibility path and test complete, incomplete, blocked, malformed, problems, and clean outputs when the selected item touches those cases.
- For mergeability and merge terminal transitions, verify action order, merge pre-commit behavior, request-id progression, and dry-run output against existing expectations.
- For daemon routing rounds, prove `DaemonTickResult`, `DaemonObservedTickResult`, detailed transaction failures, dry-run reports, and action ordering remain compatible.
- For package-boundary-adjacent rounds, keep recursive boundary assertions passing: `agent-workflow-core` must not import moifold lifecycle policy, Codex app-server transport, GitHub adapters, daemon/runtime interpreters, Aeson event codecs, or concrete `WatcherEvent`/`SomeWatcherState` ownership.
- Do not change event `type` fields, JSON schemas, golden fixtures, or public compatibility module availability unless a later roadmap item explicitly says so.

## Approval Criteria

- Every baseline check passes.
- Every selected task-specific check passes.
- `selection.md` records `roadmap_id`, `roadmap_revision`, `roadmap_dir`, and `roadmap_item_id`.
- `review.md` records evidence for the round.
- `review-record.json` records the same roadmap identity when the round finalizes.
- The round stays inside the active roadmap bundle recorded in `orchestrator/state.json`.
- The round's `roadmap_id` is exactly `2026-05-07-00-workflow-kernel-indexing`, not a recomputed title-derived value.
- If worker fan-out is used later, `worker-plan.json` must exist and reviewer approval must be based on the integrated round result.
- The reviewer decision is explicit.

## Reviewer Record Format

### Round `<round-id>`

- Baseline checks:
- Task-specific checks:
- Decision:
- Evidence:
