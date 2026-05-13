# Retry Subloop: Highest-Value Cleanup

Roadmap id: `2026-05-11-00-highest-value-cleanup`
Roadmap revision: `rev-002`

## Retry Policy

Retries must preserve the selected cleanup surface, the compatibility boundary,
and the family goal of clean compatibility removal. A retry may narrow an import
slice, add focused behavior evidence, restore behavior, or classify a remaining
user as blocked/public-compat/runtime-compat/policy evidence. A retry must not
convert missing evidence into deprecation, runtime compatibility-file deletion,
Cabal exposure removal, or facade removal.

## Common Retry Cases

- If a production `Core.Ids` migration changes behavior, package ownership,
  command rendering, parsing, serialization, prompt/output text, runtime
  compatibility writes, healthcheck output, or public API shape, revert that
  migration in the round and either narrow the slice or record the exact
  blocker.
- If a milestone 003 slice cannot safely migrate a production file, the retry
  should classify that file with the missing evidence instead of leaving the
  milestone open without a finite closeout path.
- If a test/fixture `Core.Ids` migration loses coverage, changes assertion
  meaning, changes fixture JSON, or hides policy evidence, return to
  implementation or planning to preserve the original coverage and name the
  retained facade-import reason.
- If an EventLog or Permission bridge migration changes replay, audit,
  permission validation, public facade behavior, or stale qualified-use
  behavior, narrow the slice or classify the remaining facade use as an
  intentional bridge/policy owner.
- If AppServerClient public-surface cleanup lacks downstream, docs, Cabal, or
  behavior evidence, keep the public facade available and record the blocker.
- If fixture coverage is incomplete for a runtime compatibility cleanup, keep
  the round on fixture/test work or record the missing gate. Do not proceed to
  runtime-state cleanup.
- If `planner-state.json` and `planning-state.json` semantics become
  ambiguous, require an explicit contract artifact and focused tests before
  allowing a rename, deletion, or healthcheck behavior change.
- If a large-module split creates import cycles, mixed ownership, or behavior
  drift, narrow the split or return to tests before retrying.
- If deprecation or removal approval is missing, the lawful result is keep,
  defer, or an interim hold with exact blockers. That blocker must feed later
  roadmap work; it is not final success for this family.
- If terminal closeout finds any compatibility surface still kept, deferred,
  blocked, or hold-only, retry as roadmap expansion instead of approving the
  family as done.

## Removal Retry Boundary

Removal is allowed only when the selected round already has every applicable
gate satisfied and reviewer approval names the exact surface. The controller
must not treat a failed migration, a direct-owner import, or a locally unused
surface as a removal candidate.

## Verification Carry-Forward

Every retry keeps the baseline validation from `verification.md` unless the
reviewer records a valid artifact-only changed-path rationale. Retries that
touch public API, Cabal exposure, docs, compatibility fixtures, runtime
compatibility files, healthcheck, repair, event schemas, command rendering,
parsers, prompt/output text, or large runtime behavior must add focused checks
for that touched surface.

## Roadmap Expansion Boundary

Adding milestones is allowed only through the delegated update-roadmap path and
reviewed roadmap revision rules. The expansion must name the new milestones,
their dependencies, verification gates, and evidence that justifies keeping the
family open. The family must keep expanding milestones until the reviewed final
report proves all roadmap-covered compatibility surfaces have been removed
cleanly or migrated away from supported compatibility paths.
