### Goal

Record current evidence for the `daemon-state.json` compatibility surface:
active daemon projection evidence, stopped daemon projection evidence,
tolerated old-shape fixture evidence, current compatibility projection
readback, healthcheck readback, repair readback, restart cleanup readback, and
blockers before any later cleanup, migration, schema, timing, healthcheck,
repair, projection, or removal decision.

This is an evidence-only round for
`direction-016-daemon-state-active-stopped-fixtures` under
`milestone-006-runtime-compatibility-follow-up-evidence`. It must preserve the
project-contract compatibility promises for runtime compatibility files. It
must not change filenames, schemas, event JSON `type` fields, daemon summary
compatibility, compatibility projection behavior, healthcheck behavior, repair
behavior, restart cleanup behavior, production source, tests, scripts, roadmap
files, controller state, package metadata, deprecation status, migration
status, removal approval, publication, upload, or release approval.

### Approach

Keep this as a sequential evidence-only round. Use
`orchestrator/project-contract.md` for stable compatibility invariants and
the active verification contract for baseline expectations. Do not write a
`worker-plan.json`: the selected surface is one shared compatibility file, and
the active/stopped projection, old fixture, healthcheck, repair, and restart
cleanup readbacks are tightly coupled enough that worker fan-out would create
coordination overhead without independent ownership.

The implementer should create one round-local evidence artifact, expected as
`orchestrator/rounds/round-067/daemon-state-active-stopped-fixtures.md`, plus
round-local implementation notes if the implementer normally records them.
The evidence artifact should be source-backed and conservative. If active or
stopped checked-in `daemon-state.json` fixtures are still absent, record the
fixture gap and the current source-derived JSON shapes; do not invent golden
fixture coverage unless a later reviewed implementation plan explicitly
authorizes fixture/test changes.

### Steps

