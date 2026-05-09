### Goal

Produce an evidence-only external operator and downstream inventory across the
compatibility surfaces covered by milestones 005 and 006. The round should
create a reviewable artifact at
`orchestrator/rounds/round-071/external-operator-downstream-inventory.md`
that records public import consumers, state-file path consumers,
shell/operator consumers, runbook and docs references, downstream-user
evidence, unavailable evidence, blocked evidence, and unsupported-user
decisions before any later cleanup selection.

This round must not change behavior. It must not approve deprecation,
migration, removal, package publication, upload, release, Cabal exposure
changes, production import rewrites, runtime compatibility filename/schema
changes, event type changes, healthcheck behavior changes, repair behavior
changes, write-timing changes, or operator behavior changes.

### Approach

Keep the work sequential and round-local. Use
`orchestrator/project-contract.md` for stable compatibility invariants and the
active rev-002 verification bundle for evidence expectations. Do not write
`worker-plan.json`: the implementation needs one integrated inventory across
milestone-005 public import facades, milestone-006 runtime compatibility
files, scripts, docs, runbooks, fixtures, and unsupported-user decisions. Split
workers would duplicate broad searches and create overlapping ownership over
the same downstream/operator evidence.

The implementer should create one round-local evidence artifact, expected as
`orchestrator/rounds/round-071/external-operator-downstream-inventory.md`,
plus round-local implementation notes if they normally record them. The
artifact should be source-backed and conservative. Local repo absence is not
removal evidence: record evidence as `observed`, `unavailable`,
`blocked_on_operator_approval`, or `unsupported_user_decision` rather than
promoting absence to cleanup approval.

Treat these milestone-005 public import surfaces as required inventory rows:

- `CodexWatcher.Core.Ids`
- `CodexWatcher.AppServerClient`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Permission`

Treat these milestone-006 runtime compatibility surfaces as required inventory
rows:

- `planning-state.json`
- `repair-state.json`
- `runtime-owner.json`
- `daemon-state.json`
- PR review compatibility state files and PR URL/state paths:
  `watcher-state.json`, `checker-state.json`, `agent-state.json`,
  `reviewer-state.json`, `issue-state.json` `pr_url`, `prUrl`, `pr-url`, and
  `pr-state`
- repair-failure and normal `block-state.json`
- live issue-planning `issue-snapshot.json`

### Steps

1. Re-read the round/control inputs before editing:
   `orchestrator/rounds/round-071/selection.md`,
   `orchestrator/project-contract.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`,
   and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`.
   Confirm the selected direction remains
   `direction-020-external-operator-downstream-inventory` and that milestone
   007 is evidence-only after milestones 005 and 006.

2. Refresh milestone-005 evidence from current artifacts:
   `orchestrator/rounds/round-060/core-ids-split-import-evidence.md`,
   `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`,
   `orchestrator/rounds/round-062/event-log-helper-boundary-evidence.md`,
   `orchestrator/rounds/round-063/workflow-permission-public-api-evidence.md`,
   and
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Carry forward only claims still supported by current scans. Record each
   facade's current classification, known repo-local consumers, replacement
   imports, external/downstream gaps, and blockers.

3. Refresh milestone-006 evidence from current artifacts:
   `orchestrator/rounds/round-064/planning-state-fixture-policy.md`,
   `orchestrator/rounds/round-065/repair-state-fixture-reader-policy.md`,
   `orchestrator/rounds/round-066/runtime-owner-fixture-operator-inventory.md`,
   `orchestrator/rounds/round-067/daemon-state-active-stopped-fixtures.md`,
   `orchestrator/rounds/round-068/pr-state-external-path-inventory.md`,
   `orchestrator/rounds/round-069/block-state-repair-failure-evidence.md`,
   `orchestrator/rounds/round-070/live-issue-snapshot-fixture-timing.md`,
   and
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Record each file or path's current classification, producer, reader,
   healthcheck or non-healthcheck status, repair/restart/script behavior,
   fixture status, external/downstream gaps, and blockers.

4. Build a public import inventory table. For each required import facade,
   include columns for surface, current package exposure, preferred
   replacement import when known, repo-local production imports, repo-local
   test imports, docs/package references, available downstream references,
   unavailable downstream evidence, blocked evidence, unsupported-user
   decision if any, and cleanup blocker. Refresh direct import scans rather
   than relying only on prior artifact counts.

5. Build a runtime path inventory table. For each required state-file or path
   surface, include columns for surface, producer/writer, reader, healthcheck
   or non-healthcheck policy, repair/restart behavior, shell/operator
   consumer, runbook/docs reference, checked-in fixture or fixture gap,
   available downstream reference, unavailable evidence,
   blocked_on_operator_approval evidence, unsupported-user decision if any,
   and cleanup blocker.

