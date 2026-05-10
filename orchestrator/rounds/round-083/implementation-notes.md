### Changes Made

- `orchestrator/rounds/round-083/cleanup-inventory.md`: added the artifact-only
  cleanup inventory required by the round plan, covering roadmap lineage,
  compatibility facades, runtime compatibility files, test topology/helper
  clusters, large behavior modules, fixture coverage, policy references,
  downstream/operator scope, follow-up gates, and artifact-only validation.
- `orchestrator/rounds/round-083/implementation-notes.md`: recorded the exact
  control-plane inputs, read-only inventory commands, verification commands,
  results, changed-path evidence, and artifact-only baseline rationale.

### Tests

- No production or test code was changed.
- Package build/test baselines were not run because this round is artifact-only
  and changed-path evidence is confined to round-local orchestrator artifacts
  plus pre-existing controller/selection/plan artifacts.

### Notes

#### Control-Plane Inputs Re-Read

- `orchestrator/roles/implementer.md`
- `orchestrator/state.json`
- `orchestrator/project-contract.md`
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
- `orchestrator/rounds/round-083/selection.md`
- `orchestrator/rounds/round-083/plan.md`

#### Commands Run

```sh
pwd
```

Result: pass. Confirmed worktree:
`/Users/ares/src/codex-feishu-bot/.codex-local/workspace/artifacts/codex-watcher-hs/orchestrator/worktrees/round-083`.

```sh
git status --short
```

Initial result before this implementer wrote owned files:

```text
 M orchestrator/state.json
?? orchestrator/rounds/round-083/
```

The modified state file and untracked round directory were pre-existing
controller/round artifacts before implementation work. This implementer only
wrote `cleanup-inventory.md` and `implementation-notes.md` under the active
round directory.

```sh
sed -n '1,220p' orchestrator/roles/implementer.md
sed -n '1,240p' orchestrator/state.json
sed -n '1,240p' orchestrator/project-contract.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md
sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md
sed -n '1,240p' orchestrator/rounds/round-083/selection.md
sed -n '1,260p' orchestrator/rounds/round-083/plan.md
```

Result: pass. Inputs confirmed this is a serial artifact-only inventory round
for `round-083-cleanup-inventory-refresh`, with write ownership limited to the
round-local inventory and notes artifacts.

```sh
rg -n "import CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)" src app test agent-workflow-* *.cabal docs orchestrator
```

Result: pass. Produced the broad selected-facade import scan used to group
facade users by source tree, test tree, app tree, package candidates, docs, and
orchestrator evidence.

```sh
rg -n "import CodexWatcher\\.AppServerClient" src app test agent-workflow-* docs orchestrator/rounds
rg -n "import CodexWatcher\\.Core\\.Ids" src app test agent-workflow-* docs orchestrator/rounds
rg -n "import CodexWatcher\\.Workflow\\.EventLog( |$| qualified)" src app test agent-workflow-* docs orchestrator/rounds
rg -n "import CodexWatcher\\.Workflow\\.Permission( |$| qualified)" src app test agent-workflow-* docs orchestrator/rounds
```

Result: pass. Narrowed facade import evidence:

- `AppServerClient`: 12 `src` imports, 1 `test` import, no `app` or
  `agent-workflow-*` imports; prior round evidence in `round-077/plan.md`.
- `Core.Ids`: 29 `src` imports, 1 `app` import, 3 `test` imports, no
  `agent-workflow-*` imports.
- `Workflow.EventLog`: 2 `src` imports, 1 `test` import, plus prior round
  evidence in `round-062/event-log-helper-boundary-evidence.md`.
- `Workflow.Permission`: 1 `test` import, plus prior round evidence in
  `round-063/workflow-permission-public-api-evidence.md`.

```sh
rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)|CodexWatcher/.*(AppServerClient|Ids|EventLog|Permission)" *.cabal agent-workflow-*/*.cabal
```

Result: pass. Confirmed `moifold.cabal` exposes the four selected public
compatibility facades; `agent-workflow-core.cabal` exposes the corresponding
generic event-log and permission core modules.

