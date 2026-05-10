# Retry Subloop: Facade Removal Readiness

Roadmap id: `2026-05-10-00-facade-removal-readiness`
Roadmap revision: `rev-001`

## Retry Policy

Retries must preserve the selected facade scope and the prior terminal-hold
boundary. A retry may narrow evidence, split a migration, add focused tests, or
record a hold. A retry must not turn missing evidence into deprecation or
removal approval.

## Common Retry Cases

- If import scans are incomplete, return the same round to planning or
  implementation to refresh the scan scope. Do not proceed to migration.
- If a replacement import changes behavior or ownership boundaries, revert that
  replacement in the round and record the blocker. Do not weaken tests to make
  the migration pass.
- If `Workflow.EventLog` or `Workflow.Permission` touches replay, permission, or
  phase-validation behavior without focused evidence, require focused evidence
  or record a hold for the surface.
- If deprecation or removal approval is missing, the round may record
  `defer`/`keep`/hold evidence but must not add deprecation pragmas, remove
  exposed modules, or delete facade modules.
- If a final report overstates completion, return it to the reporting stage and
  require explicit kept, deferred, deprecated, removed, and blocked surface
  sets.

## Removal Retry Boundary

Removal is never a fallback for a failed migration. An exact removal round must
already have every applicable gate satisfied and reviewer approval naming the
surface. If any gate fails, the lawful retry result is a narrower migration, a
defer/keep decision, or a terminal hold.

## Verification Carry-Forward

Every retry keeps the baseline validation from `verification.md` and adds the
focused checks required by the touched surface. When a retry changes public API
or Cabal exposure, reviewers must require package descriptor and documentation
evidence in the same reviewed slice.
