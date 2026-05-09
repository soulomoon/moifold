### Checks Run

- Command: `git status --short --branch --untracked-files=all`
  Result: pass. Branch is `orchestrator/round-072-gated-compatibility-removals`; changed paths are untracked round-local artifacts under `orchestrator/rounds/round-072/`: `selection.md`, `plan.md`, `no-lawful-removal-surface-status.md`, and `implementation-notes.md`.
- Command: `git diff --name-only`
  Result: pass. No tracked diff output. Changed-path inspection used status plus untracked-file listing because this artifact-only round is currently untracked.
- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-072 | sort`
  Result: pass. Untracked paths are limited to `orchestrator/rounds/round-072/implementation-notes.md`, `orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`, `orchestrator/rounds/round-072/plan.md`, and `orchestrator/rounds/round-072/selection.md`.
- Command: `git diff --check`
  Result: pass with no output.
- Command: `git diff --cached --check`
  Result: pass with no output; no staged diff exists.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-072`
  Result: pass with no output.
- Command: `test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md && test -f orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md && test -f orchestrator/rounds/round-059/plan.md && test ! -e orchestrator/rounds/round-059/worker-plan.json && test -f orchestrator/rounds/round-072/no-lawful-removal-surface-status.md && test -f orchestrator/rounds/round-072/implementation-notes.md && test ! -e orchestrator/rounds/round-072/worker-plan.json`
  Result: pass. Rev-002 artifacts and round 059 plan exist, and no worker fan-out plan exists for round 059 or round 072.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Project contract preserves event schemas, golden logs, public compatibility facades, runtime compatibility files, healthcheck, repair, and compatibility cleanup sequencing.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
  Result: pass. Verification contract read back baseline checks, artifact-only allowance, forbidden-diff checks, alignment checks, removal approval gates, and roadmap overrides.
- Command: `sed -n '1,760p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Roadmap id `2026-05-09-01-compatibility-surface-cleanup`, revision `rev-002`, style `strategy-backlog`, activation metadata, milestones 001-007 complete, milestone 008 pending, and milestone 009 dependent on milestone 008 all read back.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
  Result: pass. Retry contract confirms removal is not a retry fallback; missing approval records a hold or deferral and must not remove the surface.
- Command: `sed -n '1,240p' orchestrator/rounds/round-072/selection.md`
  Result: pass. Selection lineage is `milestone-008-gated-compatibility-removals` / `none-selected-no-lawful-removal-surface` / `round-072-no-lawful-removal-surface-status`; scope is status evidence only and excludes deprecation, migration, removal, publication, upload, release, Cabal exposure changes, production import rewrites, compatibility behavior changes, and milestone-009 selection.
- Command: `sed -n '1,260p' orchestrator/rounds/round-072/plan.md`
  Result: pass. Plan requires an artifact-only no-lawful-removal status, classifying both removal directions as not currently lawful, preserving round 071 blockers, and not selecting milestone 009.
- Command: `sed -n '1,360p' orchestrator/rounds/round-071/external-operator-downstream-inventory.md`
  Result: pass. Round 071 evidence records unavailable external downstream repositories, unavailable live state archives, unavailable external operator scripts, blocked approval evidence, no unsupported-user decisions, and per-surface blockers.
- Command: `sed -n '1,260p' orchestrator/rounds/round-071/review.md`
  Result: pass. Round 071 review approved inventory only and explicitly did not approve deprecation, migration, removal, publication, upload, release, Cabal exposure changes, production import rewrites, schema/filename/event/write-timing/planner-turn/projection/healthcheck/repair/replay/restart/operator behavior changes.
- Command: `sed -n '1,220p' orchestrator/rounds/round-071/implementation-notes.md`
  Result: pass. Round 071 notes preserve artifact-only scope, unavailable evidence, blocked approval, and no production behavior changes.
- Command: `sed -n '1,320p' orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`
  Result: pass. Status artifact records milestone 008 as dependency-reached but blocked/held, classifies both `direction-021` and `direction-022` as not currently lawful, keeps local absence as unavailable/blocked evidence rather than approval, does not mark milestone 008 complete, and does not select milestone 009.
- Command: `sed -n '1,220p' orchestrator/rounds/round-072/implementation-notes.md`
  Result: pass. Notes record changed files, readbacks, no worker fan-out, artifact-only baseline skip rationale, and final no-source-change claim.
- Command: `rg -n "dependency-reached|blocked|held|does not mark milestone 008 complete|does not select milestone 009|does not imply terminal family completion|Local absence is not removal approval|not currently lawful|retry-subloop|approval is missing|must not remove" orchestrator/rounds/round-072/no-lawful-removal-surface-status.md orchestrator/rounds/round-072/implementation-notes.md`
  Result: pass. Required hold/status, missing-approval, no-milestone-009, and local-absence language is present.
- Command: `rg -n "direction-021|direction-022|milestone-008|milestone-009|deprecation|migration|removal|package publication|upload|release|Cabal exposure|production import|schema|filename|event-type|write-timing|planner-turn|projection|healthcheck|repair|replay|restart-script|operator behavior" orchestrator/rounds/round-072/no-lawful-removal-surface-status.md`
  Result: pass. Required direction classifications and forbidden-scope statements are present.
- Command: `rg -n 'Milestone id: `milestone-008|Depends on: `milestone-007|No exact surface has passed|direction-021-remove-approved-import-facades|direction-022-remove-approved-runtime-compatibility-surfaces|Milestone id: `milestone-009|Depends on: `milestone-008|Local absence remains unavailable or blocked evidence' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Active roadmap confirms milestone 008 depends on milestone 007, has no exact approved surface yet, contains directions 021/022, and milestone 009 depends on milestone 008.
- Command: `rg -n "Removal is not a retry fallback|approval is missing|records a hold or deferral|must not remove the surface|REJECTED because removal lacks explicit approval" orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
  Result: pass. Retry-subloop hold/deferral rule read back.
- Command: `rg -n "unavailable external downstream|unavailable live state|unavailable external operator|blocked operator/reviewer|no recorded unsupported-user|per-surface blockers|Local absence remains unavailable or blocked evidence|does not approve deprecation" orchestrator/rounds/round-071/external-operator-downstream-inventory.md orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
  Result: pass. Round 071 blockers and active roadmap blocker summary read back.