```sh
sed -n '1,220p' src/CodexWatcher/AppServerClient.hs
sed -n '1,220p' src/CodexWatcher/Core/Ids.hs
sed -n '1,180p' src/CodexWatcher/Workflow/EventLog.hs
sed -n '1,140p' src/CodexWatcher/Workflow/Permission.hs
```

Result: pass. Confirmed `AppServerClient` and `Core.Ids` are pure reexport
facades, while `Workflow.EventLog` and `Workflow.Permission` are mixed
moifold bridge modules over generic core modules.

```sh
rg -n "(planner-state\\.json|planning-state\\.json|daemon-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json)" src app test scripts docs golden examples orchestrator/rounds
```

Result: pass. Produced broad runtime compatibility-file evidence across
production, tests, scripts, docs, golden fixtures, and prior rounds.

```sh
rg --files src agent-workflow-* app test docs scripts golden examples | rg '(AppServerClient|Core/Ids|Workflow/EventLog|Workflow/Permission|Runtime/Compatibility|Healthcheck|Snapshot|EventLogRepair|Runtime/Owner|issue-snapshot|daemon-state|block-state|runtime-owner|planning-state|planner-state|repair-state)'
```

Result: pass. Confirmed the concrete source and fixture files that anchor the
inventory, including `Runtime/Compatibility.hs`, `Healthcheck.hs`,
`Snapshot.hs`, `EventLogRepair.hs`, runtime owner modules, selected facade
files, and checked-in daemon/block state fixtures.

```sh
sed -n '1,190p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '210,260p' src/CodexWatcher/Domain/IssuePlanning/Loop.hs
sed -n '1,120p' src/CodexWatcher/Runtime/Owner/Store.hs
sed -n '1,130p' src/CodexWatcher/EventLogRepair.hs
sed -n '230,285p' src/CodexWatcher/Healthcheck.hs
```

Result: pass. Confirmed runtime compatibility producers, live issue-snapshot
write path, runtime owner lease schema, event-log repair owner module, and
healthcheck state-file readers.

```sh
rg -n "repair-state\\.json|repairCliStateDir|repair-state|writeJsonValue|removeFileIfExists" src/CodexWatcher/Cli src/CodexWatcher/EventLogRepair.hs src/CodexWatcher/RunnerGuard.hs
```

Result: pass. Confirmed `src/CodexWatcher/Cli/Command/Replay.hs` writes
`repair-state.json`, rewrites compatibility files, and removes stale
`block-state.json` in execute repair order.

```sh
find golden examples test docs scripts src app -path './.git' -prune -o \( -name 'planner-state.json' -o -name 'planning-state.json' -o -name 'daemon-state.json' -o -name 'block-state.json' -o -name 'repair-state.json' -o -name 'runtime-owner.json' -o -name 'issue-snapshot.json' \) -print | sort
```

Result: pass. Found checked-in runtime compatibility fixtures only at:

```text
golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json
golden/pr-review/mlf2-pr6-blocked/block-state.json
```

```sh
wc -l test/Main.hs test/*.hs src/CodexWatcher/Daemon.hs src/CodexWatcher/Workflow/DocsMigration.hs src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs src/CodexWatcher/EventLog/Types.hs src/CodexWatcher/TurnOutput.hs
```

Result: pass. Key line counts recorded:

```text
16956 test/Main.hs
  334 test/AppServerSpec.hs
  212 test/CliSpec.hs
  251 test/GhGitSpec.hs
  200 test/HealthcheckSpec.hs
   16 test/JsonPathSpec.hs
  411 test/RuntimeSpec.hs
  960 src/CodexWatcher/Daemon.hs
  954 src/CodexWatcher/Workflow/DocsMigration.hs
  940 src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs
  672 src/CodexWatcher/EventLog/Types.hs
  618 src/CodexWatcher/TurnOutput.hs
```

```sh
rg -n "(facade|compatib|package-boundary|package boundary|import-policy|import policy|boundary-policy|EventLog|Permission|AppServerClient|Core\\.Ids|planner-state|planning-state|daemon-state|block-state|repair-state|runtime-owner|issue-snapshot)" test/Main.hs test/*.hs
sed -n '7280,8105p' test/Main.hs
sed -n '10240,10920p' test/Main.hs
sed -n '14480,15820p' test/Main.hs
```

