# PR State External Path Inventory

Round: `round-068`
Direction: `direction-017-pr-state-external-path-inventory`

## Scope And Non-Goals

This is source-backed evidence for the current PR review compatibility state
files, PR URL fields, and absent dedicated PR URL/state paths. It does not
approve filename changes, schema changes, event `type` changes, PR review state
projection changes, PR URL storage migration, healthcheck changes, repair
changes, deprecation, removal, publication, upload, or release.

The current policy baseline from
`docs/agentic-workflow-framework/compatibility-deprecation-policy.md` keeps PR
review state files as `keep` and keeps absent dedicated PR URL file wording as
`defer`. The missing gate remains external operator/downstream inventory before
concluding nobody expects a dedicated PR URL/state path.

## Current Producers

`src/CodexWatcher/Runtime/Compatibility.hs` is the current compatibility
projection writer for PR review states.

PR review projections:

| State | Files emitted | `watcher-state.json` status fields |
| --- | --- | --- |
| `PrCheckingReviews` | `watcher-state.json`, `checker-state.json` | `lastTurnStatus = checking`, no review target SHAs |
| `PrFixingReviews` | `watcher-state.json`, `checker-state.json` | `lastTurnStatus = worker_active`, `lastReviewTargetSha = reviewedCommit`, no reviewer target |
| `PrReviewFixQueued` | `watcher-state.json`, `checker-state.json` | `lastTurnStatus = worker_queued`, `lastReviewTargetSha = reviewedCommit`, no reviewer target |
| `PrVerifyingReviewFix` | `watcher-state.json`, `checker-state.json` | `lastTurnStatus = verifying_fix`, `lastReviewTargetSha = reviewedCommit`, no reviewer target |
| `PrReviewingClean` | `watcher-state.json`, `checker-state.json` | `lastTurnStatus = reviewer_active`, both target SHAs set to the reviewed commit |
| `PrWaitingForMergeability` | `watcher-state.json`, `checker-state.json`, `reviewer-state.json` | `lastTurnStatus = waiting_mergeability`, both target SHAs set to the clean review commit |
| `PrMerging` | `watcher-state.json`, `checker-state.json`, `reviewer-state.json` | `lastTurnStatus = clean`, empty worker/reviewer thread ids, both target SHAs set to the clean review commit |
| `CompleteState (PrMerged ...)` | `watcher-state.json` | only `lastTurnStatus = merged` and `mergeCommitSha` |

`prWatcherStateJson` fields are `repoFullName`, `prNumber`, `branch`,
`threadId`, `reviewerThreadId`, `lastTurnStatus`, `lastReviewTargetSha`, and
`lastReviewerTargetSha`.

`checkerStateJson` fields are `repo`, `pr_number`, `has_unresolved`,
`unresolved_count`, `unresolved_thread_ids`, `has_feedback`, and
`review_findings`. `checkerStateClearJson` emits the same field set with
`has_unresolved = false`, `unresolved_count = 0`, empty thread ids,
`has_feedback = false`, and empty findings.

`reviewerStateJson` fields are `reviewed_commit_sha`,
`reviewer_prompt_version`, `added_review_comment_count`,
`prior_findings_status`, `new_findings_status`, `lgtm_comment`,
`prior_findings_summary`, `new_findings_summary`, `blocked_reason`,
`solved_threads`, and `remaining_review_threads`.

`agent-state.json` is not produced by `compatibilityStateWrites`. It exists as
an optional snapshot/readback compatibility file from older or external PR
review states.

Issue PR URL projection is separate from PR review state files:
`issueStateJson` writes `pr_url` in `issue-state.json` through `issuePrUrl`
when an issue state has a PR number. That field is not a dedicated PR URL file.

## Current Readers

`src/CodexWatcher/Snapshot.hs` keeps PR review snapshot readback and issue PR
URL readback distinct.

`loadNodePrReviewSnapshot` requires `config.json` and `watcher-state.json`.
It optionally reads `checker-state.json`, `agent-state.json`,
`reviewer-state.json`, and `block-state.json`.

`NodeIssueState` decodes optional `issue_status`, `pr_number`, `pr_url`, and
`blocked_reason` from issue compatibility snapshots. That is issue-state PR URL
readback, not PR review snapshot PR URL file readback.

`src/CodexWatcher/Healthcheck.hs` reads PR review state files through
`stateFileSpecs SPrReview`: `watcherState` from `watcher-state.json`,
`checkerState` from `checker-state.json`, `agentState` from
`agent-state.json`, `reviewerState` from `reviewer-state.json`,
`blockedState` from `block-state.json`, and `runtimeOwner` from
`runtime-owner.json`. It does not read a dedicated PR URL file.