The active verification baseline also names `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`. These were intentionally skipped under the rev-002 artifact-only allowance because changed paths are limited to round-local orchestrator artifacts and there are no production source, test, fixture, script, documentation-policy, Cabal descriptor, roadmap, project-contract, or controller-state changes.

### Plan Compliance

- Step 1, re-read required control artifacts: met. Selection, project contract, rev-002 roadmap, verification contract, and retry-subloop were read back.
- Step 2, re-read round 071 evidence: met. Round 071 inventory, review, and implementation notes were read back and support the current blocker summary.
- Step 3, write no-lawful-removal status artifact with required sections: met. The artifact contains scope/non-goals, active roadmap gate summary, round 071 blocker summary, direction-021 classification, direction-022 classification, milestone-009 sequencing note, and conservative conclusion.
- Step 4, record milestone 008 as blocked/held without marking it complete: met. The artifact says milestone 008 is dependency-reached but blocked/held, does not mark milestone 008 complete, does not select milestone 009, and does not imply terminal family completion.
- Step 5, forbid unapproved deprecation/removal and compatibility behavior changes: met. The artifact explicitly forbids deprecation, migration, removal, package publication, upload, release, Cabal exposure changes, production import rewrites, schema/filename/event-type/write-timing/planner-turn/projection/healthcheck/repair/replay/restart-script/operator behavior changes.
- Step 6, write implementation notes: met. Notes summarize changed files, readbacks, no worker fan-out, skipped baseline rationale, and no-source-change claim.
- Step 7, stay artifact-only: met. Changed-path inspection shows only round-local orchestrator artifacts under `orchestrator/rounds/round-072/`; no source, tests, docs outside round-local artifacts, scripts, fixtures, package files, roadmap files, project contract, controller state, or merge artifacts were changed.
- Step 8, do not create worker fan-out plan: met. `orchestrator/rounds/round-072/worker-plan.json` does not exist.

### Decision

**APPROVED**

### Evidence

The integrated round result is artifact-only. `git status --short --branch --untracked-files=all` and `git ls-files --others --exclude-standard orchestrator/rounds/round-072 | sort` show only round-local untracked artifacts. `git diff --name-only` has no tracked output, and both diff whitespace checks are clean. The round-local trailing-whitespace scan is clean.

The status artifact records milestone 008 as dependency-reached but blocked/held for removal. It does not mark milestone 008 complete, does not select milestone 009, and does not imply terminal family completion.

Both removal directions are correctly classified as not currently lawful. `direction-021-remove-approved-import-facades` is held because no exact import facade has recorded all policy, follow-up evidence, external inventory, unsupported-user, behavior/package-boundary, and reviewer-approval gates. `direction-022-remove-approved-runtime-compatibility-surfaces` is held because no exact runtime compatibility file or snapshot has recorded all old-log/golden, repair, healthcheck or non-healthcheck, runtime-owner, fixture, operator, write-timing, unsupported-user, and reviewer-approval gates.

The artifact preserves round 071 blockers. Unavailable external downstream repositories, unavailable live state archives, unavailable external operator scripts, blocked operator/reviewer/release-gate approval evidence, missing unsupported-user decisions, and per-surface blockers remain removal blockers. Local absence remains unavailable or blocked evidence, not approval.

The artifact does not approve deprecation, migration, removal, package publication, upload, release, Cabal exposure changes, production import rewrites, schema changes, filename changes, event-type changes, write-timing changes, planner-turn changes, projection changes, healthcheck changes, repair changes, replay changes, restart-script changes, or operator behavior changes.