Result: pass. Identified the large `test/Main.hs` helper clusters and behavior
clusters recorded in `cleanup-inventory.md`.

```sh
rg -n "compatibilityStateWrites|writeCompatibility|RecordPlanningGraph|RecordBlocked|runtime-owner\\.json|issue-snapshot\\.json" src/CodexWatcher test/Main.hs test/*.hs
```

Result: pass. Confirmed compatibility write producers, direct graph/block
effects, runtime-owner path users, issue-snapshot path users, and tests that
anchor write-timing and compatibility behavior.

```sh
rg -n "(terminal hold|removed-surface|remove|deprecat|compatibility.*policy|planner-state|planning-state|runtime-owner|daemon-state|block-state|repair-state|issue-snapshot)" orchestrator/project-contract.md orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md docs/agentic-workflow-framework/compatibility-deprecation-policy.md orchestrator/rounds/round-071/external-operator-downstream-inventory.md orchestrator/rounds/round-074/*
```

Result: pass. Confirmed policy references, prior terminal-hold context,
non-approval language, runtime compatibility surface blockers, and prior
external/operator inventory gaps.

```sh
rg -n "src/CodexWatcher/(Daemon|Workflow/DocsMigration|Workflow/Moifold/IssueImplement/Indexed|EventLog/Types|TurnOutput)\\.hs|Workflow\\.DocsMigration|Workflow\\.Moifold\\.IssueImplement\\.Indexed|EventLog\\.Types|TurnOutput|runObservedDaemonTick|DocsMigration|eventLog|turn output" moifold.cabal test/Main.hs test/*.hs
```

Result: pass. Confirmed Cabal exposure and test anchors for the large behavior
modules named by the active roadmap.

#### Artifact-Only Verification

```sh
git status --short
git diff --name-only
git diff --check
rg -n "deprecat|remov|migrat|delete|rename|approval|Cabal exposure" orchestrator/rounds/round-083/cleanup-inventory.md orchestrator/rounds/round-083/implementation-notes.md
find orchestrator/rounds/round-083 -maxdepth 1 -type f -print | sort
git status --short orchestrator/state.json orchestrator/rounds/round-083
rg -n "[[:blank:]]$" orchestrator/rounds/round-083/cleanup-inventory.md orchestrator/rounds/round-083/implementation-notes.md
```

Final results are recorded after the files were written:

- `git status --short`: pass; changed paths are limited to pre-existing
  `orchestrator/state.json`, pre-existing untracked
  `orchestrator/rounds/round-083/` artifacts, and this implementer's two owned
  files in that round directory.
- `git diff --name-only`: pass; lists `orchestrator/state.json` only because
  the active round directory remains untracked.
- `git diff --check`: pass; no whitespace errors.
- policy-word `rg`: pass; matches are intentional non-goal, missing-gate,
  prior-hold, and non-approval statements. The inventory does not classify any
  surface as approved for deprecation, migration, removal, deletion, rename,
  or Cabal exposure change.
- round directory file listing: pass; files present are `selection.md`,
  `plan.md`, `cleanup-inventory.md`, and `implementation-notes.md`.
- scoped status check: pass; status is the pre-existing modified
  `orchestrator/state.json` plus untracked `orchestrator/rounds/round-083/`.
- trailing-whitespace scan for the two owned files: pass; no matches.

No staging occurred, so `git diff --cached --check` was not applicable.

#### Artifact-Only Baseline Rationale

The active verification bundle allows artifact-only inventory rounds to skip
`cabal build all` and `cabal test watcher-core-test` when changed-path evidence
shows no production code, test code, package descriptor, runtime compatibility
file, public API, fixture, docs, or behavior surface changed.

This round wrote only:

- `orchestrator/rounds/round-083/cleanup-inventory.md`
- `orchestrator/rounds/round-083/implementation-notes.md`

The pre-existing controller and round setup artifacts remain outside this
implementer's write ownership:

- `orchestrator/state.json`
- `orchestrator/rounds/round-083/selection.md`
- `orchestrator/rounds/round-083/plan.md`

Because the implementation is documentation-only within the active round
artifact directory, package build/test baselines were skipped.
