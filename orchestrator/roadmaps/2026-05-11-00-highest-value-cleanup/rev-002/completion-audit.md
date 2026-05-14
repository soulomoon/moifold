# Completion Audit: Highest-Value Cleanup Rev 002

Date: 2026-05-14

Objective: implement the remaining cleanup items in
`orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-002/roadmap.md`
without subagents.

## Checklist

| Requirement | Evidence | Status |
| --- | --- | --- |
| Work without subagents | No subagent delegation was used for the direct cleanup and audit pass. | complete |
| Remove remaining public import wrappers when gates are satisfied | `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission` were removed from source and `moifold.cabal`; direct import scans over `src`, `app`, `test`, and package candidates return no removed-wrapper imports. | complete |
| Preserve behavior after public-wrapper removal | `cabal build all` and `cabal test watcher-core-test` passed after wrapper removal and test/doc/policy updates. | complete |
| Finish EventLog and Permission bridge burndown | `test/FacadeImportPolicySpec.hs` now imports `CodexWatcher.Workflow.EventLog.Core` and `CodexWatcher.Workflow.Permission.Core` directly; removed-wrapper scans return no `CodexWatcher.Workflow.EventLog` or `CodexWatcher.Workflow.Permission` imports. | complete |
| Finish AppServerClient public-surface cleanup | `CodexWatcher.AppServerClient` no longer exists as a source module or exposed module; docs/policy point at `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`. | complete |
| Split selected large runtime modules without behavior changes | Extracted `CodexWatcher.Daemon.Types`, `CodexWatcher.TurnOutput.Schema`, `CodexWatcher.Workflow.Moifold.IssueImplement.Indexed.Types`, `CodexWatcher.Workflow.DocsMigration.Types`, and `CodexWatcher.EventLog.Types.Core`; stable public wrapper modules still export the same public surfaces. | complete |
| Refresh runtime compatibility cleanup gates | `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` records current runtime-file classifications and the 2026-05-14 direct-reader inventory. | complete |
| Provide a supported read-only downstream replacement path | `docs/agentic-workflow-framework/downstream-runtime-state-migration.md` maps legacy runtime files to `moifold healthcheck` `watchers[].states.*` paths, and `healthcheckRuntimeStateMigrationContractTests` guard the report shape. | complete |
| Implement read-only downstream command migration | `/tmp/pr-review-watcher-tool-audit` now has local branch `codex/moifold-healthcheck-migration` commit `c2a14af` routing `watcher-healthcheck.mjs`, `issue-planning-control.mjs status`, `issue-implement-control.mjs status`, and `pr-review-control.mjs status/doctor` through `moifold healthcheck`; `npm run check`, `git diff --check`, direct-state-file scans, and fake-`moifold` status smokes passed in that checkout. The patch bundle is `/tmp/pr-review-watcher-tool-moifold-healthcheck-migration.patch`. | complete locally, not upstreamed |
| Implement downstream daemon migration shims | `/tmp/pr-review-watcher-tool-audit` branch `codex/moifold-healthcheck-migration` commit `c2a14af` replaces `issue-planning-watcher.mjs`, `issue-implement-watcher.mjs`, and `pr-review-watcher.mjs` with launchers for Haskell `moifold run-* --execute --loop`; fake-`moifold` launcher smokes passed, and current Haskell `moifold replay-events` accepted the generated initial event logs. | complete locally, not upstreamed |
| Migrate local healthcheck off direct compatibility-file reads | `CodexWatcher.Healthcheck` now projects the stable `watchers[].states.*` compatibility-state shape from event replay through `compatibilityStateWrites`; it directly reads only `runtime-owner.json` as the retained product lease file. `healthcheckRuntimeStateMigrationContractTests` and `healthcheckRuntimeStateReadNonReadContractTest` guard the new behavior. | complete |
| Classify local runtime-file removal candidates | `docs/agentic-workflow-framework/local-runtime-file-candidates.md` records exact decisions for `planning-state.json`, `repair-state.json`, `runtime-owner.json`, and live `issue-snapshot.json`; `localRuntimeFileCandidateDecisionTest` guards the source-backed classification. | complete |
| Remove the obsolete local `planning-state.json` compatibility projection | `RecordPlanningGraph` now compiles to no runtime write, `PlanningWaitingForReadyIssues` writes only `planner-state.json` plus daemon state, the old fixture is deleted, and source/fixture tests assert the file remains absent. | complete |
| Remove normal local compatibility-file producers | `RecordBlocked`, daemon observed transactions, daemon-loop idle/terminal reconciliation, automatic-loop startup/fanout/PR-handoff paths, issue-implementer launch, PR-review launch, and repair execution no longer write compatibility state files. `Runtime.Compatibility` now exposes pure projection only for healthcheck/reporting, and tests assert execute paths append event logs without post-commit compatibility writes. | complete |
| Remove repair-failure `block-state.json` writer and fixture | `AutomaticLoop.Runner` no longer writes `block-state.json` when replay fails, `EventLogRepair` no longer exports `repairFailureBlockStateJson`, the dedicated `golden/runtime-compatibility/block-state/repair-failure/block-state.json` fixture was deleted, and source tests assert runner no longer writes the repair-failure file. | complete |
| Remove checked-in compatibility snapshot readers/fixtures | `CodexWatcher.Snapshot` and `CodexWatcher.GoldenReplay` were removed from source and Cabal exposure; old `golden/pr-review/*` and `golden/issue-implement/*` JSON snapshots were replaced by replayed `golden/event-log/bootstrapped/*` fixtures. Source scans show no snapshot bridge imports. | complete |
| Remove restart/operator stale compatibility-file cleanup | `scripts/restart-watcher` no longer removes stale `block-state.json` or `daemon-state.json`; the operator checklist now points at `moifold healthcheck` instead of `block-state.json`; source tests assert restart no longer touches those stale files. | complete |
| Prove terminal cleanup can close with empty kept/deferred/blocked sets | Direct-reader inventory found live upstream downstream readers of runtime compatibility files. The local downstream audit patch migrates `soulomoon/pr-review-watcher-tool`, but it is not upstream accepted from this workspace. The remaining blocker is downstream owner acceptance, supersession, or explicit retention. | blocked |

