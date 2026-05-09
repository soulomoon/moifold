### Goal

Produce runtime compatibility-file behavior-gate evidence for the round 053
surfaces:

- `issue-state.json`
- `daemon-state.json`
- `planning-state.json`
- PR review state files and PR URL state fields
- `block-state.json`
- `repair-state.json`
- `runtime-owner.json`
- compatibility snapshots

The round should turn the round 053 inventory into a reviewable behavior-gates
report, preferably
`orchestrator/rounds/round-055/runtime-file-behavior-gates.md`, with
surface-by-surface evidence for golden replay, repair, healthcheck,
write timing, old snapshot/file assumptions, and conservative
`keep`, `defer`, or `remove-later` readiness notes.

The round must not change file names, schemas, write timing, event JSON
`type` fields, healthcheck or repair design, daemon ownership, app-server
policy, cleanup policy, import-facade policy, deprecation/removal status,
roadmap scope, or final removal approval.

### Approach

Keep the implementation sequential. These runtime compatibility files share
event-log replay, repair, healthcheck, startup/reconciliation, and snapshot
assumptions, so one integrated evidence pass is safer than worker fan-out.

Use `orchestrator/project-contract.md` as the stable compatibility contract
and the active roadmap verification contract as the baseline check list.
Start from
`orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md` and
`orchestrator/rounds/round-054/import-replacement-readiness.md`; round 054 is
context only and must not pull import-facade policy work into this round.

Prefer source-backed documentation first. Add focused tests or source
assertions only when the behavior-gates report depends on a claim that is not
already protected by existing tests. Any added tests should prove the current
contract; they must not migrate schemas, rewrite runtime behavior, or weaken
existing coverage.

### Steps

1. Re-read the round inputs before writing evidence:
   `orchestrator/rounds/round-055/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`,
   `orchestrator/rounds/round-053/runtime-compatibility-file-inventory.md`,
   and `orchestrator/rounds/round-054/import-replacement-readiness.md`.
2. Create one round-local report at
   `orchestrator/rounds/round-055/runtime-file-behavior-gates.md`. Start it
   with scan commands, representative evidence, and a summary table for every
   selected surface with columns for golden replay, repair, healthcheck,
   write timing, old snapshot/file evidence, protecting tests, missing
   evidence, and readiness note.
3. Re-run targeted scan commands from the round 053 inventory to refresh the
   current evidence. Include at least filename, text, and file-IO scans over
   `src`, `app`, `test`, `scripts`, `docs`, `examples`, `golden`, and
   orchestrator evidence, focused on the selected file names, PR URL/state
   wording, block/repair/runtime-owner wording, snapshots, replay, healthcheck,
   repair, and compatibility writes.
4. For `issue-state.json`, record the exact golden fixtures, snapshot readers,
   healthcheck reads, PR URL field coverage, repair rewrite path, and
   compatibility write timing that currently protect it. Note any old-state
   combinations that remain unrepresented by local fixtures or tests.
5. For `daemon-state.json`, record idle/active/stopped/current summary
   producers, golden or old snapshot tolerance evidence, healthcheck reads,
   repair rewrite path, startup/reconciliation timing, and any missing active
   or stopped fixture coverage.
6. For `planning-state.json`, distinguish the direct `RecordPlanningGraph`
   planned write from compatibility projection writes. Record existing tests
   for graph recording and compatibility parity, then explicitly mark missing
   healthcheck and checked-in old snapshot coverage unless new focused tests
   are added.
7. For PR review state files and PR URL state fields, map the selected
   roadmap wording to current files and fields: `pr_url` in
   `issue-state.json`, PR review config `prUrl`, and PR review
   `watcher-state.json`, `checker-state.json`, `agent-state.json`, and
   `reviewer-state.json`. Record golden replay/bootstrap fixtures,
   healthcheck reads, classifier tests, compatibility write tests, and the
   absence of a separate dedicated PR URL file.
