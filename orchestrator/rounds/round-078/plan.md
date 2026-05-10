### Goal
Split a focused behavior-neutral set of internal `CodexWatcher.Core.Ids`
imports to the direct identifier owner modules, while keeping
`CodexWatcher.Core.Ids` exposed, available, and unchanged as the combined
moifold compatibility facade.

This round should migrate caller sites that only need one identifier owner:
`CodexWatcher.Workflow.Agent.Ids` for `RequestId`, `ThreadId`, `TurnId`, and
`nextRequestId`; `CodexWatcher.Workflow.GitHub.Ids` for `RepoName`,
`IssueNumber`, `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha`.
It must also record remaining legitimate combined-facade callers that still span
both owners. The result is internal import readiness evidence only, not
deprecation, public API, Cabal exposure, documentation, or facade removal
approval.

### Approach
Use a single sequential implementer pass. Worker fan-out is not justified
because this is an import-only migration with overlapping compile/test
validation, and a single implementer can keep the owner mapping and remaining
facade inventory consistent.

Use the round-060 split-import evidence and the current import scan as the
starting map, but refresh the scan before editing. Migrate only callers whose
current `Core.Ids` usage belongs to one owner. Leave mixed agent/GitHub callers
on `CodexWatcher.Core.Ids` and record them explicitly as legitimate combined
facade users. Do not edit `src/CodexWatcher/Core/Ids.hs`, split owner modules,
newtype constructors, parsers, renderers, command output, event schemas,
healthcheck, repair, runtime compatibility files, package descriptors, docs,
deprecation pragmas, Cabal exposure, public API, `CodexWatcher.AppServerClient`,
`CodexWatcher.Workflow.EventLog`, `CodexWatcher.Workflow.Permission`,
`CodexWatcher.Workflow.Types`, or `CodexWatcher.Workflow.Execution`.

### Steps
1. Confirm the active inputs: `orchestrator/state.json` selects round
   `round-078`, roadmap `2026-05-10-00-facade-removal-readiness` revision
   `rev-001`, and extracted item
   `round-078-core-ids-split-import-migration`; `selection.md` keeps the round
   limited to `CodexWatcher.Core.Ids` internal import migration.
2. Refresh the starting inventory with:
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
   Record the starting combined-facade count and current split-owner importers
   in `orchestrator/rounds/round-078/implementation-notes.md`.
3. Replace these agent-id-only imports with
   `CodexWatcher.Workflow.Agent.Ids`, preserving explicit import lists where
   present and making broad imports explicit enough to compile cleanly:
   - `src/CodexWatcher/AutomaticLoop/Runner.hs`
   - `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
   - `src/CodexWatcher/Cli/Command/AppServerProbe.hs`
   - `src/CodexWatcher/Core/Thread.hs`
   - `src/CodexWatcher/DaemonLoop.hs`
   - `src/CodexWatcher/DaemonLoop/ActiveTurn.hs`
   - `src/CodexWatcher/DaemonLoop/TurnStart.hs`
   - `src/CodexWatcher/Runtime/Defaults.hs`
   - `src/CodexWatcher/Workflow/DocsMigration.hs`
   - `src/CodexWatcher/Workflow/Moifold/IssuePlanning/Indexed.hs`
   - `test/AppServerSpec.hs`
4. Replace these GitHub-id-only imports with
   `CodexWatcher.Workflow.GitHub.Ids`, preserving explicit import lists where
   present and making broad imports explicit enough to compile cleanly:
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
   - `test/GhGitSpec.hs`
5. Leave mixed or broad combined-facade users unchanged when they currently need
   both agent and GitHub identifiers, and leave explicitly out-of-scope modules
   unchanged even if their current import is one-owner. At minimum, expect mixed
   callers such as CLI/runtime state, event-log/replay, healthcheck/runner-guard,
   issue and PR lifecycle loops, runtime compatibility, `test/CliSpec.hs`,
   `test/Main.hs`, and `test/RuntimeSpec.hs` to remain candidates for either a
   later two-import migration or a deliberate keep/defer decision. Also record
   `src/CodexWatcher/Workflow/Execution.hs` as deferred by selection boundary if
   it still imports `CodexWatcher.Core.Ids`.
6. Compile-check and adjust only imports in touched files. If a listed file no
   longer compiles with a single owner because current usage has drifted into
   mixed agent/GitHub identifiers, revert that file's import replacement in this
   round and record it as a legitimate combined-facade caller or deferred mixed
   caller.
7. Re-run the combined-facade and split-owner import scans from step 2. Record
   in implementation notes:
   - changed files and owner module chosen for each file;
   - final combined-facade import count;
   - remaining `CodexWatcher.Core.Ids` callers grouped as legitimate mixed
     combined-facade users, deferred broad users, and tests that still compile
     through the facade;
   - confirmation that `src/CodexWatcher/Core/Ids.hs`, Cabal files, docs,
     runtime compatibility files, command rendering, event schemas,
     healthcheck, repair, public API, deprecation, and facade removal were
     untouched.

### Verification
Run focused inventory and behavior checks first:

- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Core\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `rg -n "^ *import +(qualified +)?CodexWatcher\\.Workflow\\.(Agent|GitHub)\\.Ids(\\b| +as +| *$)" src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github`
- `cabal test watcher-core-test`

Also run the roadmap baseline checks that apply to source/test edits:

- `cabal build all`
- `git diff --check`

Do not run `git diff --cached --check` unless the implementer stages files. If
either Cabal command is too slow or blocked by the environment, record the exact
command, failure or blocker, and any narrower compile/test command that was
successfully run.

Reviewers should specifically confirm:

- `src/CodexWatcher/Core/Ids.hs` remains a live combined compatibility reexport.
- No newtype constructor, parser, renderer, command output, event schema,
  healthcheck, repair, runtime compatibility file, package descriptor, docs,
  deprecation pragma, Cabal exposure, public API, or facade removal changed.
- Touched parser/rendering and command-output-adjacent modules still compile
  through the same tests, especially branch names, commit shas, issue numbers,
  PR numbers, repo names, request ids, review thread ids, thread ids, turn ids,
  and request-id progression covered by `watcher-core-test`.
- Remaining `CodexWatcher.Core.Ids` imports are recorded as mixed/deferred
  compatibility-facade users, not as evidence that removal is approved.

### Worker Fan-Out
No worker fan-out. This is a single serial import migration with one shared
owner map and one shared validation pass; there is no non-overlapping ownership
boundary that would justify `worker-plan.json`.
