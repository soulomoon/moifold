### Checks Run
- Command: `git status --short --branch`
  Result: pass. Branch is `orchestrator/round-068-pr-state-external-path-inventory`; only untracked `orchestrator/rounds/round-068/` artifacts are present.
- Command: `git diff --name-only`
  Result: pass. No tracked diff output. Path-scope check uses `git status --short` and `git ls-files --others --exclude-standard orchestrator/rounds/round-068` because the integrated round artifacts are untracked.
- Command: `git ls-files --others --exclude-standard orchestrator/rounds/round-068`
  Result: pass. Untracked files are limited to `orchestrator/rounds/round-068/implementation-notes.md`, `orchestrator/rounds/round-068/plan.md`, `orchestrator/rounds/round-068/pr-state-external-path-inventory.md`, and `orchestrator/rounds/round-068/selection.md`.
- Command: `git diff --check`
  Result: pass. No whitespace errors in tracked diff.
- Command: `rg -n "[ \t]+$" orchestrator/rounds/round-068`
  Result: pass. No trailing whitespace matches in round-068 artifacts.
- Command: `test -f orchestrator/rounds/round-068/worker-plan.json; echo worker_plan_exists=$?`
  Result: pass. Output `worker_plan_exists=1`, so no worker fan-out file exists.
- Command: `sed -n '110,230p' src/CodexWatcher/Runtime/Compatibility.hs`
  Result: pass. Source confirms PR review compatibility writes for `PrCheckingReviews`, `PrFixingReviews`, `PrReviewFixQueued`, `PrVerifyingReviewFix`, `PrReviewingClean`, `PrWaitingForMergeability`, `PrMerging`, and `CompleteState (PrMerged ...)`, plus `pr_url` issue projection through `issuePrUrl`.
- Command: `sed -n '140,245p' src/CodexWatcher/Snapshot.hs`
  Result: pass. Source confirms `NodeIssueState` decodes optional `pr_url`; `loadNodePrReviewSnapshot` reads required `config.json`/`watcher-state.json` and optional `checker-state.json`, `agent-state.json`, `reviewer-state.json`, and `block-state.json`.
- Command: `sed -n '235,285p' src/CodexWatcher/Healthcheck.hs`
  Result: pass. Source confirms `SPrReview` healthcheck state files are `watcher-state.json`, `checker-state.json`, `agent-state.json`, `reviewer-state.json`, `block-state.json`, and `runtime-owner.json`; no dedicated PR URL file is listed.
- Command: `sed -n '1,120p' scripts/watcher-init/init-pr-review-state.sh`
  Result: pass. Script confirms `PR_REVIEW_ROOT`, conventional PR state directory, generated `events.jsonl`, `config.json`, `dry-run-command.sh`, and `restart-command.sh`; no dedicated `pr-url` or `pr-state` path is referenced.
- Command: `sed -n '55,105p' scripts/watcher-init/docker-setup-smoke.sh`
  Result: pass. Smoke script confirms `PR_REVIEW_ROOT=$state_root/pr-review-watchers`, command-script syntax checks, and PR review replay validation.
- Command: `sed -n '100,230p' scripts/restart-watcher`
  Result: pass. Restart script confirms PR review pid defaults, `restart-command.sh`, `runtime-owner.json` readback, blocked-tail handling, and cleanup of pid/runtime/block/daemon/stale-active files; no dedicated PR URL/state path is referenced.
- Command: `sed -n '450,490p' src/CodexWatcher/TurnOutput.hs`
  Result: pass. Source confirms `prUrl` helper renders GitHub PR URLs as prompt/output context.
- Command: `sed -n '190,245p' src/CodexWatcher/PromptTemplates.hs`
  Result: pass. Source confirms PR review worker/reviewer templates consume `{{prUrl}}` as prompt context, not a compatibility-file path.
- Command: `find . -path './.git' -prune -o \( -name '*pr-url*' -o -name '*pr-state*' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' \) -print | sort`
  Result: pass. Found checked-in PR review and issue-state fixtures plus the round artifact path containing `pr-state` in its name; no checked-in dedicated `*pr-url*` or `*pr-state*` runtime fixture was found.
- Command: `rg -n "watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|pr_url|prUrl|pr-url|pr state|pr-state|PR URL|PR_REVIEW_ROOT|pr-review-watchers|statePath|checkerStatePath|reviewerStatePath|blockedStatePath|runtime-owner\\.json" src app test scripts docs examples golden orchestrator/rounds/round-053 orchestrator/rounds/round-055 orchestrator/rounds/round-057 orchestrator/rounds/round-058 orchestrator/rounds/round-065 orchestrator/rounds/round-066 orchestrator/rounds/round-067`
  Result: pass. Scan supports the artifact's source, test, fixture, script, docs, and prior-round evidence claims for current state files, PR URL fields, path fields, and absent dedicated checked-in path fixtures.
