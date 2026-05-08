### Checks Run
- Command: `cabal build all`
  Result: pass. Cabal reported `Up to date`, covering all internal libraries, executables, and tests under the current package split.
- Command: `cabal test watcher-core-test`
  Result: pass. The suite rebuilt `watcher-core-test` and finished with `Test suite watcher-core-test: PASS` and `1 of 1 test suites (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No whitespace errors reported; `git diff --cached --name-only` was empty.
- Command: `git diff --stat && git diff --name-status && git diff --cached --name-status`
  Result: pass for scope inspection. The implementation diff touches `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/{Command,Ids,Remote}.hs`, moifold facade/integration files `src/CodexWatcher/{GhGit,Healthcheck}.hs`, focused tests `test/{GhGitSpec,RuntimeSpec,Main}.hs`, and the pre-existing orchestrator `state.json` review-state diff. No staged files were present.
- Command: `rg -n "^import |CodexWatcher\\." agent-workflow-github/src`
  Result: pass for adapter import inspection. The adapter source imports only its own GitHub id module plus library dependencies.
- Command: `rg -n "CodexWatcher\\.(AppServer|AppServerClient|AppServerProtocol|ChildDaemon|Cli|Core\\.|Daemon|DaemonLoop|Domain|EffectInterpreter|Effects|EventLog|EventLogRepair|GhGit|Healthcheck|Json|Logging|Observation|Runtime|StateMachine|Supervisor|Turn|TurnOutput|WatcherLiveness|WatcherRuntimeStatus|Workflow\\.(Agent|Daemon|EventLog|Execution|Moifold|Observation|Permission|Transaction|Types))|WatcherEvent|SomeWatcherState|RuntimeCommand|RuntimeInterpreter|CommandReport|IssueConfig|PrConfig|ReviewEvidence|CleanReviewEvidence|Healthcheck|EventLogRepair|runtime-owner|daemon-state\\.json|issue-state\\.json|planning-state\\.json|watcher-state\\.json|block-state\\.json|app-server" agent-workflow-github/src`
  Result: pass. `rg` found no forbidden moifold lifecycle, daemon, runtime, healthcheck, repair, app-server, event-log, or compatibility ownership tokens in `agent-workflow-github/src`.
- Command: direct source inspection with `git diff -- ...`, `nl -ba ...`, and `rg -n ...` over `moifold.cabal`, touched `agent-workflow-github` modules, `src/CodexWatcher/GhGit.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/Runtime/Command/{Render,Types}.hs`, `src/CodexWatcher/Core/Ids.hs`, `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, and `test/Main.hs`.
  Result: pass. The adapter API, moifold facades, command-rendering parity tests, parser coverage, healthcheck parity, and recursive boundary scan all match the selected round scope.

### Plan Compliance
- Step 1: met. `Ids.hs` keeps GitHub identifiers in the adapter and adds stable `Ord` instances for `RepoName`, `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha`; `Command.hs` exposes adapter-owned JSON field lists and pure command specs; `Remote.hs` keeps remote metadata parsing/classification in the adapter.
- Step 2: met. `Runtime.Command.Render` already routes pure GitHub/git command rendering through `CodexWatcher.Workflow.GitHub.Command`; `GhGit.hs` now consumes adapter-owned field lists; `Healthcheck.hs` now uses the adapter-owned merge metadata field list and merged classifier. `Core.Ids` remains a compatibility facade over adapter id modules.
- Step 3: met. `moifold.cabal` exposes only `CodexWatcher.Workflow.GitHub.Command`, `.Ids`, and `.Remote` for `library agent-workflow-github`, with dependencies limited to `aeson`, `base`, and `text`. No new package dependency or exposed module was added.
- Step 4: met. Production changes are narrow and adapter-owned: field-list constants, field rendering via `fieldsArg`, `Ord` instances, and `remotePullRequestIsMerged` recognizing non-empty stripped `mergedAt`. Moifold lifecycle commands such as issue creation, PR creation/body update, issue close, review-findings comments, and clean-review-and-merge scripts remain in the main library.
- Step 5: met. `test/GhGitSpec.hs` covers unknown issue/PR states, PR view `mergeCommit` object/string/null variants, `mergedAt`, nullable head/review fields, merge-state classification, PR-create status normalization/rejection, checks JSON/table fallback, review-thread author/comment URL fallbacks, and trimmed git output parsing.
- Step 6: met. `test/RuntimeSpec.hs` and `workflowGithubCommandFacadeMatchesRuntimeRender` cover structured PR view/list/check fields, review-thread GraphQL query/resolve/reply command shape, PR merge flags, and git push/dry-run command parity without force flags.
- Step 7: met. `Healthcheck.hs` consumes `ghPrViewMergeMetadataFields` and `remotePullRequestIsMerged`, so branch/head/remote SHA parser coverage in `GhGitSpec` plus PR merged metadata coverage exercises the exact parser/classifier path healthcheck depends on while leaving inventory/reporting policy in the main library.
- Step 8: met. `workflowGithubCabalSublibraryKeepsPackageBoundary` now recursively scans `agent-workflow-github/src` for forbidden imports and ownership tokens, not a hard-coded file list, and checks the cabal component boundary.
- Step 9: met. `GhGit.hs` remains an execution/parsing facade over adapter-owned remote parsers and field lists; `Core.Ids` remains a reexport compatibility facade over `Workflow.Agent.Ids` and `Workflow.GitHub.Ids`. No compatibility facade was removed.

### Decision
**APPROVED**

### Evidence
The round implements the selected GitHub adapter API stabilization without moving moifold lifecycle, daemon, runtime execution, filesystem/process ownership, healthcheck inventory policy, repair policy, or Codex/app-server ownership into `agent-workflow-github`.

Key evidence:
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Command.hs` owns the shared JSON field lists and pure command specs, including PR view metadata and checks fields.
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Remote.hs` owns the PR merged classifier and remote metadata parsers.
- `src/CodexWatcher/GhGit.hs` and `src/CodexWatcher/Healthcheck.hs` consume those adapter-owned helpers while keeping runtime execution and healthcheck reporting in moifold.
- `src/CodexWatcher/Runtime/Command/Render.hs` still converts adapter `GitHubCommandSpec` values into runtime command specs but keeps lifecycle shell scripts in the main library.
- `test/Main.hs` registers the new parser/rendering tests and recursively enforces the GitHub adapter package boundary.
- Baseline verification passed: `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
