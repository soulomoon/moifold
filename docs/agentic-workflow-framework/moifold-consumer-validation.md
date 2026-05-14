# Moifold Consumer Validation

Status: passed local evidence-only validation.

Date: 2026-05-09 Asia/Shanghai.

Scope: prove that moifold builds, tests, and exposes current CLI/watcher command
surfaces while consuming the standalone workflow package candidates
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
through local package wiring. This validation did not change package layout,
source implementation, event schemas, compatibility facades, runtime policy, or
release artifacts.

## Commands Run

Descriptor and wiring scans:

```sh
git status --short
rg -n "packages:|agent-workflow-(core|codex|github)|moifold:agent-workflow|library agent-workflow" cabal.project moifold.cabal agent-workflow-core/agent-workflow-core.cabal agent-workflow-codex/agent-workflow-codex.cabal agent-workflow-github/agent-workflow-github.cabal examples/workflow-package-consumer/cabal.project examples/workflow-package-consumer/workflow-package-consumer.cabal
rg -n "workflowMoifoldCabalConsumesStandaloneWorkflowPackages|workflowCabalProjectListsStandaloneWorkflowPackages|workflowCoreStandalonePackageKeepsPackageBoundary|workflowCodexStandalonePackageKeepsPackageBoundary|workflowGithubStandalonePackageKeepsPackageBoundary" test/BoundaryPolicySpec.hs
```

Package-boundary import scans:

```sh
rg -n "^import (CodexWatcher\.(Core|Domain|Effects|EventLog|Observation|StateMachine|Runtime|GhGit|Daemon|DaemonLoop|ChildDaemon|Healthcheck|EventLogRepair|RunnerGuard|WatcherRuntimeStatus|Supervisor)|Data\.Aeson)" agent-workflow-core/src
rg -n "^import CodexWatcher\.(AppServerClient|ActionExecutor|ChildDaemon|Daemon|DaemonLoop|Domain|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Runtime|StateMachine|Workflow\.GitHub|Workflow\.Moifold|Workflow\.Types)" agent-workflow-codex/src
rg -n "^import CodexWatcher\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|Watcher|Workflow\.Agent|Workflow\.Daemon|Workflow\.EventLog|Workflow\.Execution|Workflow\.Moifold|Workflow\.Observation|Workflow\.Permission|Workflow\.Transaction|Workflow\.Types)" agent-workflow-github/src
```

Compatibility-surface scans:

```sh
rg -n "CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.EventLog|Workflow\.Permission)" moifold.cabal src app test
rg -n "workflowMoifoldCabalLibraryDoesNotReexportAdapters|workflowDirectOwnerReplayMatchesEventLog|workflowPermissionSpecMatchesStateMachine|workflowExecutionFacadeDryRunMatchesExecutor|workflowPrReviewCheckingFacadeMatchesWatcher|workflowPrReviewMergeabilityFacadeMatchesWatcher" test/BoundaryPolicySpec.hs test/FacadeImportPolicySpec.hs
rg -n "compatibilityStateWrites|writeCompatibility|issue-state\.json|daemon-state\.json|planning-state\.json|block-state|repair-state|runtime-owner" src/CodexWatcher/Runtime/Compatibility.hs src/CodexWatcher/Cli/Command/Replay.hs src/CodexWatcher/Cli/Command/Observe.hs src/CodexWatcher/AutomaticLoop/Runner.hs src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs src/CodexWatcher/AutomaticLoop/StartupThreads.hs src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs docs/agentic-workflow-framework/compatibility-deprecation-policy.md
```

Validation commands:

```sh
scripts/validate-workflow-packages.sh
(cd examples/workflow-package-consumer && cabal build all)
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
cabal build all
cabal test watcher-core-test
cabal run exe:moifold -- --help
cabal run exe:moifold -- run-issue-planning --help
cabal run exe:moifold -- run-issue-implement --help
cabal run exe:moifold -- run-pr-review --help
cabal run exe:moifold -- issue-fanout --help
cabal run exe:moifold -- observe-once --help
cabal run exe:moifold -- render-service --name round-049-smoke --domain issue-planning --events /tmp/moifold-round-049/events.jsonl --state-dir /tmp/moifold-round-049/state --repo soulomoon/mlf2 --workdir /tmp/moifold-round-049/work --app-server-host 127.0.0.1 --app-server-port 3000 --thread-id planner-thread --executable /tmp/moifold-smoke
tmp_state_root="$(mktemp -d)"
cabal run exe:moifold -- healthcheck --state-root "$tmp_state_root" --repo soulomoon/mlf2
git diff --check
git diff -- docs/agentic-workflow-framework/moifold-consumer-validation.md
git diff --no-index --check /dev/null docs/agentic-workflow-framework/moifold-consumer-validation.md
git diff --no-index --check /dev/null orchestrator/rounds/round-049/implementation-notes.md
git diff --no-index -- /dev/null docs/agentic-workflow-framework/moifold-consumer-validation.md
```

## Descriptor Wiring Evidence

`cabal.project` lists only the root package plus the standalone workflow
package candidates:

```cabal
packages:
  .
  agent-workflow-core
  agent-workflow-codex
  agent-workflow-github
```

The descriptor scan found no `moifold:agent-workflow-*` references and no
`library agent-workflow-*` internal component definitions. `moifold.cabal`
depends on the standalone package names in both the main library and
`watcher-core-test`:

```cabal
agent-workflow-core >=0.1 && <0.2,
agent-workflow-codex >=0.1 && <0.2,
agent-workflow-github >=0.1 && <0.2
```

Standalone package descriptor ownership:

- `agent-workflow-core` exposes 13 generic workflow modules and depends only on
  `base`, `bytestring`, and `text`.
- `agent-workflow-codex` exposes 10 Codex app-server and typed agent adapter
  modules and depends on `aeson`, `agent-workflow-core`, `base`, `bytestring`,
  `text`, and `websockets`.
- `agent-workflow-github` exposes 3 GitHub identifier, remote metadata, and
  command rendering modules and depends only on `aeson`, `base`, and `text`.

The local consumer example has its own `cabal.project` with local paths to
`../../agent-workflow-core`, `../../agent-workflow-codex`, and
`../../agent-workflow-github`. Its executable depends on the three standalone
package names and does not depend on `moifold`.

## Boundary And Import-Scan Evidence

The required forbidden import scans returned no matches for all reusable package
source trees:

- `agent-workflow-core/src`: no imports of moifold lifecycle/runtime modules or
  `Data.Aeson`.
- `agent-workflow-codex/src`: no imports of moifold app-server compatibility,
  lifecycle, healthcheck, runtime, GitHub, or moifold workflow modules.
- `agent-workflow-github/src`: no imports of moifold app-server, CLI,
  lifecycle, event-log, healthcheck, runtime, agent, daemon, workflow facade, or
  compatibility modules.

`test/BoundaryPolicySpec.hs` contains the recursive source-tree assertions used by
`watcher-core-test`, including:

- `workflowCabalProjectListsStandaloneWorkflowPackages`
- `workflowMoifoldCabalConsumesStandaloneWorkflowPackages`
- `workflowCoreStandalonePackageKeepsPackageBoundary`
- `workflowCodexStandalonePackageKeepsPackageBoundary`
- `workflowGithubStandalonePackageKeepsPackageBoundary`

The helpers `sourceFilesUnder`, `sourceModulesUnder`,
`sourceImportViolationsUnder`, and `sourceTextNeedleViolationsUnder` scan the
package source trees recursively rather than relying on a hand-listed source
subset.

## Compatibility Surface Evidence

The compatibility scan confirms that the removed public wrappers no longer
carry reusable-package access:

```text
CodexWatcher.AppServerClient is not exposed by moifold.cabal
CodexWatcher.Core.Ids is not exposed by moifold.cabal
CodexWatcher.Workflow.EventLog is not exposed by moifold.cabal
CodexWatcher.Workflow.Permission is not exposed by moifold.cabal
src/CodexWatcher/Workflow/Execution.hs still imports CodexWatcher.Workflow.Execution.Core
src/CodexWatcher/Workflow/Types.hs still imports CodexWatcher.Workflow.Spec
```

