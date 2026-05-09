# External Operator And Downstream Inventory

Round: `round-071`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup` `rev-002`
Milestone: `milestone-007-external-operator-downstream-inventory`
Direction: `direction-020-external-operator-downstream-inventory`

## Scope And Non-Goals

This artifact is a source-backed, conservative inventory of external operator
and downstream evidence for the compatibility surfaces covered by milestones
005 and 006.

It records:

- public import consumers for `CodexWatcher.Core.Ids`,
  `CodexWatcher.AppServerClient`, `CodexWatcher.Workflow.EventLog`, and
  `CodexWatcher.Workflow.Permission`;
- runtime compatibility paths for `planning-state.json`,
  `repair-state.json`, `runtime-owner.json`, `daemon-state.json`, PR review
  state files and PR URL/state paths, `block-state.json`, and
  `issue-snapshot.json`;
- shell/operator consumers, runbook references, docs references, checked-in
  fixture evidence, unavailable evidence, blocked evidence, unsupported-user
  decisions, and per-surface blockers.

This round does not approve deprecation, migration, removal, package
publication, upload, release, Cabal exposure changes, production import
rewrites, schema changes, filename changes, event-type changes, write-timing
changes, planner-turn changes, projection changes, healthcheck changes, repair
changes, replay changes, restart-script changes, or operator behavior changes.

Local absence is never treated as approval. Missing downstream repositories,
live state archives, operator approval records, or unsupported-user decisions
are recorded as unavailable or blocked evidence.

## Evidence Status Vocabulary

| Status | Meaning |
| --- | --- |
| `observed` | Current repo source, tests, docs, scripts, fixtures, or round artifacts directly reference the surface. |
| `unavailable` | The required evidence source was not present in this worktree, such as an external downstream checkout or live state archive. |
| `blocked_on_operator_approval` | A later decision would require explicit operator/reviewer/release-gate approval that is not recorded here. |
| `unsupported_user_decision` | A recorded decision explicitly classifies a remaining user as unsupported. |
| `no_decision_recorded` | No unsupported-user decision was found in this worktree. |

## Milestone-005 Public Import Inventory

The refreshed direct import scan was:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.(Core\.Ids|AppServerClient|Workflow\.EventLog|Workflow\.Permission)(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | sort
```

Summary counts from the refreshed scan:

- `CodexWatcher.Core.Ids`: 65 importer files.
- `CodexWatcher.AppServerClient`: 28 importer files.
- `CodexWatcher.Workflow.EventLog`: 7 importer files using the anchored scan,
  including replacement submodules; a stricter exact-facade scan found one
  unqualified exact facade import, while qualified facade users remain in
  `src/CodexWatcher/Daemon.hs` and `test/Main.hs`.
- `CodexWatcher.Workflow.Permission`: 2 anchored importer files, because the
  anchored pattern includes `src/CodexWatcher/Workflow/Permission.hs` importing
  `.Permission.Core`; the product facade is imported by `test/Main.hs`.

