### Checks Run

- Command: `git status --short --branch --untracked-files=all`
  Result: pass. Branch is `orchestrator/round-071-external-operator-downstream-inventory`; the only changed paths are untracked round-local artifacts under `orchestrator/rounds/round-071/`: `selection.md`, `plan.md`, `external-operator-downstream-inventory.md`, `implementation-notes.md`, `review.md`, and `review-record.json`.
- Command: `git diff --name-only`
  Result: pass. No tracked diff output; changed-path inspection used `git status --short --branch --untracked-files=all` and `git ls-files --others --exclude-standard orchestrator/rounds/round-071 | sort` for the untracked round artifacts.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output; no staged diff exists.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-071`
  Result: pass with no output.
- Command: `test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md && test -f orchestrator/rounds/round-059/plan.md && test ! -e orchestrator/rounds/round-059/worker-plan.json && test ! -e orchestrator/rounds/round-071/worker-plan.json`
  Result: pass. Rev-002 artifacts are readable, round 059 plan exists, and no worker fan-out plan exists for round 059 or round 071.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Project contract preserves event schemas, golden logs, public compatibility facades, runtime compatibility files, healthcheck, repair, and cleanup sequencing.
- Command: `sed -n '1,360p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass. Baselines and artifact-only allowance read back. Cabal/package baselines may be skipped only when the diff is limited to roadmap and round-local orchestrator artifacts.
- Command: `sed -n '1,620p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Roadmap id `2026-05-09-01-compatibility-surface-cleanup`, revision `rev-002`, style `strategy-backlog`, activation metadata, complete milestones 001-006, pending milestone 007, and gated removals only in milestone 008 all read back.
- Command: `sed -n '1,220p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
  Result: pass. Retry contract allows inventory expansion or overclaim narrowing, and confirms removal is not a retry fallback.
- Command: `sed -n '1,260p' orchestrator/rounds/round-071/selection.md`
  Result: pass. Selection lineage is `milestone-007-external-operator-downstream-inventory` / `direction-020-external-operator-downstream-inventory` / `direction-020-external-operator-downstream-inventory`; scope is evidence-only and excludes deprecation, migration, removal, publication, upload, release, production import rewrites, Cabal exposure changes, schema/filename/event/healthcheck/repair/write-timing behavior changes, and gated-removal work.
- Command: `sed -n '1,320p' orchestrator/rounds/round-071/plan.md`
  Result: pass. Plan requires an integrated evidence-only inventory over milestone-005 import facades and milestone-006 runtime paths, plus shell/operator consumers, runbooks/docs, downstream/unavailable/blocked evidence, unsupported-user decisions, and conservative blockers.
- Command: `sed -n '1,360p' orchestrator/rounds/round-071/implementation-notes.md`
  Result: pass. Notes record changed files, focused scans/readbacks, no production behavior changes, and skipped Cabal/package baselines under artifact-only scope.
- Command: `sed -n '1,520p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md`
  Result: pass. Artifact includes scope/non-goals, status vocabulary, milestone-005 import inventory, milestone-006 runtime path inventory, shell/operator consumer inventory, runbook/docs inventory, downstream/unavailable/blocked evidence, unsupported-user decisions, per-surface blockers, and a conservative conclusion.
- Command: `rg -l '^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort | wc -l`
  Result: pass. Refreshed scan returned 65 importer files, matching the inventory.
- Command: `rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort | wc -l`
  Result: pass. Refreshed scan returned 28 importer files, matching the inventory.
- Command: `rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.EventLog(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort`
  Result: pass. Anchored scan returned seven files including replacement submodules; strict exact facade scan returned `src/CodexWatcher/Workflow/DocsMigration.hs`.
- Command: `rg -l '^ *import +(qualified +)?CodexWatcher\.Workflow\.Permission(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort`
  Result: pass. Anchored scan returned `src/CodexWatcher/Workflow/Permission.hs` and `test/Main.hs`; strict exact facade scan returned no output, supporting the artifact's conservative public-surface blocker.