`test/BoundaryPolicySpec.hs` and `test/FacadeImportPolicySpec.hs` assert the direct owner and
adapter boundary contracts:

- `workflowMoifoldCabalLibraryDoesNotReexportAdapters`
- `workflowDirectOwnerReplayMatchesEventLog`
- `workflowPermissionSpecMatchesStateMachine`
- `workflowExecutionFacadeDryRunMatchesExecutor`
- `workflowPrReviewCheckingFacadeMatchesWatcher`
- `workflowPrReviewMergeabilityFacadeMatchesWatcher`

Compatibility file ownership remains in moifold. As of the 2026-05-14 cleanup,
`src/CodexWatcher/Runtime/Compatibility.hs` exposes pure
`compatibilityStateWrites` projections for healthcheck/reporting, and the old
`writeCompatibility` runtime writer plus replay/startup/fanout/PR-handoff
writer call sites have been removed. The policy doc names the remaining
runtime-state surfaces as moifold-owned migration or product-retention issues,
not reusable package promises; the obsolete `planning-state.json` graph
projection has been removed.

## Package Validation Output

`scripts/validate-workflow-packages.sh` passed. It ran:

```text
(cd agent-workflow-core && cabal check)
(cd agent-workflow-codex && cabal check)
(cd agent-workflow-github && cabal check)
cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-core
cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-codex
cabal sdist --output-directory=dist-newstyle/sdist agent-workflow-github
```

Each `cabal check` reported:

```text
No errors or warnings could be found in the package.
```

Local source distributions were written and validated at:

```text
dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz
dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz
dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz
```

The script ended with:

```text
No upload or package publication command was run.
```

## Local Consumer Example Output

`(cd examples/workflow-package-consumer && cabal build all)` passed. Cabal built
`agent-workflow-core`, `agent-workflow-github`, `agent-workflow-codex`, and the
`workflow-package-consumer` executable from the example-local package set.

`(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`
passed and printed package-specific output:

```text
agent-workflow-core
observation -> event=review-accepted, effects=record-decision
dsl -> event=review-accepted, effects=record-decision

agent-workflow-codex
request id=1, method=thread/start
request id=2, method=turn/start
request id=3, method=thread/read

agent-workflow-github
gh pr list --repo soulomoon/moifold --head codex/example-consumer --state open --json number,title,headRefName,headRefOid,body,state cwd=<none> stdin-bytes=0
gh pr view 47 --repo soulomoon/moifold --json state,mergedAt,mergeCommit,url,headRefOid,mergeStateStatus,reviewDecision cwd=<none> stdin-bytes=0
git push --dry-run origin codex/example-consumer cwd=/workspace/example stdin-bytes=0
```

The Codex section also emitted JSON-RPC request JSON for `thread/start`,
`turn/start`, and `thread/read`, proving the example exercised exposed
`agent-workflow-codex` request construction.

## Moifold Build And Test Output

`cabal build all` passed. Cabal built:

```text
agent-workflow-core-0.1.0.0 (lib)
agent-workflow-github-0.1.0.0 (lib)
agent-workflow-codex-0.1.0.0 (lib)
moifold-0.1.0.0 (lib)
moifold-0.1.0.0 (exe:moifold)
```

`cabal test watcher-core-test` passed:

```text
Test suite watcher-core-test: PASS
1 of 1 test suites (1 of 1 test cases) passed.
```

The test log was written to:

```text
dist-newstyle/build/aarch64-osx/ghc-9.12.2/moifold-0.1.0.0/t/watcher-core-test/test/moifold-0.1.0.0-watcher-core-test.log
```

Relevant covered surfaces in `watcher-core-test` include:

- `test/BoundaryPolicySpec.hs`: package descriptor scans, recursive package-boundary scans,
  facade parity checks, adapter reexport checks, event-log/replay contracts,
  and workflow law checks.
