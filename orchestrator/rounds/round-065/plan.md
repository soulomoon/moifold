### Goal

Record current evidence for the `repair-state.json` compatibility surface:
repair execute write-order readback, compatibility rewrite ordering, production
reader inventory, current healthcheck or non-healthcheck policy, fixture or
fixture-gap evidence, and blockers before any later cleanup, migration,
schema, timing, healthcheck, projection, or removal decision.

### Approach

Keep this as a sequential evidence-only round. Do not change repair behavior,
compatibility rewrite behavior, healthcheck behavior, event schemas, filenames,
fixtures, production source, tests, roadmap files, controller state, or package
metadata. Use the stable invariants in `orchestrator/project-contract.md`
instead of restating repo-wide compatibility rules.

The implementation should create a round-local evidence artifact, expected as
`orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md`, plus
round-local implementation notes if the implementer normally records them. A
durable policy-doc pointer may be updated only if the implementation owner has
write permission for docs in that phase; if updated, it must keep
`repair-state.json` classified as `defer` and must not approve migration,
healthcheck surfacing, or removal.

Worker fan-out is not justified. The work is a single compatibility surface
with tightly coupled readbacks across repair, healthcheck, fixtures, policy,
and blockers; splitting it would add coordination cost without independent
write ownership.

### Steps

1. Re-read the active round/control inputs before editing:
   `orchestrator/rounds/round-065/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the round remains evidence-only and `repair-state.json` remains
   selected under `direction-014-repair-state-fixture-reader-policy`.
2. Refresh the prior evidence from rounds 053, 055, 057, and 064, focusing only
   on the `repair-state.json` parts. Carry forward prior findings only when
   the current source scan still proves them.
3. Inspect the repair writer path in
   `src/CodexWatcher/Cli/Command/Replay.hs`. Record that execute mode archives
   the invalid event log, writes repaired `events.jsonl`, writes
   `repair-state.json`, rewrites compatibility files from the repaired replay
   state, then removes stale `block-state.json`. Also record the
   `writeRepairSummary` fields and that this summary is produced only by
   `repair-invalid-state --execute`.
4. Inspect `src/CodexWatcher/EventLogRepair.hs` enough to identify the repair
   plan data that feeds `repair-state.json`: strategy, failure index/type,
   failure reason, inserted/dropped event names, and final replay state.
   Do not propose new repair rules or different event ordering.
5. Inspect `src/CodexWatcher/Healthcheck.hs`, especially `stateFileSpecs`,
   `sharedStateFiles`, and `readStateFiles`. Record the current healthcheck
   policy explicitly: issue planning, issue implementation, and PR review
   healthcheck state-file lists do not include `repair-state.json`; current
   status is non-healthcheck evidence for a repair summary output, not approval
   to remove the file or change healthcheck.
6. Run a production-reader inventory for `repair-state.json` across
   `src`, `app`, `scripts`, `docs`, `test`, `golden`, and relevant
   orchestrator evidence. Separate true production readers from tests,
   docs, and prior evidence artifacts. Record any docs/runbook mentions as
   operator-policy context, not as Haskell production readers.
7. Run the fixture search for checked-in `repair-state.json` files. If none
   exist, record the exact command and no-output result as a fixture gap. Do
   not create a fixture unless a current checked-in old/current fixture source
   is already present and the selected implementation scope explicitly permits
   adding fixture evidence.
8. Inspect `test/Main.hs` around
   `issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract`. Record
   the existing test coverage as source-order behavior coverage only:
   dry-run reports the plan before mutation, and execute ordering preserves
   repair-state-before-compatibility and stale-block removal after compatibility
   rewrite. Do not describe this as fixture round-trip coverage.
9. Create the round-local evidence artifact with sections for scope/non-goals,
   repair writer readback, compatibility rewrite ordering, repair summary JSON
   fields, production-reader inventory, healthcheck non-healthcheck policy,
   fixture evidence or fixture gap, existing test coverage, and blockers.
10. Keep blockers conservative. At minimum, retain missing checked-in
    `repair-state.json` fixture or fixture round-trip coverage, missing
    external operator/downstream direct-reader inventory, no selected
    healthcheck behavior-change authorization, no migration/removal approval,
    and no approval to alter repair write order, compatibility rewrite order,
    stale `block-state.json` cleanup, filename, schema, or event `type`
    fields.
11. If a docs policy pointer is updated by the implementer, limit it to
    adding round-065 evidence to the existing `repair-state.json` row while
    preserving `defer` and the missing gates. Do not touch roadmap revision
    files or `orchestrator/project-contract.md`.
12. Record implementation notes with files changed, exact scans run, the
    fixture-search result, any skipped baseline rationale, and a statement
    that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,260p' orchestrator/rounds/round-065/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '1,130p' src/CodexWatcher/Cli/Command/Replay.hs
sed -n '1,220p' src/CodexWatcher/EventLogRepair.hs
sed -n '244,282p' src/CodexWatcher/Healthcheck.hs
sed -n '1970,2010p' test/Main.hs
```

Run the focused scans and record results:

```sh
find . -path './.git' -prune -o -name 'repair-state.json' -print
rg -n "repair-state\\.json|repair state|repair-state|repairInvalidState|repair-invalid-state|writeRepairSummary|writeCompatibilityFiles|removeFileIfExists|issueImplementEventLogRepairCliPreservesDryRunAndExecuteContract" src app test scripts docs golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-064
rg -n "stateFileSpecs|sharedStateFiles|readStateFiles|blockedState|runtimeOwner|daemonState|issueState|watcherState|checkerState|agentState|reviewerState" src/CodexWatcher/Healthcheck.hs test/Main.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-065
rg -n "repair-state\\.json|defer|non-healthcheck|healthcheck|fixture|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-065
```

Validate the artifact-only diff:

```sh
git status --short
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-065
```

If the diff remains limited to round-local orchestrator artifacts, and an
allowed policy-doc pointer if explicitly permitted for the implementation
phase, Cabal and package baselines may be skipped under the active verification
contract. If production source, tests, fixtures, schemas, package files,
scripts, roadmap files, or controller state change, the implementer must stop
and either narrow the diff back to the selected evidence scope or run the full
baseline from `verification.md`:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```