Healthcheck also checks remote PR state separately through `checkRemotePr`
using `repoFullName` and `prNumber` from config and `gh pr view` merge
metadata. That remote check is not a replacement for compatibility-file
evidence.

## PR URL Field Usage

Current PR URL usage is field and prompt context:

- Issue compatibility writes `pr_url` in `issue-state.json` when a PR number is
  known.
- Issue event-log fixtures contain `prUrl` in `issue_pr_created` and
  `issue_pr_reused` events.
- `src/CodexWatcher/TurnOutput.hs` renders `prUrl` for PR review worker and
  reviewer developer instructions, issue plan mode, final review text, and the
  local helper `prUrl`.
- `src/CodexWatcher/PromptTemplates.hs` consumes `{{prUrl}}` in PR review
  worker/reviewer templates and issue plan mode, and the reviewer template
  renders a literal GitHub PR URL from repo and PR number.
- The checked-in legacy PR review merged config includes `prUrl` plus
  `statePath`, `agentStatePath`, `checkerStatePath`, `blockedStatePath`, and
  `reviewerStatePath`.

None of those uses is a dedicated runtime compatibility file named
`*pr-url*`.

## Dedicated Path Search

The focused fixture/path search found checked-in PR review and issue-state
compatibility fixtures:

- `golden/pr-review/mlf2-pr6-blocked/watcher-state.json`
- `golden/pr-review/mlf2-pr6-clean-ready/checker-state.json`
- `golden/pr-review/mlf2-pr6-clean-ready/reviewer-state.json`
- `golden/pr-review/mlf2-pr6-clean-ready/watcher-state.json`
- `golden/pr-review/mlf2-pr6-merged/agent-state.json`
- `golden/pr-review/mlf2-pr6-merged/checker-state.json`
- `golden/pr-review/mlf2-pr6-merged/reviewer-state.json`
- `golden/pr-review/mlf2-pr6-merged/watcher-state.json`
- `golden/pr-review/mlf2-pr6-unresolved/checker-state.json`
- `golden/pr-review/mlf2-pr6-unresolved/watcher-state.json`
- `golden/issue-implement/mlf2-issue42-blocked/issue-state.json`
- `golden/issue-implement/mlf2-issue42-incomplete/issue-state.json`
- `golden/issue-implement/mlf2-issue42-plan-ready/issue-state.json`

No checked-in file path matching `*pr-url*` or `*pr-state*` was found by the
focused `find` command. Repo-local absence is not external absence: old live
state archives and downstream/operator scripts outside this checkout were not
available in this round.

## Scripts And Operator Paths

`scripts/watcher-init/init-pr-review-state.sh` requires `PR_REVIEW_ROOT`,
`PR_NUMBER`, and `ISSUE_BRANCH`. It creates:

- state dir: `$PR_REVIEW_ROOT/<repo-slug>__pr${PR_NUMBER}`;
- `events.jsonl` with `pr_review_initialized`;
- `config.json` with `repoFullName`, `prNumber`, `branch`, `threadId`,
  `reviewerThreadId`, `stateDir`, `eventsPath`, and `workdir`;
- `dry-run-command.sh`;
- `restart-command.sh` using `run-pr-review --execute --loop` and
  `--pid-file "$pr_state_dir/pr-review-watcher.pid"`.

`scripts/watcher-init/docker-setup-smoke.sh` sets
`PR_REVIEW_ROOT=$state_root/pr-review-watchers`, initializes PR review state,
checks generated command scripts with `bash -n`, and replays the generated PR
review `events.jsonl`.

`src/CodexWatcher/Domain/PrReview/LaunchCli.hs` uses the same
`pr-review-watchers` root convention for issue handoff-derived child PR review
watchers. It writes `config.json`, appends the initial event, writes initial
compatibility files, uses child pid `watcher.pid`, and starts `run-pr-review`
with `--state-dir`, `--events`, `--repo`, `--workdir`, app-server options,
`--execute`, `--loop`, and `--pid-file`.

`scripts/restart-watcher` supports `--domain pr-review`, defaults PR review pid
path to `$state_dir/watcher.pid`, defaults command path to
`$state_dir/restart-command.sh`, reads `$state_dir/runtime-owner.json` for a
pid, can drop a blocked tail from `events.jsonl`, and removes pid files,
`runtime-owner.json`, `block-state.json`, `daemon-state.json`, and
`stale-active-turn.json` during cleanup. It does not reference dedicated
`pr-url` or `pr-state` files.