- `test/CliSpec.hs`: CLI parser coverage for healthcheck, run-loop,
  app-server probe, bad domains, and runner guard domains.
- `test/HealthcheckSpec.hs`: read-only healthcheck lifecycle reporting,
  singleton domain dispatch, summary JSON shape, daemon-required statuses, and
  typed analyzer dispatch.
- `test/RuntimeSpec.hs`: GitHub command rendering, push safety, structured PR
  view/check commands, runtime defaults, and process execution reporting.

## CLI And Watcher Smoke Output

All required help/rendering smoke commands returned exit code 0.

Top-level help included the current command surface:

```text
replay-events
probe-app-server
healthcheck
clear-runtime-lease
stop-daemon
render-service
issue-fanout
observe-once
run-pr-review
run-issue-implement
run-issue-planning
guard-issue-planning
guard-issue-implement
guard-pr-review
repair-invalid-state
```

The domain loop help commands parsed and printed usage for:

```text
moifold run-issue-planning --events events.jsonl --state-dir PATH --repo owner/name ...
moifold run-issue-implement --events events.jsonl --state-dir PATH --repo owner/name ...
moifold run-pr-review --events events.jsonl --state-dir PATH --repo owner/name ...
```

`issue-fanout --help` printed:

```text
Usage: moifold issue-fanout --repo owner/name --implementers-root PATH --max-parallel N ...
```

`observe-once --help` printed:

```text
Usage: moifold observe-once --events events.jsonl --state-dir PATH --repo owner/name ... --domain pr-review|issue-implement|issue-planning --observation NAME ...
```

`render-service` produced a systemd unit and logrotate config. The rendered
`ExecStart` remained moifold-owned and targeted the issue-planning loop:

```text
ExecStart=/tmp/moifold-smoke run-issue-planning --events /tmp/moifold-round-049/events.jsonl --state-dir /tmp/moifold-round-049/state --repo soulomoon/mlf2 --workdir /tmp/moifold-round-049/work --app-server-host 127.0.0.1 --app-server-port 3000 --poll-seconds 30 --execute --loop
```

Optional empty-root healthcheck was cheap and passed. Output summary:

```json
{
  "repoFilter": "soulomoon/mlf2",
  "status": "ok",
  "problems": [],
  "summary": {
    "activeImplementers": 0,
    "blockedConfigs": 0,
    "implementers": 0,
    "planners": 0,
    "reviewWatchers": 0,
    "runningDaemons": 0,
    "totalConfigs": 0
  }
}
```

The healthcheck notes included that it is read-only and does not mutate GitHub,
app-server threads, or local checkouts.

## Implementation Notes

This round made no production code, package descriptor, schema, fixture,
runtime, healthcheck, repair, prompt-policy, CI, changelog, release-note,
roadmap, or controller-state changes. The only intended repository changes are
this evidence document and the round implementation notes.

Generated `dist-newstyle/` outputs from package validation and builds are local
ignored artifacts. They were not committed, staged, uploaded, or treated as a
release-candidate bundle.

The worktree had a pre-existing modified `orchestrator/state.json` and an
untracked `orchestrator/rounds/round-049/` directory at the start of this
validation. This round did not edit `orchestrator/state.json`.

Final hygiene notes: `git diff --check` passed. The required
`git diff -- docs/agentic-workflow-framework/moifold-consumer-validation.md`
produced no output because the evidence document is a new untracked file, so
the new-file whitespace and review diff were checked with `git diff --no-index`
without staging anything. The no-index `--check` commands printed no whitespace
errors; their non-zero exit status is the expected no-index diff status for a
new file compared with `/dev/null`.

## Non-Goals

This validation did not perform or approve any of the following:

- package upload or publication
- release approval
- release-candidate bundle assembly
- package descriptor or version changes
- compatibility facade removal
- event schema changes
- golden fixture changes
- runtime policy changes
- healthcheck policy changes
- repair policy changes
- prompt-policy changes
- CI changes
- changelog or release-note changes
- source-distribution artifact commits
- roadmap or controller-state edits
