# Downstream Runtime-State Migration Contract

Date: 2026-05-14

This contract is the supported read-only migration path for downstream tools
that currently inspect moifold runtime state files directly. Use:

```bash
moifold healthcheck --state-root /workspace/artifacts --repo owner/name
```

The command is read-only. It reports each watcher under `watchers[]` with a
`kind` discriminator and a `states` object that preserves the legacy runtime
state projection under stable keys. Current moifold healthcheck derives the
compatibility-state entries from event replay instead of reading those JSON
files directly; `runtime-owner.json` remains a separate product lease file.

## State-File Mapping

| Runtime file | `healthcheck` JSON path | Current status |
| --- | --- | --- |
| issue planner `daemon-state.json` | `watchers[].states.daemonState` where `kind == "issue-planning"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| issue planner `planner-state.json` | `watchers[].states.plannerState` where `kind == "issue-planning"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| issue planner `block-state.json` | `watchers[].states.blockedState` where `kind == "issue-planning"` | Replacement read path available; normal and repair-failure local file writers removed, with downstream migration still pending. |
| issue implementer `daemon-state.json` | `watchers[].states.daemonState` where `kind == "issue-implement"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| issue implementer `issue-state.json` | `watchers[].states.issueState` where `kind == "issue-implement"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| issue implementer `block-state.json` | `watchers[].states.blockedState` where `kind == "issue-implement"` | Replacement read path available; normal and repair-failure local file writers removed, with downstream migration still pending. |
| PR review `watcher-state.json` | `watchers[].states.watcherState` where `kind == "pr-review"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| PR review `checker-state.json` | `watchers[].states.checkerState` where `kind == "pr-review"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| PR review `agent-state.json` | `watchers[].states.agentState` where `kind == "pr-review"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| PR review `reviewer-state.json` | `watchers[].states.reviewerState` where `kind == "pr-review"` | Replacement read path available; normal local file writer removed, with downstream migration still pending. |
| PR review `block-state.json` | `watchers[].states.blockedState` where `kind == "pr-review"` | Replacement read path available; normal and repair-failure local file writers removed, with downstream migration still pending. |

## Downstream Inventory

The 2026-05-14 owner-scoped search found direct readers in
`soulomoon/pr-review-watcher-tool`:

- `watcher-healthcheck.mjs` reads planner, issue implementer, and PR review
  state files only for read-only health reporting. This can migrate to
  `moifold healthcheck`.
- `issue-planning-control.mjs`, `issue-implement-control.mjs`, and
  `pr-review-control.mjs` read state files for their legacy `status` or
  `doctor` commands. These read-only commands can migrate to `moifold
  healthcheck`.
- `issue-planning-watcher.mjs`, `issue-implement-watcher.mjs`, and
  `pr-review-watcher.mjs` are not passive readers. They produce, read, and
  coordinate through the same runtime files in the legacy Node runtime. A
  downstream migration must either retire those daemon bodies in favor of the
  Haskell `moifold run-*` loops or explicitly retain the files as product
  contracts.

## Read-Only Migration Patch

The direct cleanup pass implemented the read-only side in the downstream audit
checkout at `/tmp/pr-review-watcher-tool-audit`:

- `script-utils.mjs` now has a `moifold healthcheck` JSON adapter and watcher
  lookup helpers.
- `issue-planning-control.mjs status` reads `daemonState`, `plannerState`, and
  `blockedState` from the Haskell healthcheck report.
- `issue-implement-control.mjs status` reads `daemonState`, `issueState`, and
  `blockedState` from the Haskell healthcheck report.
- `pr-review-control.mjs status` and `doctor` read PR review state projections
  from the Haskell healthcheck report.
- `watcher-healthcheck.mjs` keeps its extra whole-system checks, but obtains
  runtime state through the Haskell healthcheck projection instead of direct
  state-file reads.

Validation in that downstream checkout:

```bash
npm run check
```

Additional smoke tests used a fake `moifold` binary and temporary watcher
config roots to prove the migrated status and healthcheck paths consume
`watchers[].states.*` from the Haskell report.

## Daemon Migration Patch

The same downstream audit checkout also replaces the legacy Node daemon bodies
with compatibility launchers:

- `issue-planning-watcher.mjs` initializes a Haskell
  `issue_planning_initialized` event when the event log is missing or empty,
  then delegates to `moifold run-issue-planning --execute --loop`.
- `issue-implement-watcher.mjs` initializes an
  `issue_implement_initialized` event when the event log is missing or empty,
  then delegates to `moifold run-issue-implement --execute --loop`.
- `pr-review-watcher.mjs` initializes a `pr_review_initialized` event when the
  event log is missing or empty, then delegates to
  `moifold run-pr-review --execute --loop`.
- `script-utils.mjs` owns the shared launcher, endpoint, polling, and
  initial-event helpers.

The launchers pass config-derived `--repo`, `--issue` or `--pr`,
`--state-dir`, `--events`, `--workdir`, `--pid-file`, app-server endpoint, and
polling arguments to the Haskell runtime. This removes direct runtime
state-file reads and writes from the patched downstream daemon scripts; the
Haskell moifold runtime remains the producer of current compatibility files.

Validation in the downstream audit checkout:

```bash
npm run check
```

Additional smoke tests used a fake `moifold` binary and temporary watcher
config roots to prove all three daemon launchers create their initial event
logs and pass the expected `moifold run-*` commands. The generated event logs
were then replayed by the current Haskell binary:

```bash
moifold replay-events /tmp/planner-events.jsonl
moifold replay-events /tmp/impl-events.jsonl
moifold replay-events /tmp/review-events.jsonl
```

The replay output accepted the initialized domains for issue planning, issue
implementation, and PR review.

## Cleanup Rule

Do not remove, rename, or change the meaning of these runtime files merely
because the local downstream audit patch can replace read-only status checks
and daemon bodies. Runtime-file removal requires the downstream patch to be
accepted by the downstream owner or explicitly retained by that owner. Local
moifold producers, healthcheck, checked-in snapshots, and operator restart
runbooks have already migrated off direct stale compatibility-file dependence.
Healthcheck now projects the stable `watchers[].states.*` shape from event
replay.
