### Goal

Stabilize the `agent-workflow-github` adapter API surface so GitHub identifier types, remote metadata parsers, and pure GitHub/git command-rendering helpers are explicit, parity-tested against current moifold callers, and guarded by recursive boundary scans that keep moifold state-machine, daemon, lifecycle, filesystem, process, healthcheck, and repair policy outside the adapter package.

### Approach

Keep this round sequential. The selected item touches one adapter package plus its current moifold integration tests, and the active controller state has no concurrent batch; worker fan-out is not justified.

Use `orchestrator/project-contract.md` as the stable source for repo-wide event, dry-run, compatibility, and package-boundary invariants. Treat `agent-workflow-github` as the owner of GitHub ids, remote JSON/text parsing, remote metadata classification/rendering, review-thread metadata, and pure command specs for adapter-level `gh`/`git` operations. Keep concrete moifold issue/PR lifecycle scripts, daemon behavior, runtime execution, filesystem/process ownership, healthcheck inventory policy, and repair policy in the main library.

Prefer additive helper/API clarification and focused test/source-scan hardening over a broad move. Existing compatibility imports such as `CodexWatcher.Core.Ids` and `CodexWatcher.GhGit` may remain as main-library facades when they preserve callers without duplicating definitions or moving policy into the adapter.

### Steps

1. Inspect `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`, `Remote.hs`, and `Command.hs` for unstable or duplicated public API around `RepoName`, `IssueNumber`, `PrNumber`, `BranchName`, `CommitSha`, `ReviewThreadId`, remote issue/PR state rendering, merge-state classification, review-thread parsing, git output parsing, and `GitHubCommandSpec`.
2. Inspect current integration callers in `src/CodexWatcher/GhGit.hs`, `src/CodexWatcher/Runtime/Command/Render.hs`, `src/CodexWatcher/Runtime/Command/Types.hs`, `src/CodexWatcher/Healthcheck.hs`, `src/CodexWatcher/TurnOutput.hs`, and `src/CodexWatcher/Core/Ids.hs` to identify adapter-owned helpers that should be reused through `agent-workflow-github` without moving lifecycle-specific commands such as issue creation, PR creation/body update, issue close, review-findings comments, or clean-review-and-merge scripts into the adapter.
3. Tighten the exported API in `moifold.cabal` only as needed for `library agent-workflow-github`. Keep the exposed modules focused on `CodexWatcher.Workflow.GitHub.Command`, `.Ids`, and `.Remote` unless a new helper module is required; do not add dependencies beyond adapter-level parsing/rendering needs, and do not add dependencies on the main moifold library, `agent-workflow-core`, `agent-workflow-codex`, daemon/runtime packages, filesystem/process packages, CLI packages, or app-server transport.
4. If production code changes are needed, make them small and adapter-owned: move or add pure helpers for remote metadata parsing/classification/rendering or command specs in `agent-workflow-github`, then have moifold compatibility/integration code call those helpers. Leave moifold-owned runtime command constructors and effect/lifecycle scripts in `src/CodexWatcher/Runtime/Command/*` or the existing domain modules.
5. Add or refine focused parser tests in `test/GhGitSpec.hs` for every touched remote parser surface, including issue/PR list metadata, issue view closed-state defaults, PR view `mergeCommit` object/string/null shapes, `mergedAt`, `headRefOid`, `mergeStateStatus`, `reviewDecision`, PR create status normalization/rejection, checks JSON/table fallback, review-thread URL/comment/author fallback, git branch/SHA/ls-remote parsing, and unknown state preservation.
6. Add or refine command-rendering parity tests in `test/RuntimeSpec.hs` and/or the existing `workflowGithubCommandFacadeMatchesRuntimeRender` assertion in `test/Main.hs` so every adapter-owned `GitHubCommandSpec` still matches `renderRuntimeCommand`. Include the structured `gh pr view` and `gh pr checks` fields, review-thread GraphQL command shape, resolve/reply mutation commands, merge flag behavior, and git push/dry-run commands without force flags.
7. Add focused healthcheck/parser parity coverage where practical by extending parser tests or healthcheck tests for the exact metadata `Healthcheck.hs` consumes: branch, local HEAD SHA, remote branch SHA, PR merged detection via `state` and `mergedAt`, and remote PR error-tolerant parsing behavior. Keep healthcheck inventory/reporting policy in the main library.
8. Harden `workflowGithubCabalSublibraryKeepsPackageBoundary` in `test/Main.hs` so it recursively scans all `agent-workflow-github/src` source and rejects imports or source ownership leaks for moifold state-machine, daemon, lifecycle, domain, event-log, effects, runtime, filesystem/process, healthcheck, repair, app-server/Codex adapter, concrete `WatcherEvent`, concrete `SomeWatcherState`, and main-library compatibility modules. Keep the scan recursive rather than file-list based.
9. Review `src/CodexWatcher/GhGit.hs` and `src/CodexWatcher/Core/Ids.hs` after the changes to ensure they remain compatibility/integration facades over adapter-owned definitions, not parallel implementations. Do not remove compatibility facades in this round unless the local build and tests prove all current imports still work.

### Verification

- `cabal test watcher-core-test`
- `cabal build all`
- `git diff --check`
- `git diff --cached --check` if any files are staged during the round

Because `watcher-core-test` is a custom executable rather than a matcher-filtered suite, focused verification is by direct review of the named assertions in `test/GhGitSpec.hs`, `test/RuntimeSpec.hs`, and `test/Main.hs`. Review should also inspect `moifold.cabal`, `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/*.hs`, `src/CodexWatcher/GhGit.hs`, `src/CodexWatcher/Runtime/Command/Render.hs`, `src/CodexWatcher/Healthcheck.hs`, and the recursive boundary scan to confirm GitHub adapter ownership is explicit while moifold lifecycle policy remains in the main library.
