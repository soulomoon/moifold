### Goal

Record current evidence for the `runtime-owner.json` compatibility surface:
runtime owner store readback, runtime owner CLI readback, `lease` field-path
evidence, automatic-loop ownership timing, current healthcheck behavior,
checked-in fixture or fixture-gap evidence, and operator script/runbook
inventory including `scripts/restart-watcher`.

The round must preserve `runtime-owner.json` as live daemon ownership state. It
must not change the filename, schema, lease fields, daemon ownership behavior,
healthcheck behavior, repair behavior, compatibility timing, production source,
tests, fixtures, scripts, runbooks, roadmap files, controller state, package
metadata, deprecation status, migration status, removal approval, publication,
upload, or release approval.

### Approach

Keep this as a sequential evidence-only round. Use the stable invariants in
`orchestrator/project-contract.md` instead of restating repo-wide compatibility
rules, and use the active verification contract to keep the evidence bounded
to runtime compatibility behavior.

The implementation should create one round-local evidence artifact, expected
as
`orchestrator/rounds/round-066/runtime-owner-fixture-operator-inventory.md`,
plus implementation notes if the implementer normally records them. Do not
write a worker plan. The source paths are coupled through the same ownership
file, healthcheck readback, shell restart path, and fixture gap, so worker
fan-out is not justified.

### Steps

1. Re-read the active round/control inputs before editing:
   `orchestrator/rounds/round-066/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the round remains evidence-only under
   `direction-015-runtime-owner-fixture-operator-inventory`.
2. Refresh prior evidence from rounds 053, 055, 057, 058, 064, and 065, but
   carry forward only findings still supported by current source scans. Treat
   round 058's `runtime-owner.json` follow-up as the direct source of this
   selected direction.
3. Inspect `src/CodexWatcher/Runtime/Owner/Store.hs` and
   `src/CodexWatcher/Runtime/Owner/Types.hs`. Record the current file path
   `<stateDir>/runtime-owner.json`, the top-level `lease` object, and the
   exact accepted lease fields: `lease.runtime`, `lease.pid`,
   `lease.hostname`, `lease.claimedAt`, `lease.expiresAt`, and
   `lease.eventLogHeadHash`. Record that owner-only JSON and top-level
   owner-plus-lease JSON are rejected by current parsing.
4. Inspect `src/CodexWatcher/Runtime/Owner/Cli.hs`. Record the current CLI
   ownership behavior: validate in execute mode, write fresh Haskell leases,
   renew leases, clear only clearable inactive leases, clear current-process
   leases on execute cleanup, no-op in dry-run where applicable, and use the
   event-log head hash in fresh leases. Do not propose a lease migration or
   new clear policy.
5. Inspect runtime-owner read sites found by a focused scan. Include at least
   `src/CodexWatcher/AutomaticLoop/Runner.hs`, and if still present also
   record `src/CodexWatcher/Cli/Command/Observe.hs` and
   `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` as current readers or
   validators. Record automatic-loop timing: validate before startup, renew
   before each loop tick, repair pid file after renewal, reconcile
   compatibility from event-log replay, and clear only the current-process
   lease on exit.
6. Inspect `src/CodexWatcher/Healthcheck.hs`, especially `readStateFiles`,
   `stateFileSpecs`, `sharedStateFiles`, and the `runtimeOwner` summary field.
   Record current behavior exactly: healthcheck reads `runtime-owner.json` for
   issue planning, issue implementation, and PR review through the
   `runtimeOwner` state key, and current summary extraction uses configured
   `runtimeOwner` or `lookupStateText ["runtimeOwner", "owner"]`. Record the
   `lease.runtime` versus `runtimeOwner.owner` field-path mismatch as current
   evidence only, not as a planned healthcheck behavior change.
7. Inspect `scripts/restart-watcher`. Record that it reads
   `runtime-owner.json` with shell `sed` to extract the first numeric `pid`,
   attempts to stop that owner pid along with pid-file pids, and removes
   `runtime-owner.json` during cleanup. Keep this as operator-script evidence;
   do not modify the script.
8. Inspect operator runbook references, including
   `docs/watcher-agent-runbook/project-watch/01-preflight.md`,
   `docs/watcher-agent-runbook/checklists/operator-checklist.md`, and the
   current runtime-compatibility policy row in
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Record whether these documents treat `runtime-owner.json` as an active
   operator gate, inactive-pid prerequisite, policy blocker, or only historical
   context. Do not edit docs or runbooks in this round.
9. Run a production/test/docs/operator inventory for `runtime-owner.json`,
   `RuntimeOwner`, `runtimeOwner`, `runtime owner`, `lease.runtime`, and shell
   owner-pid parsing across `src`, `app`, `test`, `scripts`, `docs`,
   `examples`, `golden`, and relevant prior round artifacts. Separate true
   production readers/writers from tests, docs, scripts, policy evidence, and
   prior-round evidence artifacts.
10. Run the checked-in fixture search for `runtime-owner.json`. If no file is
    found, record the exact command and no-output result as a fixture gap. Do
    not create a fixture; this selected round asks for fixture or fixture-gap
    evidence, not fixture creation.
11. Inspect existing tests in `test/Main.hs` around runtime owner parsing,
    invalid older shapes, clear rejection for running leases, current-process
    cleanup, watcher log lease events, and healthcheck source assertions.
    Record this as behavior/source assertion coverage only. Do not describe it
    as checked-in fixture coverage.
12. Create the round-local evidence artifact with sections for scope and
    non-goals, store/schema readback, CLI readback, automatic-loop timing,
    healthcheck behavior and field-path evidence, operator script inventory,
    operator runbook inventory, fixture evidence or fixture gap, existing test
    coverage, current classification, and blockers before any later cleanup.
13. Keep blockers conservative. At minimum, retain missing checked-in
    `runtime-owner.json` fixture coverage, missing old/current fixture
    round-trip coverage, current healthcheck `owner` versus writer
    `lease.runtime` field-path mismatch or explicit reviewed policy gap,
    external operator/downstream script inventory limits beyond repo-local
    evidence, and no selected approval for filename, schema, lease-field,
    healthcheck, daemon ownership, restart-script, migration, deprecation, or
    removal changes.
14. Record implementation notes with files changed, exact scans run, fixture
    search result, any skipped baseline rationale, and a statement that no
    production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,260p' orchestrator/rounds/round-066/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '1,220p' src/CodexWatcher/Runtime/Owner/Store.hs
sed -n '1,260p' src/CodexWatcher/Runtime/Owner/Types.hs
sed -n '1,320p' src/CodexWatcher/Runtime/Owner/Cli.hs
sed -n '1,180p' src/CodexWatcher/AutomaticLoop/Runner.hs
sed -n '180,285p' src/CodexWatcher/Healthcheck.hs
sed -n '130,270p' scripts/restart-watcher
sed -n '2960,3135p' test/Main.hs
```

