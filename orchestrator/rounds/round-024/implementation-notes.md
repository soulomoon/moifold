### Changes Made
- `src/CodexWatcher/Cli/Command/IssueFanout.hs`: exported the pure launch manifest and child command render helpers so the watcher-core suite can assert IssueImplement child lifecycle compatibility without spawning child daemons.
- `test/Main.hs`: added focused lifecycle coverage for IssueImplement child launch manifests, compatibility facade paths, dry-run child command rendering, launch write ordering, child-start status classification, IssueImplement terminal runtime status gating, repair CLI dry-run/apply sequencing, and package-boundary source scans.
- `test/HealthcheckSpec.hs`: added IssueImplement lifecycle healthcheck analysis coverage for terminal complete daemon requirements, stopped non-terminal warnings, duplicate active implementer detection, dirty stopped workdir warnings, active implementer summary counting, and read-only logic-review text.

### Tests
- `test/Main.hs`: verifies launch manifests and command shape, append-before-compatibility ordering, pending/finalized manifest sequencing, completed-before-ready classification, issue-close-gated terminal runtime status, deterministic repair CLI mutation order, and workflow package-boundary lifecycle scans.
- `test/HealthcheckSpec.hs`: verifies issue-implement lifecycle healthcheck reporting and cross-item duplicate detection.
- `cabal test watcher-core-test`: passed.
- Explicit source scans:
  - `rg -n "ChildDaemon|WatcherRuntimeStatus|Healthcheck|EventLogRepair|IssueFanout|IssuePlanningFanout|runtime-owner|issue-watcher\\.pid|\\.lock|IssueConfig|WatcherEvent|SomeWatcherState" agent-workflow-core/src`: no matches.
  - `rg -n "CodexWatcher.Workflow.Moifold.IssueImplement.Indexed|projectIssueImplement|IssueImplementIndexedSpec" src/CodexWatcher/Domain/IssueImplement src/CodexWatcher/DaemonLoop src/CodexWatcher/AutomaticLoop`: no matches.
  - `rg -n "reexported-modules|CodexWatcher.Workflow.Agent|CodexWatcher.Workflow.GitHub" moifold.cabal`: matches only adapter sublibrary exposed modules, not main-library reexports.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no changes were staged.

### Notes
No event schemas, golden logs, daemon result constructors, dry-run wording, action ordering, request-id progression, runtime command rendering, compatibility write timing, compatibility file names, or package boundaries were intentionally changed. The implementation stayed in the round worktree and did not edit `orchestrator/state.json`.