- Command: `find . -path './.git' -prune -o \( -name 'planning-state.json' -o -name 'repair-state.json' -o -name 'runtime-owner.json' -o -name 'daemon-state.json' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' -o -name 'block-state.json' -o -name 'issue-snapshot.json' -o -name '*pr-url*' -o -name '*pr-state*' \) -print | sort`
  Result: pass. Found checked-in issue-state fixtures, one old-shape daemon-state fixture, PR review state fixtures, one normal PR-review block-state fixture, and round-068 `pr-state` artifact. No checked-in `planning-state.json`, `repair-state.json`, `runtime-owner.json`, live `issue-snapshot.json`, or dedicated runtime `*pr-url*` / `*pr-state*` file was found.
- Command: `rg -n 'planning-state\.json|repair-state\.json|runtime-owner\.json|daemon-state\.json|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|issue-state\.json|block-state\.json|issue-snapshot\.json|pr_url|prUrl|pr-url|pr-state|runtimeOwner|blockedState|checkerStatePath|reviewerStatePath|issueSnapshotPath' src app test scripts docs examples golden orchestrator/rounds/round-064 orchestrator/rounds/round-065 orchestrator/rounds/round-066 orchestrator/rounds/round-067 orchestrator/rounds/round-068 orchestrator/rounds/round-069 orchestrator/rounds/round-070`
  Result: pass. Source, tests, docs, fixtures, and prior artifacts support the inventory's producers, readers, healthcheck/non-healthcheck status, repair/restart behavior, fixture gaps, and conservative blockers.
- Command: `rg -n 'restart-watcher|healthcheck|repair|resume|operator|downstream|external|unsupported|approval|publication|upload|release|remove|removal|migration|deprecation|state file|state-file|runtime-owner\.json|daemon-state\.json|issue-snapshot\.json|block-state\.json|PR_REVIEW_ROOT|pr-review-watchers' docs/watcher-agent-runbook docs/agentic-workflow-framework scripts README.md orchestrator/rounds/round-071`
  Result: pass. Runbooks, policy docs, README, scripts, and the round artifact support operator expectations, publication hold, no explicit upload approval, and removal/deprecation gates.
- Command: `sed -n '130,235p' scripts/restart-watcher`
  Result: pass. Script reads `runtime-owner.json` for a pid, can drop a blocked tail, and removes `runtime-owner.json`, `block-state.json`, `daemon-state.json`, and `stale-active-turn.json` during cleanup.
- Command: `sed -n '1,180p' scripts/watcher-init/init-pr-review-state.sh`
  Result: pass. Script uses `PR_REVIEW_ROOT`, creates conventional PR review state directories, writes `events.jsonl` and `config.json`, and generates dry-run/restart commands.

The active verification baseline also names `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`. These were intentionally skipped under the rev-002 artifact-only allowance because changed paths are limited to round-local orchestrator artifacts and there are no production source, test, fixture, script, documentation-policy, Cabal descriptor, roadmap, project-contract, or state changes.

### Plan Compliance