1. Re-read the active round/control inputs before editing:
   `orchestrator/rounds/round-067/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the round remains evidence-only under
   `direction-016-daemon-state-active-stopped-fixtures`.

2. Refresh prior evidence from rounds 053, 055, 057, 058, 064, 065, and 066,
   but carry forward only claims still supported by current source scans. Treat
   the round-055 and round-057 `daemon-state.json` rows as baseline evidence:
   the file is currently classified `keep`, an old incomplete fixture exists,
   and active/stopped fixture evidence plus external operator/downstream
   inventory remain blockers.

3. Inspect `src/CodexWatcher/Runtime/Compatibility.hs`. Record all current
   `daemon-state.json` projection producers:
   - idle daemon JSON for planning ready, planning waiting-ready-issues,
     issue ready/planned/handoff/waiting/post-merge/waiting-close states;
   - active daemon JSON for planning, issue implementation, and post-merge
     review active turns;
   - stopped daemon JSON for `StoppedState`.
   Record the current active fields exactly:
   `activeTurnId`, `activeTurnPurpose`, and `activeThreadId`. Record the
   current stopped fields exactly: `activeTurnId`, `activeTurnPurpose`, and
   `stopReason`. Record that idle uses `activeTurnId = null`,
   `activeTurnPurpose = null`, and `activeTurnCollaborationMode = null`.
   Do not propose a daemon summary/schema change.

4. Inspect the current checked-in fixture coverage:
   `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json` and any
   other `daemon-state.json` files found by the fixture search. Record that the
   known old fixture has the tolerated older `lastCompletedTurn` shape if the
   current file still contains that shape. Separate old-shape fixture evidence
   from current active/stopped projection evidence.

5. Inspect snapshot and golden replay readers:
   `src/CodexWatcher/Snapshot.hs` and `src/CodexWatcher/GoldenReplay.hs`.
   Record that issue-implementation snapshots currently decode
   `daemon-state.json` as optional JSON value state, so old-shape tolerance is
   represented as snapshot/golden compatibility rather than a typed current
   daemon summary parser. Do not describe this as approval to remove or
   narrow the file.

6. Inspect healthcheck behavior in `src/CodexWatcher/Healthcheck.hs`, especially
   `stateFileSpecs`, `sharedStateFiles`, and `readStateFiles`. Record that
   issue-planning and issue-implementation healthcheck read shared
   `daemonState` from `daemon-state.json`, while PR review does not use the
   shared issue/planning state-file list. Record this as current read-only
   healthcheck surfacing, not as approval to change healthcheck behavior.

7. Inspect repair behavior in `src/CodexWatcher/Cli/Command/Replay.hs`.
   Record that `repair-invalid-state --execute` writes repaired `events.jsonl`,
   writes `repair-state.json`, then calls `writeCompatibilityFiles`, which
   writes `daemon-state.json` only when `compatibilityStateWrites` for the
   repaired final replay state produces it, and then removes stale
   `block-state.json`. Do not change repair ordering or compatibility rewrite
   ordering.

8. Inspect restart cleanup behavior in `scripts/restart-watcher`. Record that
   `cleanup_state` removes `$state_dir/daemon-state.json` together with pid
   files, `runtime-owner.json`, `block-state.json`, and
   `stale-active-turn.json`, after stop attempts and optional blocked-tail
   cleanup, before either `--no-start` exit or watcher restart. Keep this as
   operator-script evidence only; do not modify the script.

9. Run focused source/test/docs/operator scans for `daemon-state.json`, daemon
   summary fields, active/stopped daemon projection, healthcheck, repair, and
   restart cleanup across `src`, `app`, `test`, `scripts`, `docs`, `examples`,
   `golden`, and relevant prior round artifacts. Separate true production
   readers/writers from tests, docs, scripts, policy evidence, and prior-round
   evidence artifacts.

10. Inspect existing tests in `test/Main.hs` around healthcheck source
    assertions, repair source-order assertions, golden replay/bootstrap
    coverage, compatibility write ordering, and daemon compatibility projection
    parity. Record this as existing behavior/source assertion coverage. Do not
    claim active/stopped checked-in fixture coverage unless actual fixture
    files exist.

11. Create the round-local evidence artifact with sections for scope and
    non-goals, compatibility projection readback, active daemon evidence,
    stopped daemon evidence, tolerated old-shape fixture evidence,
    snapshot/golden replay readback, healthcheck readback, repair readback,
    restart cleanup readback, existing test coverage, current classification,
    and blockers before any later cleanup decision.

12. Keep blockers conservative. At minimum, retain any missing checked-in
    current active `daemon-state.json` fixture, missing checked-in current
    stopped `daemon-state.json` fixture, missing old/current active/stopped
    round-trip fixture coverage, missing external operator/downstream
    direct-reader inventory beyond repo-local evidence, and no selected
    approval for filename, schema, event `type`, daemon summary, projection,
    healthcheck, repair, restart cleanup, migration, deprecation, or removal
    changes.

13. If the implementer records implementation notes, include changed files,
    exact scans run, fixture-search results, any skipped baseline rationale,
    and a statement that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,260p' orchestrator/rounds/round-067/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '45,165p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '250,275p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '220,260p' src/CodexWatcher/Snapshot.hs
sed -n '340,375p' src/CodexWatcher/GoldenReplay.hs
sed -n '244,282p' src/CodexWatcher/Healthcheck.hs
sed -n '38,105p' src/CodexWatcher/Cli/Command/Replay.hs
sed -n '200,270p' scripts/restart-watcher
```

Run the focused scans and record results:

```sh
find . -path './.git' -prune -o -name 'daemon-state.json' -print
rg -n "daemon-state\\.json|activeTurnId|activeTurnPurpose|activeThreadId|activeTurnCollaborationMode|stopReason|lastCompletedTurn|activeDaemonJson|stoppedDaemonJson|idleDaemonJson|compatibilityStateWrites" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066
rg -n "stateFileSpecs|sharedStateFiles|daemonState|readStateFiles|writeCompatibilityFiles|repairInvalidState|repair-invalid-state|cleanup_state|restart-watcher|GoldenReplay|loadNodeIssueImplementSnapshot" src app test scripts docs golden orchestrator/rounds/round-067
rg -n "daemon-state\\.json|keep|active|stopped|old-shape|old shape|lastCompletedTurn|fixture|healthcheck|repair|restart cleanup|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-067
```

Validate the artifact-only diff:

```sh
git status --short --branch
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-067
```

Full baseline expectations from the active verification contract are:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If the implementation diff remains limited to round-local orchestrator
artifacts, Cabal and package baselines may be skipped under the artifact-only
allowance in `verification.md`. If production source, tests, fixtures,
schemas, scripts, docs, package files, roadmap files, controller state, or
project contract change, the implementer must stop and either narrow the diff
back to the selected evidence scope or run the full baseline above and update
the plan/review evidence accordingly.

When staging is involved, also run:

```sh
git diff --cached --check
```
