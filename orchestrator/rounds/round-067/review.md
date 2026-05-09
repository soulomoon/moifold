### Checks Run
- Command: `git status --short --branch`
  Result: pass. Branch is `orchestrator/round-067-daemon-state-active-stopped-fixtures`; only untracked round-local files under `orchestrator/rounds/round-067/` are present.
- Command: `git diff --name-only`
  Result: pass. No tracked-file diff output. This is expected because the round files are currently untracked; `git status --short --branch` is the authoritative changed-path check for this review.
- Command: `find orchestrator/rounds/round-067 -maxdepth 1 -type f -print | sort`
  Result: pass. Files are limited to `daemon-state-active-stopped-fixtures.md`, `implementation-notes.md`, `plan.md`, `selection.md`, and this review output path after review.
- Command: `git diff --check`
  Result: pass. No whitespace errors in tracked diffs.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-067`
  Result: pass. Exit 1 with no matches; no trailing whitespace in round-067 artifacts.
- Command: `sed -n '1,260p' orchestrator/rounds/round-067/selection.md`
  Result: pass. Selection identifies roadmap `2026-05-09-01-compatibility-surface-cleanup`, revision `rev-002`, milestone `milestone-006-runtime-compatibility-follow-up-evidence`, and direction/extracted item `direction-016-daemon-state-active-stopped-fixtures`; scope is evidence-only and forbids filename/schema/event type/daemon summary/projection/healthcheck/repair/restart cleanup/removal/release changes.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract keeps compatibility files including `daemon-state.json` at current names and field meanings unless explicitly migrated, and requires old-log/golden/repair/healthcheck/write-timing evidence before runtime compatibility-file removal.
- Command: `sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass. Verification contract allows skipping Cabal/package baselines only when the diff is limited to roadmap and round-local orchestrator artifacts; the current changed paths satisfy the artifact-only allowance.
- Command: `sed -n '45,165p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Source confirms `daemon-state.json` writes for idle planning/issue states, active planning/implement/post-merge-review states, and `StoppedState`; PR-review states do not write `daemon-state.json`.
- Command: `sed -n '250,275p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Source confirms active fields `activeTurnId`, `activeTurnPurpose`, `activeThreadId`; stopped fields `activeTurnId`, `activeTurnPurpose`, `stopReason`; idle null fields include `activeTurnCollaborationMode`.
- Command: `sed -n '165,185p' src/CodexWatcher/Snapshot.hs` and `sed -n '220,260p' src/CodexWatcher/Snapshot.hs`
  Result: pass. Source confirms optional issue-implementation `daemon-state.json` decoding and optional daemon fields, so the old `lastCompletedTurn` fixture shape is tolerated as ignored unknown JSON.
- Command: `sed -n '340,375p' src/CodexWatcher/GoldenReplay.hs`
  Result: pass. Source confirms golden replay reads `daemon.activeTurnId` and `daemon.activeTurnPurpose` to bootstrap active issue turns.
- Command: `sed -n '244,282p' src/CodexWatcher/Healthcheck.hs`
  Result: pass. Source confirms issue planning and issue implementation use `sharedStateFiles` with `("daemonState", "daemon-state.json")`; PR review has its own state-file list.
- Command: `sed -n '38,105p' src/CodexWatcher/Cli/Command/Replay.hs`
  Result: pass. Source confirms `repair-invalid-state --execute` archives, rewrites events, writes `repair-state.json`, calls `writeCompatibilityFiles`, then removes stale `block-state.json`.
- Command: `sed -n '200,270p' scripts/restart-watcher`
  Result: pass. Source confirms restart cleanup removes `daemon-state.json` with pid files, `runtime-owner.json`, `block-state.json`, and `stale-active-turn.json` after stop attempts and blocked-tail cleanup.
- Command: `find . -path './.git' -prune -o -name 'daemon-state.json' -print`
  Result: pass. Only `./golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json` was found.
- Command: `rg -n "daemon-state\\.json|activeTurnId|activeTurnPurpose|activeThreadId|activeTurnCollaborationMode|stopReason|lastCompletedTurn|activeDaemonJson|stoppedDaemonJson|idleDaemonJson|compatibilityStateWrites" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066`
  Result: pass. Scan supports the current projection fields, only one checked-in old-shape fixture, production compatibility write sites, prior-round gaps, and no checked-in current active/stopped daemon fixture.
- Command: `rg -n "stateFileSpecs|sharedStateFiles|daemonState|readStateFiles|writeCompatibilityFiles|repairInvalidState|repair-invalid-state|cleanup_state|restart-watcher|GoldenReplay|loadNodeIssueImplementSnapshot" src app test scripts docs golden orchestrator/rounds/round-067`
  Result: pass. Scan supports healthcheck surfacing, snapshot/golden replay readback, repair ordering, restart cleanup, and related test assertions.
