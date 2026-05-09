### Goal

Record current evidence for PR review compatibility outputs and PR URL/state
path expectations: PR review `watcher-state.json`, `checker-state.json`,
optional `agent-state.json`, `reviewer-state.json`, issue `pr_url`, PR review
config `prUrl`, the absence or presence of dedicated `*pr-url*` and
`*pr-state*` paths, runbook/script references, downstream/operator
expectations, current PR review compatibility output readback, and golden
fixture readback.

This is an evidence-only round for
`direction-017-pr-state-external-path-inventory` under
`milestone-006-runtime-compatibility-follow-up-evidence`. It must not change
filenames, schemas, event JSON `type` fields, PR review state projection
behavior, PR URL storage, healthcheck behavior, repair behavior, production
source, tests, fixtures, scripts, runbooks, roadmap files, controller state,
package metadata, deprecation status, migration status, removal approval,
publication, upload, or release approval.

### Approach

Keep this as a sequential evidence-only round. Use
`orchestrator/project-contract.md` for stable compatibility invariants and the
active verification contract for baseline expectations. Do not write
`worker-plan.json`: this round is one coupled inventory over PR review state
files, PR URL fields, absent dedicated paths, healthcheck readback, snapshot
readback, runbooks, scripts, and operator expectations. Splitting it would
duplicate scans and produce overlapping ownership.

The implementer should create one round-local evidence artifact, expected as
`orchestrator/rounds/round-068/pr-state-external-path-inventory.md`, plus
round-local implementation notes if the implementer normally records them.
The artifact should be source-backed and conservative. If dedicated
`*pr-url*` or `*pr-state*` files are still absent, record that as observed
absence and as an external-path expectation blocker; do not introduce files,
schemas, migrations, fixtures, or behavior changes.

### Steps

1. Re-read the active round/control inputs before editing:
   `orchestrator/rounds/round-068/selection.md`,
   `orchestrator/project-contract.md`, and
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.
   Confirm the round remains evidence-only under
   `direction-017-pr-state-external-path-inventory`.

2. Refresh prior evidence from rounds 053, 055, 057, 058, 065, 066, and 067,
   plus `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Treat the current baseline as: PR review state files are classified `keep`;
   absent dedicated PR URL file wording is classified `defer`; no dedicated
   `*pr-url*` or `*pr-state*` producer was previously found; external
   operator/downstream path expectations remain the blocker.

3. Inspect `src/CodexWatcher/Runtime/Compatibility.hs`. Record all current PR
   review compatibility projections exactly:
   - `PrCheckingReviews`, `PrFixingReviews`, `PrReviewFixQueued`,
     `PrVerifyingReviewFix`, `PrReviewingClean`, `PrWaitingForMergeability`,
     `PrMerging`, and `CompleteState (PrMerged ...)`;
   - emitted files: `watcher-state.json`, `checker-state.json`, and
     `reviewer-state.json` where applicable;
   - `prWatcherStateJson` fields: `repoFullName`, `prNumber`, `branch`,
     `threadId`, `reviewerThreadId`, `lastTurnStatus`,
     `lastReviewTargetSha`, and `lastReviewerTargetSha`;
   - `checkerStateJson`/`checkerStateClearJson` fields and
     `reviewerStateJson` fields.
   Record that `agent-state.json` is read as a compatibility snapshot file but
   is not produced by `compatibilityStateWrites`. Do not propose a projection
   or file-list change.

4. In the same file, inspect issue PR URL projection. Record that issue
   compatibility state writes `pr_url` in `issue-state.json` via `issuePrUrl`
   when an issue state has a PR number. Record that this is an issue
   compatibility field, not a dedicated PR URL file.

5. Inspect `src/CodexWatcher/Snapshot.hs`. Record current readback:
   `loadNodePrReviewSnapshot` requires `config.json` and
   `watcher-state.json`, and optionally reads `checker-state.json`,
   `agent-state.json`, `reviewer-state.json`, and `block-state.json`;
   `NodeIssueState` decodes optional `pr_url`. Keep PR review snapshot
   readback distinct from issue-state PR URL readback.

6. Inspect `src/CodexWatcher/Healthcheck.hs`, especially `stateFileSpecs`,
   `sharedStateFiles`, `readStateFiles`, and `summarizeLoadedItem`. Record
   that `SPrReview` healthcheck reads `watcherState`, `checkerState`,
   `agentState`, `reviewerState`, `blockedState`, and `runtimeOwner`, but no
   dedicated PR URL file. Record that healthcheck summary also checks remote PR
   state separately through config/remote metadata; do not describe this as a
   replacement for compatibility-file evidence.

7. Inspect PR review launch/init scripts and operator scripts:
   `scripts/watcher-init/init-pr-review-state.sh`,
   `scripts/watcher-init/docker-setup-smoke.sh`, and
   `scripts/restart-watcher`. Record the current PR review state directory
   shape, generated `config.json`, `events.jsonl`, command scripts, pid-file
   naming, `PR_REVIEW_ROOT` usage, and restart cleanup behavior. If scripts do
   not reference dedicated `pr-url` or `pr-state` files, record that as
   repo-local absence only, not proof of external absence.

8. Inspect runbooks and docs for operator expectations:
   `docs/watcher-agent-runbook/project-watch/04-start-pr-review.md`,
   `docs/watcher-agent-runbook/project-watch/05-resume-old-state.md`,
   `docs/watcher-agent-runbook/checklists/operator-checklist.md`,
   `docs/watcher-agent-runbook/README.md`,
   `docs/watcher-agent-runbook/runbook-validation.md`, and
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`.
   Record every PR review state-file, PR URL, PR review root, restart, resume,
   healthcheck, and operator recovery expectation found. Separate current
   runbook expectations from prior-round policy evidence.