## Verification Commands

- `cabal build all`
- `cabal test watcher-core-test`
- `cabal test all`
- `git diff --check`
- Runbook validation gate:
  `docker --version` passed, but `docker info` could not connect to the Docker
  daemon, so the Docker setup smoke could not run in this session.
- Host runbook checks:
  `bash -n scripts/watcher-init/*.sh`,
  `bin="$(cabal list-bin moifold)" && "$bin" probe-app-server --help`
- Runbook stale-reference scan:
  `rg -n -g '!docs/watcher-agent-runbook/runbook-validation.md' 'command_text|bash -lc "\$|app-server TCP check passed|jq|APP_SERVER_CHECK_MODE|probe-app-server' scripts docs test src app moifold.cabal`
- Removed-wrapper import scan:
  `rg -n "^import( qualified)? CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)( qualified)?(\\s|$|\\()" src app test agent-workflow-core agent-workflow-codex agent-workflow-github examples`
- Removed-wrapper Cabal/source scan:
  `rg -n "CodexWatcher\\.(AppServerClient|Core\\.Ids|Workflow\\.EventLog|Workflow\\.Permission)(\\s|$|,)" moifold.cabal src app test --glob '!dist-newstyle/**'`
- Runtime-file local reader/writer inventory:
  `rg -n "issue-state\\.json|daemon-state\\.json|planner-state\\.json|planning-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json|repair-state\\.json|runtime-owner\\.json|issue-snapshot\\.json" . --glob '!dist-newstyle/**' --glob '!orchestrator/worktrees/**' --glob '!orchestrator/rounds/**' --glob '!orchestrator/roadmap-updates/**'`
- Downstream direct-reader inventory:
  `gh search code "\"<file-name>\"" --owner soulomoon --limit 20`
- Downstream replacement contract check:
  `healthcheckRuntimeStateMigrationContractTests` through
  `cabal test watcher-core-test`
