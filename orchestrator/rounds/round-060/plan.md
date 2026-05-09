### Goal
Produce source-backed evidence for the `CodexWatcher.Core.Ids` split-import ownership question without changing public facades, Cabal exposure, production imports, runtime compatibility files, roadmap files, or `orchestrator/state.json`.

The round should refresh the recursive import scan, prove current package-boundary exposure for the combined facade and split replacement modules, map agent-id ownership separately from GitHub-id ownership, and record migration risks or blockers for later cleanup decisions.

### Approach
Keep the work sequential. This is one evidence artifact over one compatibility facade, and the ownership split only becomes meaningful after a single implementer reconciles the import scan, Cabal exposure, docs references, and risk map into one consistent record.

Use `orchestrator/project-contract.md` for the shared package-boundary and compatibility-facade invariants. Use the active verification contract for the task-specific scan requirements: source, tests, examples, package docs, Cabal descriptors, public package docs, and downstream/operator evidence where available.

The expected implementation output is a round-local evidence artifact, preferably `orchestrator/rounds/round-060/core-ids-split-import-evidence.md`, plus normal implementation notes. Do not add deprecation pragmas, narrow or remove `CodexWatcher.Core.Ids`, change exposed modules, migrate production imports, edit event/runtime compatibility surfaces, update docs policy, or claim removal approval.

### Steps
1. Confirm the current facade shape by reading `src/CodexWatcher/Core/Ids.hs`, `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs`, and `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`. Record that `CodexWatcher.Core.Ids` is a combined moifold facade over agent ids and GitHub ids.
2. Refresh the anchored recursive Haskell import scan for `CodexWatcher.Core.Ids` across `src`, `app` if present, `test`, `examples`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`. Group every importer by ownership area: app-server/agent identifiers, GitHub identifiers, mixed agent+GitHub use, moifold lifecycle/runtime glue, tests, and examples.
3. Refresh replacement-module scans for `CodexWatcher.Workflow.Agent.Ids` and `CodexWatcher.Workflow.GitHub.Ids` across the same source areas. Record where split imports are already used and whether reusable packages avoid importing the combined moifold facade.
4. Scan package docs, public docs, examples, README files, and Cabal descriptors for the combined facade and both split modules. Include `README.md`, `docs`, `examples`, `*.cabal`, `*/*.cabal`, `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`.
5. Record current package-boundary exposure assertions:
   - `moifold.cabal` exposes `CodexWatcher.Core.Ids`.
   - `agent-workflow-codex/agent-workflow-codex.cabal` exposes `CodexWatcher.Workflow.Agent.Ids`.
   - `agent-workflow-github/agent-workflow-github.cabal` exposes `CodexWatcher.Workflow.GitHub.Ids`.
   - reusable package source should import split id modules directly rather than depending on the moifold facade.
6. Build an ownership map from current exports:
   - Agent-id ownership: `RequestId`, `ThreadId`, `TurnId`, and `nextRequestId` belong to `CodexWatcher.Workflow.Agent.Ids`.
   - GitHub-id ownership: `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `ReviewThreadId`, and `CommitSha` belong to `CodexWatcher.Workflow.GitHub.Ids`.
   - Mixed import sites should be listed explicitly as later migration risks because they cannot be replaced by one split import.
7. Compare the refreshed evidence against prior round-054/round-056 claims only as historical context. If counts differ, prefer the current scan and explain the delta from current files rather than preserving old numbers.
8. Record migration risks and blockers conservatively: mixed agent/GitHub import sites, broad unqualified imports, tests that compile through the facade, downstream/operator references that are unavailable or unverified, and any public docs that still describe the facade as supported. Do not turn these risks into policy or removal approval.
9. Review the final diff for scope. It should contain only round-local planner/implementation evidence artifacts for round 060. Any source, Cabal, roadmap, project-contract, state, runtime compatibility, or public-facade diff should be treated as scope drift unless a reviewer explicitly sends the round back with a narrower request.

### Verification
Record the task-specific evidence commands and their results in the evidence artifact or implementation notes:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.Core\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n '^ *import +(qualified +)?CodexWatcher\.Workflow\.(Agent|GitHub)\.Ids(\b| +as +| *$)' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github
rg -n 'exposed-modules|other-modules|CodexWatcher\.(Core\.Ids|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids)' *.cabal */*.cabal
```

If a path such as `app` is absent, record that absence and rerun the command over the existing path set rather than treating it as a failure.

Because this round is evidence-only and should not change source, tests, Cabal descriptors, or docs policy, the minimum final verification is:

```sh
git diff --check
```

Run the roadmap baseline only if the implementation diff escapes round-local orchestrator evidence artifacts:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
```

If files are staged later in the round, also run:

```sh
git diff --cached --check
```