9. Inspect current PR review prompt/output PR URL usage:
   `src/CodexWatcher/TurnOutput.hs` and `src/CodexWatcher/PromptTemplates.hs`.
   Record `prUrl`/`prUrl`-template usage as agent prompt/output context, not as
   a runtime compatibility-file path. Do not propose moving this into state
   files.

10. Inspect current tests and golden readback in `test/Main.hs`,
    `test/HealthcheckSpec.hs`, `golden/pr-review/*`,
    `golden/issue-implement/*/issue-state.json`, and
    `golden/event-log/{pr-review,issue-implement}/*/events.jsonl`. Record
    coverage for PR review compatibility writes, checker clearing,
    reviewer-state classification, golden replay/bootstrap readback,
    healthcheck state-file lists, issue `pr_url`, and event-log `prUrl`
    fields. Do not claim dedicated PR URL/state fixture coverage unless a
    current file search finds those files.

11. Run focused inventories across source, tests, scripts, docs, examples,
    golden fixtures, and relevant prior rounds for:
    `watcher-state.json`, `checker-state.json`, `agent-state.json`,
    `reviewer-state.json`, `pr_url`, `prUrl`, `pr-url`, `pr state`,
    `pr-state`, `PR_REVIEW_ROOT`, `pr-review-watchers`, `statePath`,
    `checkerStatePath`, `reviewerStatePath`, `blockedStatePath`, and
    `runtime-owner.json`. Separate production writers, production readers,
    tests, fixtures, scripts, runbooks, and prior-round evidence artifacts.

12. Create the round-local evidence artifact with sections for scope and
    non-goals, baseline policy, current producers, current readers,
    PR URL field usage, dedicated path absence/presence, healthcheck readback,
    snapshot/golden readback, runbook/script/operator inventory, existing test
    coverage, current classification, and blockers before any later cleanup
    decision.

13. Keep blockers conservative. At minimum, retain external
    operator/downstream path expectation inventory limits beyond repo-local
    evidence, no dedicated checked-in `*pr-url*` or `*pr-state*` fixture if the
    search is still empty, no old live-state archive proving historical path
    absence, no approval for changing PR review state projections or PR URL
    storage, and no selected approval for filename/schema/event-type changes,
    healthcheck or repair redesign, migration, deprecation, removal,
    publication, upload, or release.

14. If the implementer records implementation notes, include changed files,
    exact scans run, fixture-search results, any skipped baseline rationale,
    and a statement that no production behavior changed.

### Verification

Use focused readback commands first:

```sh
sed -n '1,260p' orchestrator/rounds/round-068/selection.md
sed -n '1,260p' orchestrator/project-contract.md
sed -n '1,320p' orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md
sed -n '110,230p' src/CodexWatcher/Runtime/Compatibility.hs
sed -n '140,245p' src/CodexWatcher/Snapshot.hs
sed -n '235,285p' src/CodexWatcher/Healthcheck.hs
sed -n '1,120p' scripts/watcher-init/init-pr-review-state.sh
sed -n '55,105p' scripts/watcher-init/docker-setup-smoke.sh
sed -n '100,230p' scripts/restart-watcher
sed -n '450,490p' src/CodexWatcher/TurnOutput.hs
sed -n '190,245p' src/CodexWatcher/PromptTemplates.hs
sed -n '120,145p' docs/agentic-workflow-framework/compatibility-deprecation-policy.md
```

Run the focused scans and record results:

```sh
find . -path './.git' -prune -o \( -name '*pr-url*' -o -name '*pr-state*' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' \) -print
rg -n "watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|pr_url|prUrl|pr-url|pr state|pr-state|PR URL|PR_REVIEW_ROOT|pr-review-watchers|statePath|checkerStatePath|reviewerStatePath|blockedStatePath" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-065 orchestrator/rounds/round-066 orchestrator/rounds/round-067
rg -n "PrCheckingReviews|PrFixingReviews|PrReviewFixQueued|PrVerifyingReviewFix|PrReviewingClean|PrWaitingForMergeability|PrMerging|PrMerged|prWatcherStateJson|checkerStateJson|checkerStateClearJson|reviewerStateJson|issuePrUrl|loadNodePrReviewSnapshot|NodeIssueState|stateFileSpecs|SPrReview" src/CodexWatcher test/Main.hs orchestrator/rounds/round-068
rg -n "pr-review|PR review|PR URL|pr_url|prUrl|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|pr-review-watchers|restart|resume|healthcheck|operator|downstream|external" docs/watcher-agent-runbook docs/agentic-workflow-framework orchestrator/rounds/round-068
```

Validate the artifact-only diff:

```sh
git status --short --branch
git diff --name-only
git diff --check
rg -n "[ \t]+$" orchestrator/rounds/round-068
```

Full baseline expectations from the active verification contract are:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If the implementation remains limited to round-local orchestrator artifacts,
the Cabal and package baselines may be skipped under the artifact-only
allowance. If production source, tests, fixtures, schemas, scripts, docs,
package files, roadmap files, controller state, or project contract change,
the implementer must stop and either narrow the diff back to the selected
evidence scope or run the full baseline above. If files are staged later, also
run:

```sh
git diff --cached --check
```
