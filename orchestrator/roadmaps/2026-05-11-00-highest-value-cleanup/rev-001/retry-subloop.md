# Retry Subloop: Highest-Value Cleanup

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-001`

## Retry Policy

Retries must preserve the selected cleanup surface and the compatibility
boundary. A retry may narrow a split, add fixture evidence, restore behavior,
or record a hold. A retry must not convert missing evidence into deprecation,
runtime compatibility-file deletion, Cabal exposure removal, or facade
removal.

## Common Retry Cases

- If a test split loses coverage, changes assertion meaning, or hides a helper
  behind unclear ownership, return to implementation or planning to preserve
  the original coverage and name the helper boundary.
- If fixture coverage is incomplete, keep the round on fixture/test work or
  record the missing gate. Do not proceed to runtime-state cleanup.
- If `planner-state.json` and `planning-state.json` semantics remain ambiguous,
  require an explicit contract artifact and focused tests before allowing a
  rename, deletion, or healthcheck behavior change.
- If an import migration changes behavior, package ownership, command
  rendering, parsing, or public API shape, revert that migration in the round
  and record the blocker.
- If a large-module split creates import cycles, mixed ownership, or behavior
  drift, narrow the split or return to tests before retrying.
- If deprecation or removal approval is missing, the lawful result is keep,
  defer, or a terminal hold with exact blockers.

## Removal Retry Boundary

Removal is allowed only when the selected round already has every applicable
gate satisfied and reviewer approval names the exact surface. The controller
must not treat a failed migration or a locally unused surface as a removal
candidate.

## Verification Carry-Forward

Every retry keeps the baseline validation from `verification.md` unless the
reviewer records a valid artifact-only changed-path rationale. Retries that
touch public API, Cabal exposure, docs, compatibility fixtures, runtime
compatibility files, healthcheck, repair, event schemas, or large runtime
behavior must add focused checks for that touched surface.