- Command: `rg -n "PrCheckingReviews|PrFixingReviews|PrReviewFixQueued|PrVerifyingReviewFix|PrReviewingClean|PrWaitingForMergeability|PrMerging|PrMerged|prWatcherStateJson|checkerStateJson|checkerStateClearJson|reviewerStateJson|issuePrUrl|loadNodePrReviewSnapshot|NodeIssueState|stateFileSpecs|SPrReview" src/CodexWatcher test/Main.hs orchestrator/rounds/round-068`
  Result: pass. Scan confirms implementation, tests, and the round artifact cover the selected PR review projection/readback terms.
- Command: `rg -n "pr-review|PR review|PR URL|pr_url|prUrl|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|pr-review-watchers|restart|resume|healthcheck|operator|downstream|external|PR_REVIEW_ROOT" docs/watcher-agent-runbook docs/agentic-workflow-framework orchestrator/rounds/round-068`
  Result: pass. Scan confirms runbook/operator expectations, policy classifications, and external-inventory blockers are represented.
- Command: `cabal build all`
  Result: skipped under the active verification contract's artifact-only allowance. The integrated diff is limited to round-local orchestrator artifacts and does not touch production source, tests, fixtures, scripts, docs policy files, package descriptors, roadmap files, controller state, or the project contract.
- Command: `cabal test watcher-core-test`
  Result: skipped under the same artifact-only allowance for the same path-scope reason.
- Command: `scripts/validate-workflow-packages.sh`
  Result: skipped under the same artifact-only allowance for the same path-scope reason.
- Command: `git diff --cached --check`
  Result: not applicable. No files were staged.

### Plan Compliance
- Step 1, re-read active inputs: met. `selection.md`, `project-contract.md`, and `verification.md` were read; the round remains evidence-only for `direction-017-pr-state-external-path-inventory`.
- Step 2, refresh prior evidence and policy baseline: met. The artifact cites the current policy baseline as `keep` for PR review state files and `defer` for absent dedicated PR URL file wording, with external operator/downstream inventory still blocking stronger conclusions.
- Step 3, inspect PR review compatibility projections: met. The artifact records every selected PR review state, emitted files, `watcher-state.json` status fields, `prWatcherStateJson`, `checkerStateJson`, `checkerStateClearJson`, and `reviewerStateJson` fields; source readback supports the claims.
- Step 4, inspect issue PR URL projection: met. The artifact distinguishes issue `pr_url` in `issue-state.json` from a dedicated PR URL file.
- Step 5, inspect snapshot readback: met. The artifact keeps PR review snapshot readback distinct from issue-state PR URL readback and names required/optional snapshot files.
- Step 6, inspect healthcheck readback: met. The artifact records the `SPrReview` healthcheck state-file list and correctly treats remote PR checking as separate from compatibility-file evidence.
- Step 7, inspect scripts and operator paths: met. The artifact records `init-pr-review-state.sh`, Docker smoke, launch CLI, and `scripts/restart-watcher` behavior, while limiting dedicated-path absence to repo-local evidence.
- Step 8, inspect runbooks and docs: met. The artifact records PR review root, generated files, restart/resume, healthcheck, and operator recovery expectations from the named runbook surfaces.
- Step 9, inspect prompt/output PR URL usage: met. The artifact treats `prUrl` prompt/output usage as context, not runtime compatibility-file storage.
- Step 10, inspect tests and golden readback: met. The artifact records PR review compatibility write coverage, checker clearing, reviewer-state classification, golden replay/bootstrap readback, healthcheck state-file coverage, issue `pr_url`, event-log `prUrl`, and no dedicated PR URL/state fixture coverage.
- Step 11, run focused inventories: met. The focused `find` and `rg` commands were run and results are reflected in the artifact.
- Step 12, create round-local evidence artifact: met. `orchestrator/rounds/round-068/pr-state-external-path-inventory.md` contains the requested scope, producers, readers, PR URL field usage, path search, healthcheck, snapshot/golden, scripts/runbooks, tests, classification, and blockers.
- Step 13, keep blockers conservative: met. The artifact explicitly retains external operator/downstream inventory limits, missing checked-in dedicated path fixtures, missing old live-state archive evidence, optional `agent-state.json` readback, legacy config path fields, and no approval for behavior/schema/storage/removal/publication changes.
- Step 14, implementation notes: met. `orchestrator/rounds/round-068/implementation-notes.md` records changed files, scans, fixture-search results, artifact-only baseline skip rationale, and that no production behavior changed.

### Decision
**APPROVED**

### Evidence
The integrated result is an evidence-only round-local artifact set. The untracked files are confined to `orchestrator/rounds/round-068/`, and no tracked production, test, fixture, script, package, roadmap, controller-state, or project-contract diff exists.

Source readback supports the core claims: `Compatibility.hs` writes the current PR review compatibility files and issue `pr_url`; `Snapshot.hs` reads current PR review snapshot files and issue `pr_url`; `Healthcheck.hs` reads PR review state files but no dedicated PR URL file; PR review init/smoke/restart scripts use the current state directory shape and do not reference dedicated `pr-url`/`pr-state` runtime files.

The artifact does not authorize filename, schema, event type, projection, PR URL storage, healthcheck, repair, cleanup, deprecation, removal, publication, upload, or release changes. Its final classification remains conservative: current PR review state files and issue `pr_url` stay `keep`; absent dedicated PR URL/state path conclusions stay `defer` pending external operator/downstream evidence.