- Command: `rg -n "daemon-state\\.json|keep|active|stopped|old-shape|old shape|lastCompletedTurn|fixture|healthcheck|repair|restart cleanup|external operator|downstream|removal|migration" docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-067`
  Result: pass. Policy and round artifact classify `daemon-state.json` as `keep`, retain active/stopped fixture and external inventory blockers, and do not approve migration/removal/behavior changes.
- Command: `sed -n '1984,2002p' test/Main.hs` and `sed -n '7368,7382p' test/Main.hs`
  Result: pass. Existing assertions cover repair source ordering and read-only healthcheck surfacing of `daemonState`.
- Command: `cabal build all`
  Result: skipped. The diff is limited to round-local orchestrator artifacts under `orchestrator/rounds/round-067`, so the active verification contract's artifact-only allowance applies.
- Command: `cabal test watcher-core-test`
  Result: skipped. Same artifact-only allowance; no production source, tests, fixtures, scripts, docs, package descriptors, roadmap files, controller state, or project contract changed.
- Command: `scripts/validate-workflow-packages.sh`
  Result: skipped. Same artifact-only allowance.

### Plan Compliance
- Step 1, re-read active round/control inputs: met. Selection, project contract, and active verification contract were read back; the round remains evidence-only for `direction-016-daemon-state-active-stopped-fixtures`.
- Step 2, refresh prior evidence but keep only current-source-backed claims: met. The artifact carries forward rounds 053/055/057/058/064/065/066 only where current scans support the old fixture, healthcheck, repair, restart cleanup, `keep` classification, and fixture/inventory blockers.
- Step 3, inspect `Runtime/Compatibility.hs` projection producers and exact fields: met. Artifact records idle, active, stopped producers and exact active/stopped/idle field sets.
- Step 4, inspect checked-in fixture coverage: met. The only found fixture is `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`, with old `lastCompletedTurn` shape; current active/stopped fixture coverage is explicitly absent.
- Step 5, inspect snapshot and golden replay readers: met. Artifact records optional issue-implementation daemon-state decode and active-field golden replay bootstrap without treating this as removal approval.
- Step 6, inspect healthcheck behavior: met. Artifact records shared `daemonState` for issue planning/implementation and separate PR-review state files.
- Step 7, inspect repair behavior: met. Artifact records the execute-mode ordering and conditional compatibility rewrite behavior without proposing ordering changes.
- Step 8, inspect restart cleanup behavior: met. Artifact records `cleanup_state` removal of `daemon-state.json` as operator-script evidence only.
- Step 9, run focused scans: met. Required source/test/docs/operator/prior-round scans were run and summarized.
- Step 10, inspect existing tests: met. Artifact records existing repair-order, healthcheck source, golden replay/bootstrap, compatibility parity, and launch/write-order coverage while rejecting any claim of active/stopped checked-in fixture coverage.
- Step 11, create round-local evidence artifact with required sections: met. `daemon-state-active-stopped-fixtures.md` includes scope/non-goals, projection readback, active/stopped/idle evidence, old-shape fixture evidence, snapshot/golden replay, healthcheck, repair, restart cleanup, existing coverage, classification, and blockers.
- Step 12, keep blockers conservative: met. Artifact retains missing active/stopped fixtures, missing round-trip fixture coverage, missing external operator/downstream inventory, and no approval for filename/schema/event type/daemon summary/projection/healthcheck/repair/restart cleanup/migration/deprecation/removal/publication/upload/release changes.
- Step 13, record implementation notes: met. `implementation-notes.md` lists changed files, exact scans, fixture-search result, skipped baseline rationale, and that no production behavior changed.

### Decision
**APPROVED**

### Evidence
The integrated result is limited to round-local orchestrator evidence artifacts under `orchestrator/rounds/round-067`. The absence of tracked `git diff --name-only` output is not used as proof of no changes; `git status --short --branch` and `find orchestrator/rounds/round-067 -maxdepth 1 -type f` show the actual untracked round artifacts.

The evidence artifact is source-backed for current `daemon-state.json` active, stopped, and idle projections; checked-in old-shape fixture tolerance; snapshot/golden replay readback; healthcheck surfacing; repair rewrite ordering; restart cleanup; focused scans; existing source/test assertions; current `keep` classification; and conservative blockers. It does not authorize behavior changes, cleanup, migration, deprecation, removal, publication, upload, or release.

No Cabal/package baselines were required for this review because the verified diff scope is artifact-only and the active verification contract explicitly allows skipping those commands in that case.
