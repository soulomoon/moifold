### Goal

Harden the remaining IssueImplement lifecycle surfaces after the live daemon observation routes have moved through the indexed IssueImplement projection. The round should make child launch, restart/completion detection, runtime status, healthcheck, event-log repair, dry-run launch output, and compatibility facade availability explicit and covered by focused tests, while preserving moifold ownership of process lifecycle, state directories, runtime-owner/PID/lock files, `issue-state.json`, `events.jsonl`, repair drop behavior, terminal success detection, and issue-planning fanout boundaries.

### Approach

Keep this as a sequential lifecycle-hardening round. The target surfaces share state-dir, event-log, PID, and compatibility-write invariants, and roadmap item `item-024-indexed-issue-implementation-lifecycle-hardening` is not parallel-safe.

Treat `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed` as the policy projection boundary only. Do not move child process lifecycle, fanout planning, runtime ownership, healthcheck inventory, repair behavior, GitHub issue-close checks, PID/lock handling, or compatibility file writes into `agent-workflow-core` or any adapter package.

Audit and patch only the concrete lifecycle modules involved:

- `src/CodexWatcher/Cli/Command/IssueFanout.hs` for child launch manifests, dry-run launch rendering, launch pending/finalized writes, restart start results, completed-before-ready handling, and runtime status classification.
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs` for ready-issue reconciliation, stale/completed child detection, restart decisions, terminal ready-issue completion, and planner ready-issues-fixed behavior.
- `src/CodexWatcher/WatcherRuntimeStatus.hs` for config/events/PID replay classification and terminal success detection.
- `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Healthcheck/Analysis.hs`, and `src/CodexWatcher/Healthcheck/Types.hs` for issue-implementer reporting without mutating state.
- `src/CodexWatcher/EventLogRepair.hs` and `src/CodexWatcher/Cli/Command/Replay.hs` for deterministic repair plans, repair dry-run/apply summaries, compatibility rewrite behavior, and block-state removal.
- `src/CodexWatcher/Runtime/Compatibility.hs` only if tests expose a compatibility facade gap; preserve existing compatibility file names and JSON field meanings.

Do not change event `type` fields, event JSON schemas, golden fixtures, daemon result constructors, dry-run wording, action ordering, request-id progression, runtime command rendering, compatibility write timing, public compatibility module availability, or package boundaries unless the implementation adds a paired parity test proving the output is byte-for-byte or structurally unchanged where appropriate.

### Steps

1. Add focused source-scan guards before or alongside behavior changes:
   - `agent-workflow-core/src` must not import or mention `CodexWatcher.ChildDaemon`, `CodexWatcher.WatcherRuntimeStatus`, `CodexWatcher.Healthcheck`, `CodexWatcher.EventLogRepair`, `CodexWatcher.Cli.Command.IssueFanout`, `CodexWatcher.AutomaticLoop.IssuePlanningFanout`, `IssueConfig`, concrete `WatcherEvent`, concrete `SomeWatcherState`, runtime-owner files, PID files, or lock handling.
   - IssueImplement lifecycle modules must not import `agent-workflow-core` directly for process ownership decisions beyond existing indexed projection/facade APIs.
   - `src/CodexWatcher/Daemon.hs` must continue to be the only live IssueImplement daemon projection router, while lifecycle modules remain moifold-owned.
   - The main moifold library must keep the existing compatibility facade modules available and must not reexport adapter-only modules.

2. Add or strengthen focused tests around child launch planning and manifests in `test/Main.hs`:
   - A launch plan still writes `config.json`, appends the `IssueImplementInitialized` event to `events.jsonl`, and writes the same `issue-state.json`/`daemon-state.json` compatibility files.
   - Pending and finalized manifest JSON preserve `status`, `launchKind`, `repo`, `issueNumber`, `workdir`, `stateDir`, `configPath`, `eventsPath`, `intendedThreadRoles`, `threadId`, and `childLaunch`.
   - Dry-run fanout prints the existing launch summary and child command shape, including `run-issue-implement`, `--events`, `--state-dir`, `--repo`, `--workdir`, app-server host/port/path when non-root, `--poll-seconds`, `--execute`, `--loop`, and `--pid-file`, without writing state.

3. Harden runtime status and child start behavior with tests first:
   - Missing config and missing events stay `WatcherMissing` unless the remote issue-closed terminal check says the issue is terminal complete.
   - Existing config/events with a running PID are `WatcherActiveRunning`.
   - Stopped or blocked terminal replay is not treated as successful completion for ready-issue fanout; it remains restartable/stopped.
   - `CompleteState (IssueComplete pr)` is treated as terminal complete only when the issue-close verifier succeeds.
   - `startIssueImplementerChildDetailed` treats `WatcherTerminal TerminalComplete` after launch as `IssueImplementerChildCompletedBeforeReady`, treats running as started, and reports all other post-launch statuses as start problems.

4. Harden issue-planning fanout lifecycle decisions without changing issue-planning ownership:
   - Preserve `resolveFanoutActiveIssues` as running-only discovery unless explicit `--active-issues` is supplied.
   - Ensure stopped implementers are restarted, missing implementers are launched subject to `maxParallel`, terminal completed ready issues are not recreated, and closed ready issues trigger the existing ready-issues-fixed path.
   - Keep validation blocking for ready issues outside planner scope, already running issues, and already terminal-complete issues.
   - Preserve append-before-compatibility ordering when marking planner ready issues fixed or blocking fanout.

5. Harden healthcheck issue-implement reporting:
   - Surface `runtime-owner.json` and configured `runtimeOwner` without using it to mutate or claim ownership.
   - Keep PID reports tied to the domain default `issue-watcher.pid` unless `config.json` supplies `pidPath`.
   - Keep `issue-state.json`, `daemon-state.json`, `block-state.json`, and `runtime-owner.json` in the issue-implement summary.
   - Add tests for terminal complete implementers not requiring a daemon, stopped non-terminal implementers warning, duplicate active implementer detection, dirty stopped workdir warning, and read-only logic-review text.

6. Harden deterministic repair coverage:
   - Add tests for stale `IssuePlanningReadyIssuesFixed` repair dropping only that stale marker.
   - Add tests for missing-plan-before-PR repair and completion-without-implementation-turn repair preserving safe suffix events while dropping unsafe completion events exactly as today.
   - Verify dry-run repair reports strategy, failed event index, inserted count, dropped count, and repaired phase without rewriting `events.jsonl`.
   - Verify execute repair archives the old event log, writes repaired `events.jsonl`, writes `repair-state.json`, rewrites compatibility files from the repaired replay state, and removes stale `block-state.json`.

7. If the audit finds dead compatibility-only IssueImplement routing code after the above coverage is in place, remove only code that is provably unreachable. Any removal must have tests proving event schema, daemon result shape, dry-run rendering, compatibility writes, and lifecycle behavior remain unchanged. If this proof is not narrow and local, leave the code in place.

8. Update or add focused test names in the watcher-core suite so reviewers can run a narrow matcher for:
   - IssueImplement child launch lifecycle and manifests.
   - Watcher runtime status terminal success detection.
   - IssuePlanning ready-issue fanout lifecycle decisions.
   - Healthcheck issue-implement lifecycle reporting.
   - IssueImplement event-log repair behavior.
   - Workflow package-boundary lifecycle source scans.

### Verification

Run the focused tests added or changed for this round first, using exact watcher-core matchers once the test names exist. The focused set must cover child launch manifests/dry-run output, runtime status terminal success detection, ready-issue fanout restart/completion decisions, healthcheck issue-implement lifecycle reporting, deterministic repair drop behavior, and package-boundary source scans.

Then run the roadmap baseline:

1. `cabal test watcher-core-test`
2. `cabal build all`
3. `git diff --check`
4. `git diff --cached --check` only if the implementation stages changes

Also perform explicit source scans:

1. `rg -n "ChildDaemon|WatcherRuntimeStatus|Healthcheck|EventLogRepair|IssueFanout|IssuePlanningFanout|runtime-owner|issue-watcher\\.pid|\\.lock|IssueConfig|WatcherEvent|SomeWatcherState" agent-workflow-core/src`
2. `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`
3. `rg -n "reexported-modules|CodexWatcher.Workflow.Agent|CodexWatcher.Workflow.GitHub" moifold.cabal`

Expected source-scan outcome: the first scan has no lifecycle ownership leaks in `agent-workflow-core`; the second scan shows no live daemon projection routing outside `src/CodexWatcher/Daemon.hs`; the third scan preserves the no-adapter-reexport rule while keeping compatibility facade modules available through the main moifold library.

### Worker Fan-Out

Do not use worker fan-out for this round. The roadmap marks the item as parallel unsafe, and the hardening surface crosses shared state-dir, event-log, PID/lock, compatibility-write, healthcheck, repair, and fanout invariants. No `worker-plan.json` was created.
