# Core.Ids Split Import Evidence

Round: `round-060`
Roadmap: `2026-05-09-01-compatibility-surface-cleanup`
Revision: `rev-002`

## Scope

This artifact records current evidence for `CodexWatcher.Core.Ids` split-import
ownership only. It does not approve deprecation, facade narrowing, import
migration, Cabal exposure changes, runtime compatibility changes, or removal.

## Facade Shape

`src/CodexWatcher/Core/Ids.hs` is a combined moifold facade:

- It reexports `CodexWatcher.Workflow.Agent.Ids`.
- It reexports `CodexWatcher.Workflow.GitHub.Ids`.
- It contains no local identifier definitions.

The split owner modules currently define these surfaces:

- Agent-id owner: `CodexWatcher.Workflow.Agent.Ids`
  - `RequestId`
  - `ThreadId`
  - `TurnId`
  - `nextRequestId`
- GitHub-id owner: `CodexWatcher.Workflow.GitHub.Ids`
  - `RepoName`
  - `IssueNumber`
  - `PrNumber`
  - `BranchName`
  - `ReviewThreadId`
  - `CommitSha`

## Recursive Import Scan

Command:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed. All planned paths exist. The scan found 65 importers of the
combined facade. No combined-facade imports were found under `examples`,
`agent-workflow-core`, `agent-workflow-codex`, or `agent-workflow-github`.

### Agent-Only Source Importers

These source importers use only `RequestId`, `ThreadId`, `TurnId`, or
`nextRequestId` from the combined facade and have a direct split replacement in
`CodexWatcher.Workflow.Agent.Ids`:

- `src/CodexWatcher/AutomaticLoop/Runner.hs`
- `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
- `src/CodexWatcher/Cli/Command/AppServerProbe.hs`
- `src/CodexWatcher/Core/Thread.hs`
- `src/CodexWatcher/DaemonLoop.hs`
- `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`
- `src/CodexWatcher/DaemonLoop/TurnStart.hs`
- `src/CodexWatcher/Runtime/Defaults.hs`
- `src/CodexWatcher/Workflow/DocsMigration.hs`
- `src/CodexWatcher/Workflow/Execution.hs`
- `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`

### GitHub-Only Source Importers

These source importers use only GitHub-owned identifiers from the combined
facade and have a direct split replacement in
`CodexWatcher.Workflow.GitHub.Ids`:

- `app/Main.hs`
- `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`
- `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
- `src/CodexWatcher/Cli/Command/Service.hs`
- `src/CodexWatcher/Daemon.hs`
- `src/CodexWatcher/Domain/IssueImplement/Types.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Graph/Canonical.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Scope.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Types.hs`
- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`
- `src/CodexWatcher/Domain/PrReview/Types.hs`
- `src/CodexWatcher/GhGit.hs`
- `src/CodexWatcher/IssueText.hs`
- `src/CodexWatcher/Runtime/Command/Render.hs`
- `src/CodexWatcher/Runtime/Command/Types.hs`
- `src/CodexWatcher/TurnOutput.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview/Mergeability/Indexed.hs`

### Mixed Agent and GitHub Source Importers

These source importers use both agent-owned and GitHub-owned identifiers, or
use an unqualified/broad combined-facade import in a module whose current
surface spans both ownership areas. They are later migration risks because a
single split import cannot replace the facade without adding at least two
imports:

- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
- `src/CodexWatcher/Cli/Parser/Common.hs`
- `src/CodexWatcher/Cli/Parser/Observe.hs`
- `src/CodexWatcher/Cli/RuntimeConfig.hs`
- `src/CodexWatcher/Cli/Types.hs`
- `src/CodexWatcher/Core/State.hs`
- `src/CodexWatcher/DaemonLoop/Types.hs`
- `src/CodexWatcher/Domain/IssueImplement/Loop.hs`
- `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs`
- `src/CodexWatcher/Domain/IssueImplement/Watcher.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Loop.hs`
- `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs`
- `src/CodexWatcher/Domain/PrReview/LaunchCli.hs`
- `src/CodexWatcher/Domain/PrReview/Loop.hs`
- `src/CodexWatcher/Domain/PrReview/Protocol.hs`
- `src/CodexWatcher/Domain/PrReview/Watcher.hs`
- `src/CodexWatcher/EffectInterpreter.hs`
- `src/CodexWatcher/Effects.hs`
- `src/CodexWatcher/EventLog/Replay.hs`
- `src/CodexWatcher/EventLog/Types.hs`
- `src/CodexWatcher/EventLogRepair.hs`
- `src/CodexWatcher/GoldenReplay.hs`
- `src/CodexWatcher/Healthcheck.hs`
- `src/CodexWatcher/RunnerGuard.hs`
- `src/CodexWatcher/Runtime/Compatibility.hs`
- `src/CodexWatcher/StateMachine.hs`
- `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs`
- `src/CodexWatcher/Workflow/Moifold/PrReview.hs`

### Tests

The combined facade is still used directly by tests:

- `test/AppServerSpec.hs`
- `test/CliSpec.hs`
- `test/GhGitSpec.hs`
- `test/Main.hs`
- `test/RuntimeSpec.hs`

These tests provide compile-through coverage for the facade but also block any
claim that the facade is migration-ready without a test import migration and a
focused behavior run.

### Examples

The combined-facade scan found no `CodexWatcher.Core.Ids` imports under
`examples`.

## Split Import Scan

Command:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed. The scan found 10 split-module importers:

- `agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex.hs`
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs`
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs`
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs`
- `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Types.hs`
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Command.hs`
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Remote.hs`
- `examples/workflow-package-consumer/app/Main.hs`
- `src/CodexWatcher/Core/Ids.hs`

