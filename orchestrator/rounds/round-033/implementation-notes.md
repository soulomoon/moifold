### Changes Made
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs`: added `Ord` instances to GitHub identifier newtypes so the adapter-owned IDs have stable comparison behavior.
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Command.hs`: exported adapter-owned JSON field lists for issue view, PR view, PR lists, and checks; command specs now render those lists through a single helper.
- `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Remote.hs`: treats non-empty `mergedAt` as merged remote PR metadata in `remotePullRequestIsMerged`, matching the healthcheck and daemon callers' remote metadata contract.
- `src/CodexWatcher/GhGit.hs`: switched issue/PR view runtime calls to the adapter-owned field lists while keeping lifecycle execution in the main library facade.
- `src/CodexWatcher/Healthcheck.hs`: uses the adapter-owned PR merge metadata field list and merged classifier; healthcheck inventory/reporting policy remains in the main library.
- `test/GhGitSpec.hs`: expanded parser coverage for unknown issue/PR states, PR view mergeCommit object/string/null shapes, `mergedAt`, nullable head/review fields, merge-state classification, PR create status normalization/rejection, checks table fallback, review-thread comment fallbacks, and git output trimming.
- `test/RuntimeSpec.hs`: added focused runtime rendering checks for review-thread GraphQL query/resolve commands and PR merge flags; existing push no-force checks remain unchanged.
- `test/Main.hs`: wired the new focused tests into `watcher-core-test`, extended GitHub command facade parity to the adapter-owned field lists, and hardened the recursive `agent-workflow-github/src` boundary scan for moifold state-machine, daemon, lifecycle, runtime, healthcheck, repair, app-server/Codex, event-log, and compatibility ownership leaks.

### Tests
- `test/GhGitSpec.hs`: verifies adapter remote metadata parsers and classifiers for the touched GitHub ID/remote surfaces.
- `test/RuntimeSpec.hs`: verifies adapter-owned GitHub command rendering surfaces still match expected runtime command shape for GraphQL, merge flags, checks, PR views, and git push behavior.
- `test/Main.hs`: verifies command facade parity and recursive `agent-workflow-github` package-boundary rules.
- `cabal test watcher-core-test`: passed.
- `cabal build all`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed; no files are staged.

### Notes
The worktree already had `orchestrator/state.json` modified before implementation started. I did not edit it, did not edit roadmap files, did not stage files, and did not merge.