| Surface | Current package exposure | Preferred replacement import when known | Repo-local production imports | Repo-local test imports | Docs/package references | Available downstream references | Unavailable evidence | Blocked evidence | Unsupported-user decision | Cleanup blocker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `CodexWatcher.Core.Ids` | `moifold.cabal` exposes it. | Agent code: `CodexWatcher.Workflow.Agent.Ids`; GitHub code: `CodexWatcher.Workflow.GitHub.Ids`. | `observed`: broad source use remains across CLI, daemon, runtime, event-log, issue planning, issue implementation, PR review, state machine, and app entrypoint modules. Round 060 groups users into agent-only, GitHub-only, and mixed ownership. | `observed`: `test/AppServerSpec.hs`, `test/CliSpec.hs`, `test/GhGitSpec.hs`, `test/Main.hs`, and `test/RuntimeSpec.hs`. | `observed`: descriptors expose split owner modules in `agent-workflow-codex` and `agent-workflow-github`; docs keep `Core.Ids` as a moifold convenience facade and recommend split imports for reusable code. | `observed`: local package-consumer example imports split modules, not the moifold facade. No separate external downstream checkout is present. | `unavailable`: external downstream repositories and external operator import users are not present in this worktree. | `blocked_on_operator_approval`: public facade removal would need downstream compatibility evidence, behavior checks, and reviewer approval. | `no_decision_recorded`: no unsupported user decision for remaining `Core.Ids` importers was found. | 65 current importers, mixed agent/GitHub users, tests compiling through the facade, public docs describing it as available, and missing external downstream evidence. |
| `CodexWatcher.AppServerClient` | `moifold.cabal` exposes it. | `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`; protocol request mapping remains in adjacent Codex modules. | `observed`: 25 source/importer files in daemon, automatic loop, CLI, healthcheck, runner guard, failure, turn classifiers, PR review launch, issue planning loop, and workflow agent surfaces. Round 061 groups them by client/parser, transport/session, protocol/request, and product-policy ownership. | `observed`: `test/AppServerSpec.hs`, `test/CliSpec.hs`, and `test/Main.hs`. | `observed`: `agent-workflow-codex.cabal` exposes Client, Protocol, and Transport; policy docs keep `AppServerClient` as a moifold-owned compatibility facade. | `observed`: local package-consumer example imports `CodexWatcher.Workflow.Agent.Codex.Protocol`; no standalone package or example imports `CodexWatcher.AppServerClient`. | `unavailable`: external downstream checkouts and operator import inventories outside this repo are absent. | `blocked_on_operator_approval`: migration/removal needs behavior parity for request rendering, session sequencing, fallback behavior, and app-server startup expectations. | `no_decision_recorded`: no unsupported user decision for remaining `AppServerClient` importers was found. | 28 current importers, app-server behavior contracts, current public exposure, and missing external downstream evidence. |
| `CodexWatcher.Workflow.EventLog` | `moifold.cabal` exposes it; `agent-workflow-core.cabal` exposes `Workflow.Audit`, `Workflow.EventLog.Core`, `Workflow.EventLog.File.Core`, and `Workflow.EventLog.Commit.Core`. | Generic replay/audit users should prefer `CodexWatcher.Workflow.EventLog.Core`, `CodexWatcher.Workflow.EventLog.File.Core`, `CodexWatcher.Workflow.EventLog.Commit.Core`, and `CodexWatcher.Workflow.Audit` as applicable. | `observed`: product/facade use remains in `src/CodexWatcher/Daemon.hs` and `src/CodexWatcher/Workflow/DocsMigration.hs`; concrete file/replay wrappers remain moifold-owned. | `observed`: `test/Main.hs` imports the facade and replacement cores for golden replay, codec, file, commit, facade/core parity, DocsMigration, and audit tests. | `observed`: policy and package docs describe the core modules as preferred reusable imports while keeping the facade as deferred compatibility/product surface. | `observed`: local docs and package candidates reference replacement modules. No external downstream checkout is present. | `unavailable`: external downstream and operator repository evidence is absent. | `blocked_on_operator_approval`: old-log, golden replay, event schema, concrete `WatcherEvent`, audit/failure binding, and downstream evidence are required before cleanup. | `no_decision_recorded`: no unsupported user decision for remaining event-log facade users was found. | Current facade users, concrete moifold wrappers, event JSON `type` and schema contracts, golden replay obligations, public docs with `defer`, and missing external evidence. |
| `CodexWatcher.Workflow.Permission` | `moifold.cabal` exposes it; `agent-workflow-core.cabal` exposes `CodexWatcher.Workflow.Permission.Core`. | Reusable permission code should import `CodexWatcher.Workflow.Permission.Core`. | `observed`: source facade implementation bridges `.Permission.Core` to concrete moifold state-machine permission policy; no non-facade production caller imports the facade in the refreshed scan. | `observed`: `test/Main.hs` imports the facade and covers facade/core/state-machine parity. | `observed`: package docs and policy name `.Permission.Core` for reusable users while keeping `.Permission` as a concrete moifold bridge with `defer` status. | `observed`: local package docs reference the reusable core API. No external downstream checkout is present. | `unavailable`: external downstream/operator confirmation is absent. | `blocked_on_operator_approval`: any narrowing/removal needs public API, behavior parity, downstream-user, and reviewer approval. | `no_decision_recorded`: no unsupported user decision for remaining permission facade users was found. | Public exposure, concrete moifold bridge API, test facade import, and missing external downstream evidence. |

