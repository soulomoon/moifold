### Scope And Non-Goals

This round records current evidence for `runtime-owner.json` only:

- runtime owner store/schema readback;
- runtime owner CLI behavior;
- read sites and automatic-loop timing;
- healthcheck behavior and field-path evidence;
- `scripts/restart-watcher` operator-script inventory;
- operator runbook and policy inventory;
- checked-in fixture evidence or fixture gap;
- existing behavior/source assertion coverage;
- current classification and conservative blockers.

This is evidence only. It does not authorize or perform filename, schema,
lease-field, daemon ownership, healthcheck, repair, restart-script, migration,
deprecation, removal, package publication, upload, release, source, test,
fixture, docs, roadmap, project-contract, or controller-state changes.

`runtime-owner.json` remains live daemon ownership state.

### Store And Schema Readback

Source readback:

- `src/CodexWatcher/Runtime/Owner/Store.hs` writes the file at
  `<stateDir>/runtime-owner.json` through `writeRuntimeLease`.
- `runtimeLeaseJson` writes a top-level `lease` object.
- The current accepted lease fields are:
  - `lease.runtime`
  - `lease.pid`
  - `lease.hostname`
  - `lease.claimedAt`
  - `lease.expiresAt`
  - `lease.eventLogHeadHash`
- `readRuntimeOwnerMarker` reads `<stateDir>/runtime-owner.json`.
- `runtimeOwnerMarkerFromJson` accepts `Null` as no marker and accepts JSON
  objects only when they contain a top-level `lease` object.
- `runtimeLeaseFromJson` parses the lease object and requires the six fields
  listed above.
- `readRuntimeOwner` reduces a valid leased marker to the lease owner.

Current parser behavior rejects older shapes that do not match this schema:

- owner-only JSON is rejected because an object without a top-level `lease`
  fails with `runtime owner marker must contain a lease object`;
- top-level owner-plus-lease JSON without `lease.runtime` is rejected because
  the lease parser requires `runtime` inside the `lease` object.

`src/CodexWatcher/Runtime/Owner/Types.hs` currently supports only the
`HaskellRuntime` owner, rendered as `haskell`; `parseRuntimeOwner` accepts
case-insensitive, trimmed `haskell` and rejects other owner text.

### Runtime Owner CLI Readback

Source readback from `src/CodexWatcher/Runtime/Owner/Cli.hs`:

- `validateRuntimeOwnerForExecution` is a no-op in dry-run mode.
- In execute mode, validation reads the marker, refuses execution when a valid
  lease is held by a running non-current pid, and writes a fresh Haskell lease
  when the marker is absent or not blocking takeover.
- `renewRuntimeOwnerForExecution` is a no-op in dry-run mode and writes a fresh
  Haskell lease in execute mode.
- `clearRuntimeLease` reads the marker, rejects clearing a running lease, then
  removes `runtime-owner.json` when the marker is absent or clearable.
- `clearRuntimeLeaseIfOwnedByCurrentProcess` is a no-op in dry-run mode. In
  execute mode, it removes the file only when the marker is a Haskell lease
  whose pid is the current process pid.
- Fresh leases include the current process pid, host from `HOSTNAME` or
  `unknown-host`, current timestamps, one-hour expiry, and an event-log head
  hash from `<stateDir>/events.jsonl`.
- If `events.jsonl` is absent, the fresh lease records
  `eventLogHeadHash = "missing"`; otherwise the hash includes the byte length
  and a deterministic fold over the event-log bytes.

No new lease migration or clear policy is selected by this round.

### Read Sites And Automatic-Loop Timing

Focused source scans found these current production readers or validators:

- `src/CodexWatcher/Runtime/Owner/Store.hs`: canonical marker reader and owner
  projection.
- `src/CodexWatcher/Runtime/Owner/Cli.hs`: validate, renew, clear, and
  current-process cleanup operations.
