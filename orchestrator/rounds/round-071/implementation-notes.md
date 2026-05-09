### Changes Made

- `orchestrator/rounds/round-071/external-operator-downstream-inventory.md`:
  added the evidence-only external operator/downstream inventory for
  milestone-005 public import facades and milestone-006 runtime compatibility
  paths.
- `orchestrator/rounds/round-071/implementation-notes.md`: recorded the
  implementation evidence, exact scans/readbacks, skipped baselines, and
  artifact-only scope.

### Tests

No production source, tests, fixtures, scripts, docs outside round-local
artifacts, package descriptors, roadmap files, project contract, or controller
state were changed.

Focused validation and scans run:

```sh
git status --short --branch
sed -n '1,220p' orchestrator/rounds/round-071/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,360p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
rg -n "milestone-005|milestone-006|milestone-007|direction-020|external operator|downstream|unsupported-user|removal" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md
sed -n '1,260p' orchestrator/rounds/round-060/core-ids-split-import-evidence.md
sed -n '1,260p' orchestrator/rounds/round-061/app-server-client-migration-readiness.md
sed -n '1,320p' orchestrator/rounds/round-062/event-log-helper-boundary-evidence.md
sed -n '1,260p' orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md
sed -n '1,240p' orchestrator/rounds/round-064/planning-state-fixture-policy.md
sed -n '1,240p' orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md
sed -n '1,260p' orchestrator/rounds/round-066/runtime-owner-fixture-operator-inventory.md
sed -n '1,260p' orchestrator/rounds/round-067/daemon-state-active-stopped-fixtures.md
sed -n '1,280p' orchestrator/rounds/round-068/pr-state-external-path-inventory.md
sed -n '1,260p' orchestrator/rounds/round-069/block-state-repair-failure-evidence.md
sed -n '1,240p' orchestrator/rounds/round-070/live-issue-snapshot-fixture-timing.md
rg -n '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
rg -n 'CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Audit|Workflow\.Permission\.Core' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src app test orchestrator/rounds/round-060 orchestrator/rounds/round-061 orchestrator/rounds/round-062 orchestrator/rounds/round-063
find . -path './.git' -prune -o \( -name 'planning-state.json' -o -name 'repair-state.json' -o -name 'runtime-owner.json' -o -name 'daemon-state.json' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' -o -name 'block-state.json' -o -name 'issue-snapshot.json' -o -name '*pr-url*' -o -name '*pr-state*' \) -print | sort
rg -n 'planning-state\.json|repair-state\.json|runtime-owner\.json|daemon-state\.json|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|issue-state\.json|block-state\.json|issue-snapshot\.json|pr_url|prUrl|pr-url|pr-state|runtimeOwner|blockedState|checkerStatePath|reviewerStatePath|issueSnapshotPath' src app test scripts docs examples golden orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066 orchestrator/rounds/round-067 orchestrator/rounds/round-068 orchestrator/rounds/round-069 orchestrator/rounds/round-070
rg -n 'restart-watcher|healthcheck|repair|resume|operator|downstream|external|unsupported|approval|publication|upload|release|remove|removal|migration|deprecation|state file|state-file|runtime-owner\.json|daemon-state\.json|issue-snapshot\.json|block-state\.json|PR_REVIEW_ROOT|pr-review-watchers' docs/watcher-agent-runbook docs/agentic-workflow-framework scripts README.md orchestrator/rounds/round-071
find scripts -maxdepth 3 -type f \( -name 'restart-watcher' -o -name 'healthcheck*' -o -path 'scripts/watcher-init/*' \) -print | sort
find docs/watcher-agent-runbook -type f -name '*.md' | sort
sed -n '1,140p' docs/agentic-workflow-framework/publication-gate-decision.md
sed -n '130,235p' scripts/restart-watcher
sed -n '1,180p' scripts/watcher-init/init-pr-review-state.sh
sed -n '50,95p' scripts/watcher-init/docker-setup-smoke.sh
```

Import count readback:

```text
CodexWatcher.Core.Ids: 65 importer files
CodexWatcher.AppServerClient: 28 importer files
CodexWatcher.Workflow.EventLog: 7 anchored importer files; 1 stricter exact unqualified facade importer
CodexWatcher.Workflow.Permission: 2 anchored importer files; 0 stricter exact unqualified facade importers
```

Fixture/path readback found checked-in `issue-state.json`, one old-shape
`daemon-state.json`, PR review state fixtures, one normal PR-review
`block-state.json`, and the prior round artifact
`orchestrator/rounds/round-068/pr-state-external-path-inventory.md`. It found
no checked-in `planning-state.json`, `repair-state.json`,
`runtime-owner.json`, live `issue-snapshot.json`, or dedicated `*pr-url*` /
`*pr-state*` file.

Cabal/package baselines were skipped under the artifact-only allowance because
the diff is limited to
`orchestrator/rounds/round-071/external-operator-downstream-inventory.md` and
`orchestrator/rounds/round-071/implementation-notes.md`. No staged diff exists,
so `git diff --cached --check` is not applicable unless a reviewer stages the
files later.

### Notes

The artifact records `observed`, `unavailable`,
`blocked_on_operator_approval`, and `no_decision_recorded` evidence
conservatively. It does not treat local absence as removal approval.

No explicit unsupported-user decision was found in the worktree for the
inventoried import facades, runtime paths, script consumers, runbook
consumers, or downstream users. Publication-gate evidence remains on hold and
records no explicit user/operator approval for package upload.

No production behavior changed.
