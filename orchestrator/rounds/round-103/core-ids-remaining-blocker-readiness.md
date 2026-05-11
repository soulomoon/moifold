## Scope

Round: `round-103`

Roadmap lineage: `2026-05-11-00-highest-value-cleanup`, `rev-001`

Milestone: `milestone-003-import-convergence-package-boundaries`

Direction: `direction-011-core-ids-import-convergence`

Selected extraction:
`round-103-core-ids-remaining-blocker-readiness`

This is an artifact-only readiness round for the remaining
`CodexWatcher.Core.Ids` import set after rounds 098 through 102. It refreshes
the current scan over the live worktree, confirms that the five safe
single-domain candidates from round 097 have been completed, classifies the
remaining importers by blocker type, and recommends the next direction for
direction 011.

Non-goals: no source, test, app, package descriptor, roadmap, controller-state,
public facade, fixture, docs, runtime compatibility, parser, renderer,
command-output, event-schema, prompt, healthcheck, repair, replay, restart, or
behavior change. `CodexWatcher.Core.Ids` remains available and exposed; this
round is not deprecation, Cabal exposure removal, facade removal, release
approval, milestone completion, or terminal completion.

## Inputs Reviewed

- `orchestrator/state.json`
- `orchestrator/rounds/round-103/selection.md`
- `orchestrator/rounds/round-103/plan.md`
- `orchestrator/project-contract.md`
- `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
- `orchestrator/rounds/round-097/facade-import-scan-refresh.md`
- `orchestrator/rounds/round-098/implementation-notes.md`
- `orchestrator/rounds/round-098/review.md`
- `orchestrator/rounds/round-099/implementation-notes.md`
- `orchestrator/rounds/round-099/review.md`
- `orchestrator/rounds/round-100/implementation-notes.md`
- `orchestrator/rounds/round-100/review.md`
- `orchestrator/rounds/round-101/implementation-notes.md`
- `orchestrator/rounds/round-101/review.md`
- `orchestrator/rounds/round-102/implementation-notes.md`
- `orchestrator/rounds/round-102/review.md`

## Commands Run

Starting scope:

```sh
git status --short
git diff --name-status
git ls-files --others --exclude-standard orchestrator/rounds/round-103
```

Result: matched expected artifact/controller scope. Before this implementation
the worktree already showed controller-owned `M orchestrator/state.json` and
untracked round-103 plan/selection artifacts:

```text
 M orchestrator/state.json
?? orchestrator/rounds/round-103/
M	orchestrator/state.json
orchestrator/rounds/round-103/plan.md
orchestrator/rounds/round-103/selection.md
```

Current exact `CodexWatcher.Core.Ids` import scan:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github
```

Result: matched selected shape. The live scan found 39 total imports: 29 under
`src`, 10 under `test`, 0 under `app`, and 0 under standalone package
candidates.

Completed safe-candidate facade-import scan:

```sh
rg -n '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' \
  test/BoundaryPolicySpec.hs \
  src/CodexWatcher/Workflow/Execution.hs \
  src/CodexWatcher/Core/State.hs \
  app/Main.hs \
  test/WorkflowDocsMigrationSpec.hs
```

Result: matched expected shape. Exit code 1 with no output; the five completed
safe candidates no longer import the facade.

Completed safe-candidate direct-owner scan:

```sh
rg -n '^import[[:space:]]+CodexWatcher\.Workflow\.(GitHub|Agent)\.Ids([[:space:]]|$|\()' \
  test/BoundaryPolicySpec.hs \
  src/CodexWatcher/Workflow/Execution.hs \
  src/CodexWatcher/Core/State.hs \
  app/Main.hs \
  test/WorkflowDocsMigrationSpec.hs
```

Result: matched expected shape. Direct-owner imports are present in all five
completed candidate files.

Token-domain scan:

```sh
rg -l '^import[[:space:]]+(qualified[[:space:]]+)?CodexWatcher\.Core\.Ids([[:space:]]|$|\()' \
  src app test agent-workflow-core agent-workflow-codex agent-workflow-github \
  | sort \
  | xargs rg -n '\b(RepoName|IssueNumber|PrNumber|BranchName|ReviewThreadId|CommitSha|RequestId|ThreadId|TurnId|nextRequestId|unRepoName|unIssueNumber|unPrNumber|unBranchName|unReviewThreadId|unCommitSha|unRequestId|unThreadId|unTurnId)\b'
```

Result: matched expected shape. Every remaining importer uses both GitHub-domain
and agent-domain id tokens, or is a policy/test surface that intentionally
keeps facade coverage until a later evidence slice.

Package exposure and descriptor scan:

```sh
rg -n 'CodexWatcher\.Core\.Ids|CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids|agent-workflow-(codex|github)' \
  moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
git diff -- moifold.cabal agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal cabal.project
```

Result: matched expected shape. `moifold.cabal` still exposes
`CodexWatcher.Core.Ids`; `agent-workflow-codex` exposes
`CodexWatcher.Workflow.Agent.Ids`; `agent-workflow-github` exposes
`CodexWatcher.Workflow.GitHub.Ids`; `cabal.project` includes both standalone
packages. The descriptor diff command produced no output, so no descriptor
change was made in this round.

## Current Import Counts

| Area | Count |
| --- | ---: |
| `src` | 29 |
| `app` | 0 |
| `test` | 10 |
| `agent-workflow-core` | 0 |
| `agent-workflow-codex` | 0 |
| `agent-workflow-github` | 0 |
| Total | 39 |

Current importers:

- `src/CodexWatcher/Cli/Command/IssueFanout.hs`
- `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
- `src/CodexWatcher/Cli/Parser/Common.hs`
- `src/CodexWatcher/Cli/Parser/Observe.hs`
- `src/CodexWatcher/Cli/RuntimeConfig.hs`
- `src/CodexWatcher/Cli/Types.hs`
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
- `test/CliSpec.hs`
- `test/FacadeImportPolicySpec.hs`
- `test/Main.hs`
- `test/RuntimeCompatibilityFixtureSpec.hs`
- `test/RuntimeSpec.hs`
- `test/TestSupport/Workflow.hs`
- `test/WorkflowAgentSpec.hs`
- `test/WorkflowEventLogSpec.hs`
- `test/WorkflowExecutionSpec.hs`
- `test/WorkflowIndexedSpec.hs`

## Completed Safe Candidates

| Prior round | File | Direct owner import now present | Current facade import |
| --- | --- | --- | --- |
| round-098 | `test/BoundaryPolicySpec.hs` | `CodexWatcher.Workflow.GitHub.Ids` | none |
| round-099 | `src/CodexWatcher/Workflow/Execution.hs` | `CodexWatcher.Workflow.Agent.Ids (RequestId)` | none |
| round-100 | `src/CodexWatcher/Core/State.hs` | `CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)` | none |
| round-101 | `app/Main.hs` | `CodexWatcher.Workflow.GitHub.Ids (RepoName (unRepoName))` | none |
| round-102 | `test/WorkflowDocsMigrationSpec.hs` | `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..))` | none |

The completed safe candidate scan confirms the round-097 GitHub-only and
agent-only candidates are exhausted in the live worktree.

## Remaining Importers

| File | Blocker type | Observed token groups |
| --- | --- | --- |
| `src/CodexWatcher/Cli/Command/IssueFanout.hs` | parser/renderer or command-output blocker | GitHub: `BranchName`, `IssueNumber`, `RepoName`, `unBranchName`, `unIssueNumber`, `unRepoName`; agent: `RequestId`, `ThreadId`, `unThreadId` |
| `src/CodexWatcher/Cli/Command/RunnerGuard.hs` | parser/renderer or command-output blocker | GitHub: `RepoName`, `unRepoName`; agent: `ThreadId`, `TurnId`, `unThreadId`, `unTurnId` |
| `src/CodexWatcher/Cli/Parser/Common.hs` | parser/renderer or command-output blocker | GitHub: `IssueNumber`, `RepoName`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Cli/Parser/Observe.hs` | parser/renderer or command-output blocker | GitHub: `CommitSha`, `PrNumber`; agent: `TurnId` |
| `src/CodexWatcher/Cli/RuntimeConfig.hs` | runtime-config or compatibility-state blocker | GitHub: `IssueNumber`, `RepoName`; agent: `RequestId` |
| `src/CodexWatcher/Cli/Types.hs` | parser/renderer or command-output blocker | GitHub: `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/DaemonLoop/Types.hs` | runtime-config or compatibility-state blocker | GitHub: `CommitSha`, `PrNumber`; agent: `ThreadId`, `TurnId`, `unTurnId` |
| `src/CodexWatcher/Domain/IssueImplement/Loop.hs` | parser/renderer or command-output blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `unBranchName`, `unIssueNumber`, `unPrNumber`; agent: `RequestId`, `ThreadId` |
| `src/CodexWatcher/Domain/IssueImplement/TurnClassifier.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `CommitSha`, `PrNumber`, `unCommitSha`; agent: `ThreadId` |
| `src/CodexWatcher/Domain/IssueImplement/Watcher.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `BranchName`, `CommitSha`, `PrNumber`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Domain/IssuePlanning/Fanout.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `BranchName`, `IssueNumber`, `RepoName`, `unBranchName`, `unIssueNumber`, `unRepoName`; agent: `ThreadId`, `unThreadId` |
| `src/CodexWatcher/Domain/IssuePlanning/Loop.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `IssueNumber`, `RepoName`, `unIssueNumber`, `unRepoName`; agent: `RequestId`, `ThreadId`, `TurnId`, `nextRequestId`, `unRequestId`, `unTurnId` |
| `src/CodexWatcher/Domain/IssuePlanning/Watcher.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `IssueNumber`, `unIssueNumber`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Domain/PrReview/LaunchCli.hs` | parser/renderer or command-output blocker | GitHub: `BranchName`, `PrNumber`, `RepoName`, `unBranchName`, `unPrNumber`, `unRepoName`; agent: `RequestId`, `ThreadId`, `unThreadId` |
| `src/CodexWatcher/Domain/PrReview/Loop.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `CommitSha`, `PrNumber`, `unPrNumber`; agent: `ThreadId` |
| `src/CodexWatcher/Domain/PrReview/Protocol.hs` | event-log or golden/replay blocker | GitHub: `CommitSha`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Domain/PrReview/Watcher.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `CommitSha`, `ReviewThreadId`, `unReviewThreadId`; agent: `TurnId` |
| `src/CodexWatcher/EffectInterpreter.hs` | parser/renderer or command-output blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `unBranchName`, `unIssueNumber`, `unPrNumber`; agent: `RequestId`, `ThreadId`, `nextRequestId` |
| `src/CodexWatcher/Effects.hs` | combined agent/github ids | GitHub: `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, `ReviewThreadId`; agent: `ThreadId` |
| `src/CodexWatcher/EventLog/Replay.hs` | event-log or golden/replay blocker | GitHub: `IssueNumber`, `unIssueNumber`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/EventLog/Types.hs` | event-log or golden/replay blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unBranchName`, `unCommitSha`, `unIssueNumber`, `unPrNumber`, `unRepoName`, `unReviewThreadId`; agent: `ThreadId`, `TurnId`, `unThreadId`, `unTurnId` |
| `src/CodexWatcher/EventLogRepair.hs` | event-log or golden/replay blocker | GitHub: `IssueNumber`, `PrNumber`, `unIssueNumber`, `unPrNumber`; agent: `TurnId` |
| `src/CodexWatcher/GoldenReplay.hs` | event-log or golden/replay blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Healthcheck.hs` | runtime-config or compatibility-state blocker | GitHub: `BranchName`, `CommitSha`, `PrNumber`, `RepoName`, `unBranchName`, `unCommitSha`; agent: `RequestId`, `ThreadId`, `TurnId`, `unTurnId` |
| `src/CodexWatcher/RunnerGuard.hs` | runtime-config or compatibility-state blocker | GitHub: `RepoName`, `unRepoName`; agent: `RequestId`, `ThreadId`, `TurnId`, `unThreadId`, `unTurnId` |
| `src/CodexWatcher/Runtime/Compatibility.hs` | runtime-config or compatibility-state blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unBranchName`, `unCommitSha`, `unIssueNumber`, `unPrNumber`, `unRepoName`, `unReviewThreadId`; agent: `ThreadId`, `TurnId`, `unThreadId`, `unTurnId` |
| `src/CodexWatcher/StateMachine.hs` | event-log or golden/replay blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `ReviewThreadId`, `unBranchName`, `unPrNumber`; agent: `ThreadId` |
| `src/CodexWatcher/Workflow/Moifold/IssueImplement/Indexed.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `BranchName`, `CommitSha`, `PrNumber`; agent: `ThreadId`, `TurnId` |
| `src/CodexWatcher/Workflow/Moifold/PrReview.hs` | prompt/turn/classifier or loop-policy blocker | GitHub: `CommitSha`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `test/CliSpec.hs` | test-policy evidence blocker | GitHub: `IssueNumber`, `RepoName`; agent: `ThreadId` |
| `test/FacadeImportPolicySpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`; agent: `ThreadId`, `TurnId` |
| `test/Main.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unBranchName`, `unCommitSha`, `unIssueNumber`, `unPrNumber`, `unReviewThreadId`; agent: `RequestId`, `ThreadId`, `TurnId`, `unRequestId`, `unThreadId`, `unTurnId` |
| `test/RuntimeCompatibilityFixtureSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `IssueNumber`, `PrNumber`, `RepoName`, `unIssueNumber`, `unRepoName`; agent: `ThreadId`, `TurnId` |
| `test/RuntimeSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unBranchName`, `unCommitSha`, `unIssueNumber`, `unPrNumber`, `unRepoName`; agent: `ThreadId`, `unThreadId` |
| `test/TestSupport/Workflow.hs` | test-policy evidence blocker | GitHub: `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unBranchName`, `unCommitSha`, `unIssueNumber`, `unPrNumber`, `unReviewThreadId`; agent: `RequestId`, `ThreadId`, `TurnId`, `unRequestId` |
| `test/WorkflowAgentSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`; agent: `RequestId`, `ThreadId`, `TurnId`, `nextRequestId` |
| `test/WorkflowEventLogSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `test/WorkflowExecutionSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`; agent: `ThreadId`, `TurnId` |
| `test/WorkflowIndexedSpec.hs` | test-policy evidence blocker | GitHub: `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, `RepoName`, `ReviewThreadId`, `unCommitSha`; agent: `RequestId`, `ThreadId`, `TurnId` |

All remaining production importers are now combined/blocker-class users, not
safe single-domain candidates. Test importers intentionally remain evidence
surfaces until a later verified policy slice moves them.

## Recommendation

Direction 011 has no safe next single-domain implementation slice based on the
current scan. The five round-097 candidates are complete, and every remaining
importer either combines agent-domain and GitHub-domain ids in the same file or
belongs to parser/renderer, command-output, runtime-config, compatibility
state, event-log, golden/replay, prompt/turn/classifier, loop-policy, or
test-policy evidence surfaces.

Recommendation: close direction 011's current single-domain queue and select a
later split-import or bridge-readiness direction before any additional
mechanical import movement. A next implementation slice should be scoped around
one behavior surface at a time, with focused evidence for parser/output,
runtime compatibility, event replay, prompt/classifier, or test-policy behavior
as appropriate.

## Changed-Path Evidence

Implementation-owned changes are limited to round-103 artifacts:

- `orchestrator/rounds/round-103/core-ids-remaining-blocker-readiness.md`
- `orchestrator/rounds/round-103/implementation-notes.md`

Pre-existing round-103 artifacts and controller state were present before this
implementation:

- `orchestrator/rounds/round-103/plan.md`
- `orchestrator/rounds/round-103/selection.md`
- `orchestrator/state.json`

No source, test, app, package descriptor, roadmap, public facade, fixture,
docs, runtime compatibility, or behavior file was edited by this round.
Package build/test baselines are therefore skipped under the artifact-only
allowance in the active verification bundle.