- `src/CodexWatcher/AutomaticLoop/Runner.hs`: validates ownership before loop
  startup, renews before each loop iteration, and clears only the current
  process lease on exit.
- `src/CodexWatcher/Cli/Command/Observe.hs`: validates ownership before an
  execute-mode observed daemon tick.
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`: reads the marker to detect
  a live PR-review runtime owner pid, repairs the watcher pid file to that pid
  when it is still running, and avoids starting a duplicate child watcher.
- `src/CodexWatcher/Healthcheck.hs`: reads `runtime-owner.json` into the
  healthcheck state summary.
- `app/Main.hs` exposes `clear-runtime-lease` through `clearRuntimeLease`.

Automatic-loop timing in `src/CodexWatcher/AutomaticLoop/Runner.hs` is:

- validate the runtime owner before startup and before creating the loop
  logger;
- run the loop under `runWithOptionalPidFile`;
- clear only the current-process lease in `finally`;
- before each loop tick, renew the runtime owner lease;
- after renewal, repair the current pid file with the current process pid;
- after pid-file repair, reconcile compatibility state from event-log replay;
- then run one daemon loop tick.

This timing is recorded as current behavior only. No timing migration is
authorized.

### Healthcheck Behavior And Field-Path Evidence

Source readback from `src/CodexWatcher/Healthcheck.hs`:

- `readStateFiles` reads the files named by `stateFileSpecs`.
- `sharedStateFiles` includes `("runtimeOwner", "runtime-owner.json")`.
- `SIssuePlanning` healthcheck reads `planner-state.json` plus shared
  `daemon-state.json`, `block-state.json`, and `runtime-owner.json`.
- `SIssueImplement` healthcheck reads `issue-state.json` plus shared
  `daemon-state.json`, `block-state.json`, and `runtime-owner.json`.
- `SPrReview` healthcheck reads `watcher-state.json`, `checker-state.json`,
  `agent-state.json`, `reviewer-state.json`, `block-state.json`, and
  `runtime-owner.json`.
- The summary field is `runtimeOwner`.
- Summary extraction uses configured `config.runtimeOwner` if present, or
  `lookupStateText ["runtimeOwner", "owner"] states`.

Current field-path evidence:

- the writer emits the owner at `runtimeOwner.lease.runtime` inside healthcheck
  `states`;
- the summary fallback looks at `runtimeOwner.owner`;
- therefore the current fallback path does not match the current writer path.

This mismatch is evidence only. This round does not authorize a healthcheck
behavior change, compatibility projection change, or schema change.

### Operator Script Inventory

`scripts/restart-watcher` currently treats `runtime-owner.json` as operator
state:

- `read_runtime_owner_pid` reads `$state_dir/runtime-owner.json`;
- it uses shell `sed` to extract the first numeric JSON `"pid"` string;
- `pid_from_owner=$(read_runtime_owner_pid)` adds that pid to the stop list;
- restart stops the explicit pid file pid, the default pid file pid, and the
  runtime-owner pid;
- `cleanup_state` removes `$state_dir/runtime-owner.json` along with pid files,
  `block-state.json`, `daemon-state.json`, and `stale-active-turn.json`;
- the script then either exits after cleanup when `--no-start` is set or starts
  the watcher from `restart-command.sh`.

This is operator-script evidence only. This round does not authorize changing
`scripts/restart-watcher`, its pid extraction, or its cleanup list.

### Operator Runbook And Policy Inventory

Repo-local runbook and policy references found by focused scans:

- `docs/watcher-agent-runbook/project-watch/01-preflight.md` treats an active
  `runtime-owner.json` lease as an operator gate: never start
  `--execute --loop` over a running pid or active lease.
- `docs/watcher-agent-runbook/checklists/operator-checklist.md` requires
  `runtime-owner.json` to be absent or owned by an inactive pid before starting
  a project watcher.
- `docs/watcher-agent-runbook/project-watch/05-resume-old-state.md` documents
  `clear-runtime-lease --state-dir "$STATE_DIR"` when no pid is running but an
  inactive lease remains, and prefers `scripts/restart-watcher` for resume.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  classifies `runtime-owner.json` as `keep`, citing runtime owner store and CLI
  producers/readers, automatic-loop validation and renewal, healthcheck
  surfacing, `scripts/restart-watcher` shell parsing/removal, and protecting
  tests.
- The same policy row keeps missing gates visible: checked-in fixture coverage,
  healthcheck field-path mismatch resolution or explicit policy, and external
  operator/downstream script inventory.

The runbook and policy inventory supports the current `keep` classification.
It does not approve migration, deprecation, removal, public release, or package
publication.

### Fixture Evidence Or Fixture Gap

Required fixture search:

```sh
find . -path './.git' -prune -o -name 'runtime-owner.json' -print
```

Result: no output.

There is no checked-in `runtime-owner.json` fixture in this worktree. Existing
tests create temporary runtime owner files, but those are behavior assertions,
not checked-in old/current state-file fixtures.

### Existing Behavior And Source Assertion Coverage

Existing tests and assertions in `test/Main.hs` cover the current behavior
without providing checked-in fixture round trips:

- `prop_runtimeOwnerJsonAndParsing` checks accepted owner text, rejected owner
  text, absence of top-level `owner`, and current `lease.runtime = "haskell"`.
- `runtimeOwnerLeaseParsingRejectsOwnerOnlyJson` writes temporary
  `runtime-owner.json` shapes and asserts owner-only JSON and old top-level
  owner-plus-lease JSON are rejected, while current lease-only marker JSON
  parses.
- `runtimeOwnerClearRejectsRunningLease` asserts `clearRuntimeLease` rejects a
  lease whose pid is running.
- `runtimeOwnerCleanupClearsOnlyCurrentProcessLease` asserts execute cleanup
  clears the current-process lease, preserves another pid's lease, and is a
  no-op in dry-run mode.
- `restoreOwnedPidFileRepairsMissingAndStalePid` covers the pid-file repair
  behavior used by automatic-loop renewal and PR-review runtime-owner reuse.

Additional scan evidence:

- `test/HealthcheckSpec.hs` has healthcheck summary assertions for configured
  `runtimeOwner` values.
- The selected `test/Main.hs` range does not contain a checked-in fixture
  round-trip for `runtime-owner.json`.

### Current Classification

Classification: `keep`.

Reasons:

- the file is live daemon ownership state;
- runtime owner CLI reads, validates, renews, clears, and removes it;
- automatic loops validate and renew it as part of execute-mode ownership;
- PR-review launch uses it to detect and reuse live child watcher ownership;
- healthcheck reads it for issue planning, issue implementation, and PR review;
- `scripts/restart-watcher` parses and removes it as operator state;
- runbooks treat it as an active operator gate;
- policy already records it as `keep`.

### Conservative Blockers

Before any later cleanup, migration, deprecation, removal, schema, lease-field,
healthcheck, daemon ownership, restart-script, package, publication, upload, or
release decision, the following blockers remain:

- no checked-in `runtime-owner.json` fixture exists;
- no checked-in old/current fixture round-trip coverage exists for the current
  lease shape and intentionally rejected old shapes;
- healthcheck summary fallback still uses `runtimeOwner.owner` while the writer
  emits `runtimeOwner.lease.runtime`, unless a later selected round records an
  explicit reviewed policy for that mismatch;
- external operator/downstream script inventory remains limited to repo-local
  docs and scripts;
- no selected direction authorizes filename changes;
- no selected direction authorizes schema or lease-field migration;
- no selected direction authorizes daemon ownership behavior changes;
- no selected direction authorizes healthcheck behavior changes;
- no selected direction authorizes `scripts/restart-watcher` behavior changes;
- no selected direction authorizes migration, deprecation, removal,
  publication, upload, or release approval.