## Milestone-006 Runtime Path Inventory

The refreshed fixture/path search was:

```sh
find . -path './.git' -prune -o \( -name 'planning-state.json' -o -name 'repair-state.json' -o -name 'runtime-owner.json' -o -name 'daemon-state.json' -o -name 'watcher-state.json' -o -name 'checker-state.json' -o -name 'agent-state.json' -o -name 'reviewer-state.json' -o -name 'issue-state.json' -o -name 'block-state.json' -o -name 'issue-snapshot.json' -o -name '*pr-url*' -o -name '*pr-state*' \) -print | sort
```

It found checked-in fixtures for `issue-state.json`, one old-shape
`daemon-state.json`, PR review `watcher-state.json`/`checker-state.json`/
`agent-state.json`/`reviewer-state.json`, and one normal PR-review
`block-state.json`. It did not find checked-in `planning-state.json`,
`repair-state.json`, `runtime-owner.json`, live `issue-snapshot.json`, or
dedicated `*pr-url*`/`*pr-state*` files.

| Surface | Producer/writer | Reader | Healthcheck or non-healthcheck policy | Repair/restart behavior | Shell/operator consumer | Runbook/docs reference | Checked-in fixture or gap | Available downstream reference | Unavailable evidence | Blocked evidence | Unsupported-user decision | Cleanup blocker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `planning-state.json` | `observed`: `RecordPlanningGraph` planned writes and compatibility projection for `PlanningWaitingForReadyIssues`. | `observed`: no production Haskell reader found in round 064 evidence; tests assert write behavior. | `observed`: explicit non-healthcheck policy; issue-planning healthcheck reads `planner-state.json`, `daemon-state.json`, `block-state.json`, and `runtime-owner.json`, not `planning-state.json`. | `observed`: no repair/restart-specific consumer recorded. | `unavailable`: no shell/operator direct reader found. | `observed`: policy row keeps `defer` and names missing external/operator inventory. | `unavailable`: no checked-in fixture found. | `unavailable`: no external downstream direct-reader evidence in this worktree. | External downstream repos, operator approvals, and live archives are absent. | `blocked_on_operator_approval`: any healthcheck surfacing, schema, timing, or removal decision needs selected review. | `no_decision_recorded`. | Missing fixture, missing external direct-reader inventory, and no behavior-change approval. |
| `repair-state.json` | `observed`: `repair-invalid-state --execute` writes it after archiving invalid event log and writing repaired `events.jsonl`, before compatibility rewrite and stale `block-state.json` removal. | `observed`: no production Haskell reader found; command dispatch writes repair summary only. | `observed`: explicit non-healthcheck policy; current healthcheck file lists exclude it. | `observed`: repair summary is part of successful execute repair ordering; no restart cleanup path reads it. | `observed`: runbook instructs operators to run repair commands; no direct shell reader found. | `observed`: resume runbook and compatibility policy mention repair behavior/state. | `unavailable`: no checked-in `repair-state.json` fixture found. | `unavailable`: no external downstream direct-reader evidence in this worktree. | External downstream repos, live repair summaries, and operator approval records are absent. | `blocked_on_operator_approval`: fixture round-trip, production-reader expectation, and external/operator inventory are missing before cleanup. | `no_decision_recorded`. | Missing fixture, missing external direct-reader inventory, no healthcheck behavior approval, and protected repair ordering. |
| `runtime-owner.json` | `observed`: runtime owner store writes top-level `lease` JSON; CLI validate/renew/clear paths write or remove it. | `observed`: runtime owner store/CLI, automatic loop validation/renewal, PR-review launch reuse, healthcheck, and restart script read it. | `observed`: healthcheck reads `runtime-owner.json` for issue planning, issue implementation, and PR review under `runtimeOwner`; field-path mismatch remains evidence only. | `observed`: automatic loop validates before startup, renews before each tick, and clears current-process lease on exit; `scripts/restart-watcher` parses pid and removes file in cleanup. | `observed`: `scripts/restart-watcher` reads the first `"pid"` with `sed`, stops that pid, and removes the file during cleanup. | `observed`: preflight and operator checklist require absent/inactive lease; resume runbook documents `clear-runtime-lease`; policy classifies `keep`. | `unavailable`: no checked-in fixture found. | `observed`: repo-local runbooks/scripts are operator evidence; no external downstream checkout is present. | External operator scripts outside this repo and live state archives are absent. | `blocked_on_operator_approval`: schema, lease fields, healthcheck behavior, daemon ownership, and restart-script behavior require explicit approval. | `no_decision_recorded`. | Live daemon ownership state, healthcheck and script consumers, missing fixture, and missing external operator inventory. |
| `daemon-state.json` | `observed`: compatibility projection writes idle, active, and stopped daemon JSON for issue planning/implementation states and `StoppedState`; repair rewrites compatibility files when final replay state emits it. | `observed`: snapshot/golden replay reads optional issue-implementation daemon snapshot; healthcheck surfaces issue planning/implementation `daemonState`; restart script removes it. | `observed`: healthcheck reads it for issue planning and issue implementation, not PR review. | `observed`: repair rewrite may produce it; restart cleanup removes it with runtime-owner and block state. | `observed`: `scripts/restart-watcher` cleanup removes it. | `observed`: compatibility policy classifies `keep`; operator docs reference restart/resume behavior. | `observed`: one old-shape fixture at `golden/issue-implement/mlf2-issue42-incomplete/daemon-state.json`; current active/stopped fixtures are missing. | `observed`: repo-local script/docs only; no external direct-reader evidence. | External operator/downstream direct-reader evidence and live archives are absent. | `blocked_on_operator_approval`: active/stopped fixture coverage and external inventory are missing before cleanup. | `no_decision_recorded`. | Current projection and healthcheck contract, old-shape tolerance, restart cleanup behavior, missing current fixtures, and missing external evidence. |
| PR review state files: `watcher-state.json`, `checker-state.json`, `agent-state.json`, `reviewer-state.json` | `observed`: PR review compatibility projection writes `watcher-state.json`, `checker-state.json`, and `reviewer-state.json` for selected states; current projection does not produce `agent-state.json` but snapshot/healthcheck read it. | `observed`: PR review snapshot loader requires watcher state and optionally reads checker, agent, reviewer, and block state; healthcheck reads all four plus block and runtime owner. | `observed`: healthcheck reads these files under `SPrReview`; this is a current compatibility contract. | `observed`: restart supports `--domain pr-review` and removes runtime-owner, block, daemon, stale active turn, and pid files; it does not remove PR review state files. | `observed`: `init-pr-review-state.sh` creates PR review state dir, `events.jsonl`, `config.json`, dry-run and restart commands; `docker-setup-smoke.sh` exercises that path. | `observed`: PR review start/resume runbooks document `$PR_REVIEW_ROOT/<repo-slug>__pr<PR_NUMBER>`, command scripts, replay, restart, and checklist checks. | `observed`: golden PR-review fixtures for watcher/checker/reviewer/agent states exist. | `observed`: repo-local runbooks/scripts are operator evidence; no separate external downstream checkout is present. | Old live PR review archives and external direct-reader scripts are absent. | `blocked_on_operator_approval`: external path expectations and optional `agent-state.json` readback must be resolved before cleanup. | `no_decision_recorded`. | Current healthcheck/snapshot readers, golden fixtures, operator state-dir convention, optional legacy `agent-state.json`, and missing external inventory. |
| PR URL/state paths: `issue-state.json` `pr_url`, event/prompt `prUrl`, `pr-url`, `pr-state` | `observed`: `issue-state.json` writes `pr_url` when issue state has a PR; event logs contain `prUrl`; turn output and prompt templates render `prUrl`; no dedicated `*pr-url*` or `*pr-state*` producer found. | `observed`: issue snapshots decode optional `pr_url`; prompt/turn-output uses `prUrl` text; no dedicated PR URL file reader found. | `observed`: healthcheck reads issue/PR state files, not a dedicated PR URL file. | `observed`: PR review init/restart paths operate on state dir and command scripts, not dedicated `pr-url` or `pr-state` files. | `observed`: `init-pr-review-state.sh`, `docker-setup-smoke.sh`, and `scripts/restart-watcher` use PR review state-root conventions, not dedicated PR URL files. | `observed`: runbooks document `$PR_REVIEW_ROOT` state dirs and generated commands; they do not mention dedicated `pr-url` or `pr-state` files. | `observed`: issue-state fixtures and PR-review legacy config path fields exist; no checked-in `*pr-url*` or `*pr-state*` file found. | `unavailable`: no external operator/downstream proof that dedicated path absence is acceptable. | External old live-state archives and downstream/operator scripts outside the checkout are absent. | `blocked_on_operator_approval`: absent dedicated path wording remains `defer`; absence in repo is not proof no user expects it. | `no_decision_recorded`. | Need old live-state/archive and external operator evidence before concluding dedicated PR URL/state paths are unsupported. |
| `block-state.json` | `observed`: normal `RecordBlocked` planned writes, compatibility projection for terminal blocked state, and automatic-loop repair-failure writer for invalid replay. | `observed`: healthcheck reads blocked state for issue planning, issue implementation, and PR review; snapshot/golden replay reads optional block state. | `observed`: healthcheck surfaces `blocked` and `blockedReason` while preserving raw state. | `observed`: successful repair removes stale block state after compatibility rewrite; restart cleanup removes block state; `--drop-blocked-tail` can trim blocked-tail events before restart. | `observed`: `scripts/restart-watcher` removes it and can drop blocked-tail events; operator checklist says to check it after restart. | `observed`: resume runbook instructs backup before repair or blocked-tail drop; compatibility policy classifies `keep`. | `observed`: normal PR-review blocked fixture exists; no repair-failure block-state fixture found. | `observed`: repo-local runbooks/scripts only; no external downstream direct-reader evidence. | External operator scripts, live repair-failure state archives, and downstream direct readers are absent. | `blocked_on_operator_approval`: repair-failure fixture and external inventory are missing before cleanup. | `no_decision_recorded`. | Healthcheck/snapshot consumers, restart/repair behavior, normal fixture only, missing repair-failure fixture, and missing external evidence. |
| `issue-snapshot.json` | `observed`: execute-mode issue-planning loop writes it before planner turn start and skips planner turn when scoped tree is already complete. | `observed`: planner prompt instructs agent to read `issueSnapshotPath`; no healthcheck, repair, restart, snapshot replay, or golden replay reader found. | `observed`: explicit non-healthcheck/non-repair/non-restart/non-replay evidence; current healthcheck does not read it. | `observed`: repair/restart/replay scans found no consumer; write timing before planner turn is protected by tests. | `unavailable`: no shell script direct reader found; the planner agent instruction is the current consumer contract. | `observed`: turn-output and prompt templates render the path; policy classifies live snapshot as `defer`. | `unavailable`: no checked-in live `issue-snapshot.json` fixture found. | `unavailable`: no external operator/downstream direct-reader evidence in this worktree. | External live snapshots, downstream direct readers, and operator approval records are absent. | `blocked_on_operator_approval`: write timing, planner-turn behavior, fixture coverage, and direct-reader inventory are missing before cleanup. | `no_decision_recorded`. | Agent prompt contract, tested write timing, missing fixture, missing external inventory, and no migration/removal approval. |