## Runbook Expectations

The runbook documents container-local operator paths and current generated
state files:

- `docs/watcher-agent-runbook/README.md` says helper scripts create
  conventional state directories, initial `events.jsonl`, `config.json`,
  `dry-run-command.sh`, and `restart-command.sh`.
- `docs/watcher-agent-runbook/templates/watcher.env.example` sets
  `PR_REVIEW_ROOT=/workspace/artifacts/pr-review-watchers`.
- `docs/watcher-agent-runbook/project-watch/04-start-pr-review.md` expects
  `init-pr-review-state.sh`, conventional
  `$PR_REVIEW_ROOT/<repo-slug>__pr${PR_NUMBER}`, dry-run through
  `$PR_STATE_DIR/dry-run-command.sh`, and execute loop through
  `$PR_STATE_DIR/restart-command.sh`.
- `docs/watcher-agent-runbook/project-watch/05-resume-old-state.md` requires
  `events.jsonl`, `config.json` for generated states, and
  `restart-command.sh` when available; it prefers `scripts/restart-watcher`
  for resume and supports `--domain pr-review`.
- `docs/watcher-agent-runbook/checklists/operator-checklist.md` requires
  successful replay, generated command-script syntax, no running pid for the
  same state dir, absent/inactive `runtime-owner.json`, and post-restart checks
  for `daemon.log`, `daemon.err.log`, `watcher.log.jsonl`, and
  `block-state.json`.
- `docs/watcher-agent-runbook/runbook-validation.md` requires Docker smoke to
  initialize PR review state, check generated command scripts, replay initial
  event logs, and check watcher loop command help.

These docs do not mention dedicated `pr-url` or `pr-state` files, but this
only proves repo-local runbook absence.

## Existing Test And Fixture Coverage

Current coverage protecting this surface includes:

- `prop_issueImplementationCompatibilityWritesPrUrl` verifies
  `issue-state.json` has `pr_number` and `pr_url` for issue states with a PR.
- `prop_prReviewCompatibilityClearsCheckerState` verifies selected PR review
  states write a cleared `checker-state.json`.
- Golden snapshot replay covers `golden/pr-review/mlf2-pr6-merged`,
  `mlf2-pr6-unresolved`, `mlf2-pr6-blocked`, `mlf2-pr6-clean-ready`, and
  issue implement snapshots.
- Golden bootstrap coverage replays normalized bootstrap events from the same
  PR review and issue implement snapshots.
- Golden event-log coverage covers PR review event logs and issue implement
  event logs with `prUrl` fields.
- Healthcheck tests assert healthcheck is read-only and source-level
  state-file surfacing includes domain state files; round-local source readback
  confirms current `SPrReview` includes the PR review-specific state-file list.
- The merged PR review golden config preserves legacy path fields
  `statePath`, `agentStatePath`, `checkerStatePath`, `blockedStatePath`, and
  `reviewerStatePath`.

No current test or fixture proves a dedicated `*pr-url*` or `*pr-state*` file
contract because the focused search found no such checked-in file.

## Classification And Blockers

Current classification remains:

- `keep`: PR review compatibility state files currently named
  `watcher-state.json`, `checker-state.json`, optional readback
  `agent-state.json`, and `reviewer-state.json`.
- `keep`: issue `pr_url` field compatibility where issue state has a PR.
- `defer`: absent dedicated PR URL file wording and any dedicated
  `*pr-url*` or `*pr-state*` path conclusion.

Conservative blockers before cleanup, migration, schema, healthcheck, repair,
projection, restart, removal, publication, upload, or release decisions:

- external operator/downstream path expectations are not fully inventoried;
- no dedicated checked-in `*pr-url*` or `*pr-state*` fixture exists to migrate
  or remove;
- no old live-state archive proves historical absence of dedicated PR URL or
  PR state paths;
- current source still reads optional `agent-state.json` even though current
  compatibility projection does not produce it;
- legacy golden PR review config still records path fields for
  `watcher-state.json`, `agent-state.json`, `checker-state.json`,
  `block-state.json`, and `reviewer-state.json`;
- no selected approval exists for filename/schema/event-type changes,
  healthcheck redesign, repair redesign, PR URL storage migration,
  compatibility projection changes, restart behavior changes, deprecation,
  removal, package publication, upload, or release.