8. For `block-state.json`, record both direct `RecordBlocked` writes and
   compatibility projection writes, blocked golden fixtures, healthcheck reads,
   snapshot reads, repair-success stale-block removal, runner repair-failure
   block-state behavior, and any missing fixture for the repair-failure shape.
9. For `repair-state.json`, record the `repair-invalid-state --execute` write
   order: archive old event log, write repaired `events.jsonl`, write
   `repair-state.json`, rewrite compatibility files, and remove stale
   `block-state.json`. Note that healthcheck and production readers do not
   currently consume `repair-state.json` unless fresh evidence shows otherwise.
10. For `runtime-owner.json`, record lease write/read/renew/clear behavior,
    automatic-loop startup and tick timing, healthcheck surfacing,
    `scripts/restart-watcher` assumptions, parser rejection of older owner-only
    shapes, and the current absence of a checked-in owner fixture.
11. For compatibility snapshots, separate checked-in golden fixture directories
    from live `issue-snapshot.json` writes. Record replay/bootstrap tests,
    snapshot write-before-turn timing tests, and missing checked-in live
    `issue-snapshot.json` fixture evidence.
12. After the report is drafted, inspect existing tests in `test/Main.hs` and
    focused source modules for each report claim. Add focused tests or source
    assertions only for claims that would otherwise be unprotected and are
    reasonable to protect within this bounded round, such as source-order
    assertions, fixture decode checks, write-order checks, or read-only
    healthcheck surfacing. Do not add broad migration tests or change runtime
    behavior to make tests pass.
13. Assign conservative readiness notes:
    `keep` for surfaces that are current runtime/operator contracts with no
    plausible removal path from current evidence; `defer` for surfaces with
    known replacement or weaker usage but missing old-log, healthcheck, repair,
    write-timing, fixture, or external-operator evidence; and `remove-later`
    only if the report names every required gate and existing or newly added
    tests protect it. Do not treat a readiness note as deprecation or removal
    approval.
14. Review the final diff for role and scope drift. Allowed outputs are this
    plan, the behavior-gates report, focused tests or source assertions if
    needed, and implementation evidence. Do not edit production behavior,
    roadmap files, `orchestrator/state.json`, implementation notes, reviews,
    merge notes, cleanup-policy docs, compatibility file names, schemas,
    snapshots, or event JSON type fields.

### Verification

Record the refreshed evidence commands in the behavior-gates report or
implementation notes. The implementation should include commands equivalent
to these focused scans:

```sh
find . -name 'issue-state.json' -o -name 'daemon-state.json' -o -name 'planning-state.json' -o -name '*pr-url*' -o -name '*pr-state*' -o -name '*block*state*' -o -name '*repair*state*' -o -name '*owner*' -o -name '*snapshot*'
rg -n "issue-state\\.json|daemon-state\\.json|planning-state\\.json|pr-url|pr state|PR URL|pr_url|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|runtime owner|compatibility snapshot|issue-snapshot\\.json|snapshot" src app test scripts docs examples golden orchestrator
rg -n "compatibilityStateWrites|CompatibilityWrite|writeCompatibility|RecordBlocked|RecordPlanningGraph|repair-invalid-state|repair-state\\.json|Healthcheck|healthcheck|runtime-owner\\.json|RuntimeOwner|issue-snapshot\\.json|goldenReplayCases|goldenBootstrapCases" src test scripts docs golden
rg -n "writeFile|atomicWrite|encodeFile|decodeFile|eitherDecode|readFile|doesFileExist|renameFile|copyFile|removeFile" src test scripts
```

Run focused tests if tests or assertions are added. Prefer the narrowest
matching `watcher-core-test` invocation that covers the changed assertions,
then run the full watcher regression target before review:

```sh
cabal test watcher-core-test
```

Run the baseline checks required by the active roadmap verification contract
before review:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If files are staged later in the round, also run:

```sh
git diff --cached --check
```