- Local healthcheck projection contract check:
  `healthcheckRuntimeStateReadNonReadContractTest` through
  `cabal test watcher-core-test --test-options='--pattern healthcheck'`
- Downstream read-only migration syntax check:
  `npm run check` in `/tmp/pr-review-watcher-tool-audit`
- Downstream migration diff check:
  `git diff --check` in `/tmp/pr-review-watcher-tool-audit`
- Downstream migration local branch/patch:
  branch `codex/moifold-healthcheck-migration` commit `c2a14af` in
  `/tmp/pr-review-watcher-tool-audit`; patch bundle
  `/tmp/pr-review-watcher-tool-moifold-healthcheck-migration.patch`
- Downstream read-only migration smoke:
  fake-`moifold` temporary config-root checks for `issue-planning-control.mjs
  status`, `issue-implement-control.mjs status`, `pr-review-control.mjs
  status`, and `watcher-healthcheck.mjs`
- Downstream daemon migration smoke:
  fake-`moifold` temporary config-root checks for
  `issue-planning-watcher.mjs`, `issue-implement-watcher.mjs`, and
  `pr-review-watcher.mjs`
- Downstream daemon initial-event replay:
  `moifold replay-events /tmp/planner-events.jsonl`,
  `moifold replay-events /tmp/impl-events.jsonl`, and
  `moifold replay-events /tmp/review-events.jsonl`
- Downstream patched direct state-file scan:
  `rg -n "readJson\\([^\\n]*(issue-state\\.json|daemon-state\\.json|planner-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json)|writeJson\\([^\\n]*(issue-state|daemon-state|planner-state|watcher-state|checker-state|agent-state|reviewer-state|block-state|StatePath|blockedStatePath|daemonStatePath|issueStatePath|reviewerStatePath|checkerStatePath|agentStatePath)|appendJsonLine|removeFileIfExists\\([^\\n]*(block|state)" /tmp/pr-review-watcher-tool-audit/{issue-planning-watcher.mjs,issue-implement-watcher.mjs,pr-review-watcher.mjs,watcher-healthcheck.mjs,issue-planning-control.mjs,issue-implement-control.mjs,pr-review-control.mjs}`
- Local runtime-file candidate decision check:
  `localRuntimeFileCandidateDecisionTest` through `cabal test watcher-core-test`
- Production planning-state source scan:
  `rg -n "planning-state\\.json" src app moifold.cabal --glob '!dist-newstyle/**'`
- Planning-state fixture deletion check:
  `find golden/runtime-compatibility -name 'planning-state.json' -print`
- Production compatibility writer removal scan:
  `rg -n 'writeCompatibility|writeCompatibilityFiles|compatibility_reconciled|compatibility_written|runtimeWriteJsonValue[^\n]*(issue-state\.json|daemon-state\.json|planner-state\.json|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|block-state\.json)|PlannedWriteJson[^\n]*(issue-state\.json|daemon-state\.json|planner-state\.json|watcher-state\.json|checker-state\.json|agent-state\.json|reviewer-state\.json|block-state\.json)' src/CodexWatcher app moifold.cabal --glob '!dist-newstyle/**'`
- Snapshot bridge removal scan:
  `rg -n 'CodexWatcher\.(GoldenReplay|Snapshot)|\b(replayNodeSnapshot|bootstrapNodeSnapshotEvents|loadNodeSnapshot|NodeSnapshot|NodePrReviewSnapshot|NodeIssueImplementSnapshot|normalizeNodeSnapshot|replayTypedSnapshot|TypedSnapshot)\b' moifold.cabal src app test agent-workflow-core agent-workflow-codex agent-workflow-github --glob '!dist-newstyle/**'`
- Checked-in compatibility snapshot fixture deletion check:
  `find golden/pr-review golden/issue-implement -type f \( -name '*.json' -o -name '*.jsonl' \) -print`
- Restart/runbook stale compatibility-file cleanup scan:
  `rg -n "issue-state\\.json|daemon-state\\.json|planner-state\\.json|planning-state\\.json|watcher-state\\.json|checker-state\\.json|agent-state\\.json|reviewer-state\\.json|block-state\\.json" docs/watcher-agent-runbook scripts README.md --glob '!dist-newstyle/**'`