Package-boundary evidence:

- `agent-workflow-codex` imports `CodexWatcher.Workflow.Agent.Ids` directly.
- `agent-workflow-github` imports `CodexWatcher.Workflow.GitHub.Ids` directly.
- `agent-workflow-core` imports neither the combined moifold facade nor either
  split id module.
- The package-consumer example imports the split modules directly.
- `src/CodexWatcher/Core/Ids.hs` is the only main-library source file importing
  both split modules as a facade implementation detail.

## Docs and Descriptor Scan

Command:

```sh
rg -n 'CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: passed. Matches were in Cabal descriptors, reusable-package READMEs,
the package-consumer example, reusable package source, and
`docs/agentic-workflow-framework`.

Relevant current docs evidence:

- `docs/agentic-workflow-framework/release-notes.md` says
  `CodexWatcher.Core.Ids` remains a moifold convenience facade over agent and
  GitHub identifiers.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` says
  reusable agent code should prefer `CodexWatcher.Workflow.Agent.Ids`,
  reusable GitHub code should prefer `CodexWatcher.Workflow.GitHub.Ids`, and
  existing moifold code may keep using `CodexWatcher.Core.Ids`.
- `docs/agentic-workflow-framework/package-consumer-guide.md`,
  `docs/agentic-workflow-framework/implemented-api-freeze.md`, and package
  READMEs name the split modules as public reusable-package surfaces.
- The root `README.md` had no match for these id modules.

## Exposed Module Assertions

Command:

```sh
rg -n 'exposed-modules|other-modules|CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' *.cabal */*.cabal
```

Result: passed.

Current package-boundary exposure:

- `moifold.cabal` exposes `CodexWatcher.Core.Ids`.
- `agent-workflow-codex/agent-workflow-codex.cabal` exposes
  `CodexWatcher.Workflow.Agent.Ids`.
- `agent-workflow-github/agent-workflow-github.cabal` exposes
  `CodexWatcher.Workflow.GitHub.Ids`.
- `agent-workflow-core/agent-workflow-core.cabal` exposes no id module and has
  no `CodexWatcher.Core.Ids` dependency.

## Historical Comparison

Round 054 and round 056 both recorded 65 `CodexWatcher.Core.Ids` imports.
This refreshed round-060 scan also finds 65 combined-facade importers, so there
is no count delta to explain. The new evidence adds ownership grouping for the
agent-id versus GitHub-id split.

## Downstream and Operator Evidence

The planned local scan paths all exist. A local directory search for obvious
downstream/operator evidence directories did not find separate
`downstream` or `operator` trees in this worktree. The docs scan did include
the available operator-facing documentation under `docs`.

External downstream users remain unverified in this round. Local absence of
extra downstream references is not removal approval.

## Migration Risks and Blockers

- Thirty source importers are mixed agent/GitHub users or broad combined-facade
  users. They require per-module split import edits and focused behavior
  validation before any migration claim.
- Five tests still compile through `CodexWatcher.Core.Ids`; keeping those tests
  unchanged preserves facade coverage but blocks cleanup readiness.
- Broad unqualified imports remain in core/runtime/CLI/test modules such as
  `src/CodexWatcher/Core/State.hs`, `src/CodexWatcher/EventLog/Types.hs`,
  `src/CodexWatcher/Cli/Types.hs`, `src/CodexWatcher/Runtime/Compatibility.hs`,
  and `test/Main.hs`.
- Public docs still describe `CodexWatcher.Core.Ids` as a supported moifold
  compatibility facade. That is consistent with current policy and blocks any
  removal claim without a later policy change.
- External downstream and operator references were not independently verified
  beyond the local repository and docs scan.

## Verification

Commands run:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|other-modules|CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' *.cabal */*.cabal
find . -maxdepth 3 -type d -name '.git' -prune -o -maxdepth 3 -type d \( -name '*downstream*' -o -name '*operator*' \) -print
rg -n "Core\.Ids|65 selected-facade|round 056|round-056|round-054" orchestrator/rounds/round-054 orchestrator/rounds/round-056 docs/agentic-workflow-framework/compatibility-deprecation-policy.md
```

Final whitespace verification is recorded in `implementation-notes.md`.