Run the focused scans and record results:

```sh
find . -path './.git' -prune -o -name 'runtime-owner.json' -print
rg -n "runtime-owner\\.json|runtime owner|RuntimeOwner|runtimeOwner|readRuntimeOwnerMarker|readRuntimeOwner|writeRuntimeLease|validateRuntimeOwnerForExecution|renewRuntimeOwnerForExecution|clearRuntimeLease|clearRuntimeLeaseIfOwnedByCurrentProcess|read_runtime_owner_pid" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-064 orchestrator/rounds/round-065
rg -n "lease\\.runtime|\\[\"runtimeOwner\", \"owner\"\\]|lookupStateText \\[\"runtimeOwner\", \"owner\"\\]|\"lease\"|\"runtime\"|\"pid\"|\"hostname\"|\"claimedAt\"|\"expiresAt\"|\"eventLogHeadHash\"" src/CodexWatcher/Runtime/Owner src/CodexWatcher/Healthcheck.hs test/Main.hs scripts docs orchestrator/rounds/round-066
rg -n "runtime-owner\\.json|runtime owner|inactive pid|running pid|restart-watcher|operator|downstream|fixture|healthcheck|lease\\.runtime|removal|migration|defer|keep" docs/watcher-agent-runbook docs/agentic-workflow-framework orchestrator/rounds/round-066
```

Validate the artifact-only diff:

```sh
git status --short
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-066
```

If the diff remains limited to round-local orchestrator artifacts, Cabal and
package baselines may be skipped under the active verification contract. If
production source, tests, fixtures, schemas, scripts, docs, package files,
roadmap files, controller state, or project contract change, the implementer
must stop and either narrow the diff back to the selected evidence scope or
run the full baseline from `verification.md`:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If files are staged later, also run:

```sh
git diff --cached --check
```

### Worker Fan-Out

Worker fan-out is not used. The selected evidence is one tightly coupled
compatibility surface whose store, CLI, automatic-loop, healthcheck,
operator-script, runbook, fixture, and blocker evidence should be integrated
in one sequential pass.
