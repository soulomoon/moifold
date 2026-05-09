### Changes Made

- `orchestrator/rounds/round-067/daemon-state-active-stopped-fixtures.md`: added source-backed evidence for the current `daemon-state.json` compatibility surface, including active/stopped/idle projection shapes, checked-in fixture search, snapshot/golden replay readback, healthcheck readback, repair readback, restart cleanup readback, existing coverage, current `keep` classification, and conservative blockers.
- `orchestrator/rounds/round-067/implementation-notes.md`: recorded round-local implementation notes and validation rationale.

### Tests

- No production code, tests, scripts, fixtures, docs, package files, roadmap files, project contract, or controller state were changed.
- Cabal/package baselines were skipped under the active verification contract's artifact-only allowance because the diff is limited to round-local orchestrator evidence artifacts.

### Notes

Focused readbacks/scans run:

```sh
git status --short --branch
sed -n '1,260p' orchestrator/rounds/round-067/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,340p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '45,165p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '225,275p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '220,260p' src/CodexWatcher/Snapshot.hs
sed -n '340,375p' src/CodexWatcher/GoldenReplay.hs
sed -n '244,282p' src/CodexWatcher/Healthcheck.hs
sed -n '38,105p' src/CodexWatcher/Cli/Command/Replay.hs
sed -n '200,270p' scripts/restart-watcher
find . -path './.git' -prune -o -name 'daemon-state.json' -print
rg -n "daemon-state\\.json|activeTurnId|activeTurnPurpose|activeThreadId|activeTurnCollaborationMode|stopReason|lastCompletedTurn|activeDaemonJson|stoppedDaemonJson|idleDaemonJson|compatibilityStateWrites" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066
rg -n "stateFileSpecs|sharedStateFiles|daemonState|readStateFiles|writeCompatibilityFiles|repairInvalidState|repair-invalid-state|cleanup_state|restart-watcher|GoldenReplay|loadNodeIssueImplementSnapshot" src app test scripts docs golden orchestrator/rounds/round-067
rg -n "daemon-state\\.json|keep|active|stopped|old-shape|old shape|lastCompletedTurn|fixture|healthcheck|repair|restart cleanup|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-067
```

Fixture-search result:

```text
./golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json
```

The checked-in fixture still contains the older `lastCompletedTurn` shape. No checked-in current active or stopped `daemon-state.json` fixtures were found.

No production behavior changed.