## Downstream Runtime-File Findings

`gh search code` under owner `soulomoon` found direct readers in
`soulomoon/pr-review-watcher-tool`:

- `watcher-healthcheck.mjs` reads `issue-state.json`, `daemon-state.json`,
  `planner-state.json`, `watcher-state.json`, `checker-state.json`,
  `agent-state.json`, `reviewer-state.json`, and `block-state.json`.
- `issue-planning-watcher.mjs` reads `issue-state.json`.
- `issue-planning-control.mjs` references `planner-state.json`,
  `daemon-state.json`, and `block-state.json`.
- `issue-implement-control.mjs` references `issue-state.json`,
  `daemon-state.json`, and `block-state.json`.
- `pr-review-control.mjs` references `watcher-state.json`,
  `checker-state.json`, `agent-state.json`, `reviewer-state.json`, and
  `block-state.json`.
- `pr-review-watcher.mjs` references `reviewer-state.json` and
  `block-state.json`.

No downstream hits were found for `planning-state.json`, `repair-state.json`,
`runtime-owner.json`, or `issue-snapshot.json` in that owner-scoped search.
Local repo evidence now supports removing `planning-state.json`; it retains
`repair-state.json` as a repair diagnostic output, `runtime-owner.json` as the
live daemon lease contract, and `issue-snapshot.json` as live planner input.

The local downstream audit patch migrated every listed downstream read-only
command and daemon script away from direct runtime state-file reads/writes.
That changes the local audit checkout, not upstream `soulomoon/pr-review-watcher-tool`.

## Replacement Read Path

Read-only downstream status and health tooling can migrate to:

```bash
moifold healthcheck --state-root /workspace/artifacts --repo owner/name
```

The report preserves legacy state projections under `watchers[].states.*`;
healthcheck now derives those compatibility-state entries from event replay
instead of direct compatibility-file reads. The exact mapping is documented in
`docs/agentic-workflow-framework/downstream-runtime-state-migration.md` and
covered by `healthcheckRuntimeStateMigrationContractTests`.
The downstream audit checkout has a local patch that implements this migration
for read-only status/healthcheck commands and replaces the legacy daemon
scripts with launchers for the Haskell `moifold run-* --execute --loop`
commands. That patch has not been pushed or accepted upstream from this
workspace.

This local downstream patch does not close terminal runtime-file cleanup in the
current repo. Normal local compatibility-file writers have been removed, but
runtime-file removal remains blocked until the downstream patch is accepted or
explicitly retained by the downstream owner. Checked-in compatibility snapshot
readers/fixtures, restart/operator stale-file cleanup, and the repair-failure
`block-state.json` writer/fixture have also been removed locally. The retained
`repair-state.json`, `runtime-owner.json`, and live `issue-snapshot.json` files
are product contracts outside the compatibility-file removal goal.

## Local Runtime-File Candidate Decisions

`docs/agentic-workflow-framework/local-runtime-file-candidates.md` records the
direction 026 decisions:

- `planning-state.json`: `removed`; graph persistence remains event-log and
  replay state.
- `repair-state.json`: `keep-as-product`, because it is a repair diagnostic
  output.
- `runtime-owner.json`: `keep-as-product`, because it is the live daemon lease
  contract.
- live `issue-snapshot.json`: `keep-as-product`, because it is live planner
  input.

## Conclusion

Rev-002 implementation work is complete through milestones 5, 6, 7, 8, the
read-only and daemon-shim downstream audit patches in milestone 10 direction
025, the local healthcheck projection migration, the local runtime-file
candidate classification in direction 026, and the removal of normal local
compatibility-file producers. Milestone 9 cannot be honestly marked complete
because the final success criterion requires empty kept/deferred/blocked
compatibility-surface sets, and current evidence still has external downstream
acceptance unresolved. The next implementable cleanup item is upstreaming or
otherwise owner-accepting the downstream patch, or recording an explicit
downstream owner retention/supersession decision; it is not local terminal
closeout from this workspace alone.