## Shell And Operator Consumer Inventory

| Consumer | Status | Evidence |
| --- | --- | --- |
| `scripts/restart-watcher` | `observed` | Reads `$state_dir/runtime-owner.json` to extract pid, stops pid-file/default/runtime-owner pids, can drop blocked-tail events, removes `runtime-owner.json`, `block-state.json`, `daemon-state.json`, and `stale-active-turn.json`, then starts `restart-command.sh` unless `--no-start` is used. |
| `scripts/watcher-init/init-pr-review-state.sh` | `observed` | Requires `PR_REVIEW_ROOT`, creates `$PR_REVIEW_ROOT/<repo-slug>__pr<PR_NUMBER>`, writes `events.jsonl`, `config.json`, `dry-run-command.sh`, and `restart-command.sh` for `run-pr-review`. |
| `scripts/watcher-init/docker-setup-smoke.sh` | `observed` | Sets `PR_REVIEW_ROOT=$state_root/pr-review-watchers`, runs PR review initialization, validates generated command scripts with `bash -n`, and replays generated event logs. |
| `scripts/healthcheck*` | `unavailable` | No `scripts/healthcheck*` file was found by the script search. Healthcheck is exposed through the binary command and documented in runbooks/README. |
| `docs/watcher-agent-runbook/project-watch/01-preflight.md` | `observed` | Runs `healthcheck` and warns not to start execute loop over a running pid or active `runtime-owner.json` lease. |
| `docs/watcher-agent-runbook/project-watch/04-start-pr-review.md` | `observed` | Documents PR review state root convention, init script, generated dry-run/restart commands, and replay before execution. |
| `docs/watcher-agent-runbook/project-watch/05-resume-old-state.md` | `observed` | Documents replay, repair planning/execution, `clear-runtime-lease`, `scripts/restart-watcher`, and blocked-tail drop behavior. |
| `docs/watcher-agent-runbook/checklists/operator-checklist.md` | `observed` | Requires absent/inactive `runtime-owner.json`, backup before repair or blocked-tail drop, preference for `scripts/restart-watcher`, and checking `block-state.json` after restart. |
| `docs/watcher-agent-runbook/moifold-setup/*.md` | `observed` | Establishes the persistent container/app-server setup used by operator runbooks; no compatibility removal approval is recorded there. |

