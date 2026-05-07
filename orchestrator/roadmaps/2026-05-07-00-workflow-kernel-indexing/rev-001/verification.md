# Verification Contract

## Baseline Checks

- Command: `cabal build all`
  Why: Builds every internal library, executable, and test target across the moifold package split.
- Command: `cabal test watcher-core-test`
  Why: Runs the core regression suite, including golden replay, package-boundary, workflow-facade, daemon, execution, and adapter tests.
- Command: `git diff --check`
  Why: Catches whitespace errors before review.
- Command: `git diff --cached --check`
  Why: Required when a round stages changes before review or merge.

## Task-Specific Checks

- Add focused tests for the selected roadmap item before relying on new behavior.
- For extraction rounds, verify behavior parity against the compatibility path touched by the round.
- For package-boundary rounds, verify Cabal exposure and forbidden-import assertions.
- For indexed-spec rounds, verify old and indexed paths emit the same event, next state label, effect plan, and replay result for the ported slice.

## Approval Criteria

- Every baseline check passes.
- Every task-specific check passes.
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
