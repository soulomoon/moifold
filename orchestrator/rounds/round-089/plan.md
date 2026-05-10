### Goal

Lock the current `runtime-owner.json` healthcheck contract without changing
runtime-owner production, healthcheck behavior, repair behavior, file names, or
schemas.

The round should make explicit that healthcheck reads
`runtime-owner.json` as the `runtimeOwner` state surface for issue planning,
issue implementation, and PR review, while the runtime owner producer writes
lease-shaped JSON under top-level `lease`. It should also preserve the current
field-path behavior: healthcheck derives the summary owner from
`["runtimeOwner","owner"]`, so the lease-shaped JSON produced by
`runtimeLeaseJson` does not currently populate the top-level healthcheck
`runtimeOwner` summary unless config supplies `runtimeOwner`.

### Approach

Keep this as a narrow source/test/policy contract slice. Add focused assertions
around the existing code paths rather than adding fixtures, changing readers, or
changing the runtime owner producer.

Use the existing round-088 pattern: focused tests/source-policy assertions plus
a minimal compatibility-policy note if needed. Do not create broad runtime
compatibility fixtures or an operator/downstream inventory in this round; those
remain later gates from round-087.

Key current evidence to preserve:

- `src/CodexWatcher/Runtime/Owner/Store.hs` writes `runtime-owner.json` via
  `runtimeLeaseJson`, whose current shape is top-level `lease` with nested
  `runtime`, `pid`, `hostname`, `claimedAt`, `expiresAt`, and
  `eventLogHeadHash`.
- `src/CodexWatcher/Healthcheck.hs` includes
  `("runtimeOwner", "runtime-owner.json")` in the issue-planning,
  issue-implementation, and PR-review state file specs.
- `src/CodexWatcher/Healthcheck.hs` currently computes the summary field with
  `config.runtimeOwner <|> lookupStateText ["runtimeOwner", "owner"] states`.
- `scripts/restart-watcher` still parses the first `"pid"` string in
  `runtime-owner.json` and removes the file during cleanup. This round may
  mention that as existing evidence, but it should not change script behavior.

### Steps

1. Reconfirm the current runtime-owner producer and healthcheck reader paths
   with focused source inspection of `Runtime/Owner/Store.hs`,
   `Healthcheck.hs`, `test/Main.hs`, `test/HealthcheckSpec.hs`,
   `test/BoundaryPolicySpec.hs`, `scripts/restart-watcher`, and the existing
   compatibility policy row.
2. Add or strengthen focused runtime-owner JSON assertions in the existing test
   area that already covers runtime-owner behavior. The assertions should lock
   that `runtimeLeaseJson` has no top-level `owner`, has top-level `lease`, and
   stores the owner identity under the nested `lease.runtime` path.
3. Add a focused healthcheck contract assertion, preferably in
   `test/HealthcheckSpec.hs` if it can exercise rendered healthcheck summary
   behavior cleanly, otherwise as a source-policy assertion in
   `test/BoundaryPolicySpec.hs`. It must prove:
   - healthcheck maps all relevant domains to
     `("runtimeOwner", "runtime-owner.json")`;
   - the summary owner lookup remains `["runtimeOwner", "owner"]`;
   - healthcheck does not switch this round to reading the lease-shaped
     `["runtimeOwner","lease","runtime"]` path.
4. If the existing compatibility policy row would otherwise remain ambiguous,
   add one narrow note to
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   recording the preserved current field-path contract and the missing later
   gates. Keep the note as evidence/blocker language only; do not imply
   resolution, migration, deprecation, removal, or behavior approval beyond the
   current contract.
5. Keep the diff out of production behavior, runtime owner producer code,
   healthcheck reader code, repair code, scripts, fixtures, roadmap files,
   controller state, file renames/deletions, schema migrations, and broad
   compatibility cleanup.
6. Record implementation notes for the round only if the implementer normally
   records them for reviewed rounds; those notes must say this is a current
   contract/evidence slice, not cleanup approval.

### Verification

Run focused and baseline checks appropriate to the touched files:

- `cabal test watcher-core-test`
- `git diff --check`
- `git status --short --untracked-files=all`

If only round-local artifacts are changed by a planner/review pass, package
tests may be skipped under the active verification exception. An implementation
round that changes tests or docs should run `cabal test watcher-core-test`.

Reviewers should confirm:

- no production code behavior changed;
- no `runtime-owner.json` producer or schema changed;
- healthcheck still reads the same file names and the same current
  `["runtimeOwner","owner"]` summary path;
- the lease-shaped JSON mismatch is recorded as an explicit preserved current
  contract or blocker, not silently fixed;
- no broad fixture campaign, file deletion/rename, repair behavior change,
  schema migration, deprecation/removal, roadmap edit, or controller state edit
  was introduced.

### Worker Fan-Out

Worker fan-out is not used.

This round is intentionally serial. The selected surface is one tightly coupled
runtime-owner healthcheck contract, and the likely changes are limited to
focused tests/source-policy assertions plus an optional narrow policy note.
There are no clear non-overlapping ownership boundaries that would justify a
`worker-plan.json`.
