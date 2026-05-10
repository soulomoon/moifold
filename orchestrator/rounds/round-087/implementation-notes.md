### Changes Made

- `orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`: added the approved artifact-only compatibility fixture gap inventory for planning, daemon, block, repair, runtime-owner, checked-in compatibility snapshots, and live `issue-snapshot.json` surfaces.
- `orchestrator/rounds/round-087/implementation-notes.md`: recorded implementation scope, verification, and blockers for the round.

### Tests

- `test -f orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`: verifies the required inventory artifact exists.
- `test ! -e orchestrator/rounds/round-087/worker-plan.json`: verifies no worker plan was created.
- `git diff --name-only`: verifies changed paths stay artifact-only.
- `git diff -- orchestrator/rounds/round-087/plan.md orchestrator/rounds/round-087/compatibility-fixture-gap-inventory.md`: verifies the plan/inventory diff is inspectable.
- `git diff --check`: verifies whitespace and patch formatting.
- `git status --short --untracked-files=all`: records final worktree scope.

### Notes

The inventory records blockers only. It does not claim removal, rename,
deprecation, migration, Cabal exposure, healthcheck behavior, repair behavior,
or runtime behavior approval.

Key blockers found:

- `planner-state.json` and `planning-state.json` need explicit distinct-surface
  contract fixtures and tests before any rename, reader change, or cleanup.
- `planning-state.json`, `repair-state.json`, and live `issue-snapshot.json`
  are not current healthcheck readers; this is current behavior evidence, not
  approval to keep or change it permanently.
- `runtime-owner.json` still needs checked-in lease fixtures plus explicit
  healthcheck/script field-path policy evidence.
- `daemon-state.json` and `block-state.json` have some golden snapshot
  coverage, but active/stopped daemon and repair-failure block fixtures remain
  missing.
- External operator/downstream direct-reader inventory remains required before
  runtime compatibility-file migration or removal decisions.