- Step 1, re-read round/control inputs: met. Selection, project contract, rev-002 roadmap, verification contract, and retry-subloop were read; selected direction remains `direction-020-external-operator-downstream-inventory` and milestone 007 remains evidence-only.
- Step 2, refresh milestone-005 evidence: met. The inventory covers `CodexWatcher.Core.Ids`, `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`, including exposure, current importers, replacement paths, downstream gaps, and blockers.
- Step 3, refresh milestone-006 evidence: met. The inventory covers `planning-state.json`, `repair-state.json`, `runtime-owner.json`, `daemon-state.json`, PR review compatibility state files and PR URL/state paths, `block-state.json`, and `issue-snapshot.json`, including producers/readers, healthcheck or non-healthcheck status, repair/restart behavior, fixtures/gaps, external gaps, and blockers.
- Step 4, public import inventory table: met. All four required facades have rows with current exposure, replacement imports, production/test imports, docs/package references, available/unavailable downstream evidence, blocked evidence, unsupported-user status, and cleanup blockers.
- Step 5, runtime path inventory table: met. All required runtime surfaces have rows with producer, reader, healthcheck or non-healthcheck policy, repair/restart behavior, shell/operator consumer, runbook/docs reference, fixture status, downstream evidence, unavailable/blocked evidence, unsupported-user status, and cleanup blocker.
- Step 6, shell/operator entry points: met. The artifact inventories `scripts/restart-watcher`, `scripts/watcher-init/init-pr-review-state.sh`, `scripts/watcher-init/docker-setup-smoke.sh`, absent `scripts/healthcheck*`, watcher runbooks, compatibility policy, and publication-gate decision.
- Step 7, source read/write surfaces: met. Focused scans and prior artifact readbacks cover compatibility writes, healthcheck, snapshot, repair, runtime owner, issue planning, PR review, prompt templates, turn output, tests, and golden fixtures sufficiently for an evidence-only inventory.
- Step 8, downstream/external evidence inside worktree: met. The artifact records repo-local package descriptors, examples, docs, scripts, tests/golden, and prior artifacts as observed evidence, and explicitly records absent external downstream repos, live archives, external operator scripts, hosted CI, uploads, tags, releases, and release announcements as unavailable.
- Step 9, unsupported-user decisions: met. The artifact records `no_decision_recorded` for all inventoried surfaces and states that future rounds must not infer unsupported-user status from local absence.
- Step 10, create required inventory artifact: met. `orchestrator/rounds/round-071/external-operator-downstream-inventory.md` has the required sections and evidence vocabulary.
- Step 11, conservative conclusion: met. The conclusion states that milestone 007 records observed/unavailable/blocked evidence and unsupported-user gaps only, and does not approve deprecation, migration, removal, publication, upload, release, Cabal exposure changes, production import rewrites, schema/filename/event/write-timing/planner-turn/projection/healthcheck/repair/replay/restart/operator behavior changes.
- Step 12, implementation notes: met. `implementation-notes.md` records changed files, exact scans/readbacks, skipped baseline rationale, evidence summary, and no production behavior change.

### Decision

**APPROVED**

### Evidence

The integrated round result is limited to round-local orchestrator artifacts. `git status --short --branch --untracked-files=all` shows only `orchestrator/rounds/round-071/selection.md`, `plan.md`, `external-operator-downstream-inventory.md`, `implementation-notes.md`, `review.md`, and `review-record.json`; `git diff --name-only` has no tracked output, `git diff --check` and `git diff --cached --check` are clean, and the round-local trailing-whitespace scan is clean.

The artifact satisfies the evidence-only boundary. It explicitly does not approve deprecation, migration, removal, package publication, upload, release, Cabal exposure changes, production import rewrites, runtime compatibility filename/schema changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, or operator behavior changes.

The required milestone-005 public import facades are covered. Refreshed scans support the recorded 65 `CodexWatcher.Core.Ids` importer files, 28 `CodexWatcher.AppServerClient` importer files, seven anchored `CodexWatcher.Workflow.EventLog` import files with one strict exact facade importer, and two anchored `CodexWatcher.Workflow.Permission` import files with no strict exact facade importer. The rows keep public exposure, current users, tests, replacement paths, missing external downstream evidence, and reviewer/operator blockers separate.

The required milestone-006 runtime compatibility paths are covered. Fixture/path and source scans support the artifact's rows for `planning-state.json`, `repair-state.json`, `runtime-owner.json`, `daemon-state.json`, PR review state files, PR URL/state paths, `block-state.json`, and `issue-snapshot.json`. The inventory separates observed repo-local consumers from unavailable external archives/scripts/downstream checkouts and blocked operator/reviewer approval.

Local absence is not treated as removal approval. The inventory repeatedly classifies missing external downstream repositories, live state archives, external operator script inventories, hosted CI, upload/tag/release evidence, and unsupported-user decisions as `unavailable`, `blocked_on_operator_approval`, or `no_decision_recorded`. Every surface retains at least one blocker before cleanup.