6. Inspect shell and operator entry points as first-class evidence, not just
   incidental references. Include at least:
   `scripts/restart-watcher`,
   `scripts/watcher-init/init-pr-review-state.sh`,
   `scripts/watcher-init/docker-setup-smoke.sh`,
   `scripts/healthcheck*` if present,
   `docs/watcher-agent-runbook/**`,
   `docs/watcher-agent-runbook/checklists/operator-checklist.md`,
   `docs/watcher-agent-runbook/project-watch/*.md`,
   `docs/watcher-agent-runbook/moifold-setup/*.md`,
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`,
   and
   `docs/agentic-workflow-framework/publication-gate-decision.md`.
   Separate operator instructions from source readers/writers.

7. Inspect source read/write surfaces enough to classify runtime paths without
   changing them. Include at least:
   `src/CodexWatcher/Runtime/Compatibility.hs`,
   `src/CodexWatcher/Healthcheck.hs`,
   `src/CodexWatcher/Snapshot.hs`,
   `src/CodexWatcher/EventLogRepair.hs`,
   `src/CodexWatcher/Runtime/Owner`,
   `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`,
   `src/CodexWatcher/Domain/PrReview`,
   `src/CodexWatcher/PromptTemplates.hs`,
   `src/CodexWatcher/TurnOutput.hs`,
   and current tests or golden fixtures referenced by the prior milestone-006
   artifacts. Record only evidence and blockers; do not propose source edits.

8. Search for downstream and external evidence available inside this worktree:
   `README.md`, `docs`, `examples`, `*.cabal`, `*/**/*.cabal`,
   `agent-workflow-core`, `agent-workflow-codex`, `agent-workflow-github`,
   `scripts`, `test`, `golden`, and prior round artifacts. If no external
   downstream repository, operator approval record, live state archive, or
   unsupported-user decision is available in the worktree, record that
   explicitly as unavailable or blocked evidence. Do not use local absence as
   approval to remove a surface.

9. Record unsupported-user decisions separately from missing evidence. A row
   may say `none recorded in this worktree` or cite an explicit decision if
   one exists. If an unsupported-user decision would require operator approval
   or a future release/publication gate, classify it as blocked and name the
   missing approval artifact rather than making the decision in this round.

10. Create
    `orchestrator/rounds/round-071/external-operator-downstream-inventory.md`
    with sections for scope and non-goals, evidence status vocabulary,
    milestone-005 public import inventory, milestone-006 runtime path
    inventory, shell/operator consumer inventory, runbook/docs inventory,
    downstream/unavailable/blocked evidence, unsupported-user decisions,
    per-surface blockers, and final conservative conclusion.

11. Keep the final conclusion conservative: milestone 007 may complete the
    inventory only by recording observed evidence, unavailable evidence,
    blocked evidence, and unsupported-user decision gaps. It must not state
    that any public import facade or runtime compatibility path is approved
    for deprecation, migration, removal, publication, upload, release, or
    behavior change.

12. If implementation notes are written, include changed files, exact scans
    run, readback files inspected, evidence status summary, any skipped
    baseline rationale, and a statement that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
git status --short --branch
sed -n '1,220p' orchestrator/rounds/round-071/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,360p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
rg -n "milestone-005|milestone-006|milestone-007|direction-020|external operator|downstream|unsupported-user|removal" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md
```

Read prior evidence artifacts:

```sh
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
```

Run refreshed import and docs scans and record summarized results:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
rg -n 'CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.EventLog\.(Core|File\.Core|Commit\.Core)|Workflow\.Audit|Workflow\.Permission\.Core' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src app test orchestrator/rounds/round-060 orchestrator/rounds/round-061 orchestrator/rounds/round-062 orchestrator/rounds/round-063
```

Run refreshed runtime path and operator scans and record summarized results:

```sh
find . -path './.git' -prune -o \( -name 'planning-state.json' -o -name 'repair-state.json' -o -name 'runtime-owner.json' -o -name 'daemon-state.json' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' -o -name 'block-state.json' -o -name 'issue-snapshot.json' -o -name '*pr-url*' -o -name '*pr-state*' \) -print
rg -n 'planning-state\.json|repair-state\.json|runtime-owner\.json|daemon-state\.json|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|issue-state\.json|block-state\.json|issue-snapshot\.json|pr_url|prUrl|pr-url|pr-state|runtimeOwner|blockedState|checkerStatePath|reviewerStatePath|issueSnapshotPath' src app test scripts docs examples golden orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066 orchestrator/rounds/round-067 orchestrator/rounds/round-068 orchestrator/rounds/round-069 orchestrator/rounds/round-070
rg -n 'restart-watcher|healthcheck|repair|resume|operator|downstream|external|unsupported|approval|publication|upload|release|remove|removal|migration|deprecation|state file|state-file|runtime-owner\.json|daemon-state\.json|issue-snapshot\.json|block-state\.json|PR_REVIEW_ROOT|pr-review-watchers' docs/watcher-agent-runbook docs/agentic-workflow-framework scripts README.md orchestrator/rounds/round-071
```

Validate the artifact-only diff:

```sh
git status --short --branch
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-071
sed -n '1,260p' orchestrator/rounds/round-071/selection.md
sed -n '1,320p' orchestrator/rounds/round-071/plan.md
```

Baseline expectations from the active verification contract are
`cabal build all`, `cabal test watcher-core-test`,
`scripts/validate-workflow-packages.sh`, `git diff --check`, and
`git diff --cached --check` when staging is involved. For this round, the
implementer may skip the Cabal and package baselines only if the diff remains
limited to allowed round-local orchestrator artifacts such as
`orchestrator/rounds/round-071/external-operator-downstream-inventory.md` and
round-local implementation notes. If the diff touches production source,
tests, fixtures, scripts, docs outside the round artifact, package files,
roadmap files, `orchestrator/project-contract.md`, or `orchestrator/state.json`,
the implementer must stop and either narrow the diff back to artifact-only
scope or run the full baseline before review.

If files are staged later, also run:

```sh
git diff --cached --check
```

### Worker Fan-Out

Worker fan-out is not used. No `worker-plan.json` should be written for this
round because the selected evidence needs a single integrated inventory across
public imports, state-file paths, shell/operator consumers, runbooks,
downstream evidence, unavailable evidence, blocked evidence, and
unsupported-user decisions.