## Runbook And Docs Inventory

| Document | Status | Evidence |
| --- | --- | --- |
| `README.md` | `observed` | Publicly describes operator-grade automation, durable state, healthchecks, restart scripts, repair helpers, and resume runbooks. |
| `docs/watcher-agent-runbook/**` | `observed` | Provides the operator path for setup, preflight, state initialization, PR review startup, resume, repair, and restart. These docs are operator expectations, not removal approval. |
| `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` | `observed` | Keeps import facades available until later proof; classifies runtime files conservatively; requires external operator/runbook/script/downstream inventory before runtime deprecation, migration, or removal. |
| `docs/agentic-workflow-framework/publication-gate-decision.md` | `observed` | Records a deliberate publication hold and no explicit user/operator approval for externally visible package upload. It also keeps compatibility facades, compatibility files, healthcheck, repair, runtime ownership, and release approval moifold-owned. |
| `docs/agentic-workflow-framework/release-notes.md` and release-candidate docs | `observed` | Describe future release-gate material only; they do not authorize package upload, facade removal, or runtime compatibility behavior changes. |

## Downstream, Unavailable, And Blocked Evidence

Available repo-local downstream/package evidence:

- `observed`: package descriptors expose replacement reusable modules in
  `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
- `observed`: `examples/workflow-package-consumer` uses package-facing
  replacement modules rather than the selected moifold facades where scanned.
- `observed`: local package docs and compatibility policy recommend preferred
  imports while keeping moifold compatibility facades available.
- `observed`: runbooks and scripts are repo-local operator evidence for
  runtime paths.

Unavailable evidence:

- `unavailable`: no separate external downstream repository checkout was
  present in this worktree.
- `unavailable`: no live state archive was present for old/current runtime
  compatibility files outside checked-in golden fixtures.
- `unavailable`: no external operator script inventory outside repo-local
  scripts and runbooks was present.
- `unavailable`: no hosted CI, package upload, tag, GitHub release, or release
  announcement evidence was present for this round.

Blocked evidence:

- `blocked_on_operator_approval`: publication docs record no explicit
  user/operator approval for package upload.
- `blocked_on_operator_approval`: removal gates require reviewer approval that
  names exact surfaces and confirms all applicable import, behavior, old-log,
  golden, repair, healthcheck, fixture, write-timing, script, runbook, and
  downstream gates.
- `blocked_on_operator_approval`: unsupported-user decisions would require an
  explicit future approval artifact; this round does not create one.

## Unsupported-User Decisions

No explicit unsupported-user decision was found in this worktree for any
remaining public import user, runtime compatibility-file reader, script
consumer, runbook consumer, or downstream user of the surfaces inventoried
here.

Every surface in this artifact is therefore classified as
`no_decision_recorded` for unsupported-user decisions. Future rounds must not
infer unsupported-user status from local absence. They need an explicit
operator/reviewer/release-gate decision or concrete downstream evidence.

## Per-Surface Blockers

| Surface | Current conservative blocker |
| --- | --- |
| `CodexWatcher.Core.Ids` | 65 current importers, mixed agent/GitHub users, facade tests, docs saying it remains available, and unavailable external downstream evidence. |
| `CodexWatcher.AppServerClient` | 28 current importers, app-server request/session/failure behavior, public exposure, and unavailable external downstream evidence. |
| `CodexWatcher.Workflow.EventLog` | Current facade users, concrete moifold helpers, event schema/golden replay contracts, and unavailable external downstream/operator evidence. |
| `CodexWatcher.Workflow.Permission` | Public exposure, concrete moifold bridge API, test facade import, and unavailable external downstream evidence. |
| `planning-state.json` | No checked-in fixture, explicit non-healthcheck status, missing external direct-reader inventory, and no healthcheck/write/schema approval. |
| `repair-state.json` | No checked-in fixture, no production reader decision, protected repair ordering, explicit non-healthcheck status, and missing external direct-reader inventory. |
| `runtime-owner.json` | Live daemon ownership state, CLI/automatic-loop/healthcheck/restart consumers, no checked-in fixture, and missing external operator script inventory. |
| `daemon-state.json` | Healthcheck/snapshot/restart/repair evidence, only old-shape fixture, missing current active/stopped fixtures, and missing external inventory. |
| PR review state files | Current snapshot/healthcheck consumers, golden fixtures, generated PR-review state-dir convention, optional legacy `agent-state.json`, and missing external path expectations. |
| PR URL/state paths | `issue-state.json` `pr_url` and `prUrl` prompt/event fields are observed; dedicated `*pr-url*`/`*pr-state*` absence is local-only and blocked on old live-state/external evidence. |
| `block-state.json` | Healthcheck/snapshot/restart/repair consumers, normal blocked fixture only, missing repair-failure fixture, and missing external direct-reader inventory. |
| `issue-snapshot.json` | Planner prompt contract and tested write timing, but no checked-in live fixture, no external direct-reader inventory, and no write-timing/planner-turn migration approval. |

## Conservative Conclusion

Milestone 007 can complete the requested inventory by recording observed
repo-local evidence, unavailable external evidence, blocked operator/reviewer
evidence, and unsupported-user decision gaps.

It does not approve any public import facade or runtime compatibility path for
deprecation, migration, removal, package publication, upload, release, Cabal
exposure changes, production import rewrites, schema or filename changes,
event-type changes, write-timing changes, planner-turn changes, projection
changes, healthcheck changes, repair changes, replay changes, restart-script
changes, or operator behavior changes.

Every inventoried surface remains blocked from cleanup by at least one current
repo-local user, behavior contract, fixture gap, unavailable external
downstream/operator source, missing unsupported-user decision, or missing
operator/reviewer approval artifact.
