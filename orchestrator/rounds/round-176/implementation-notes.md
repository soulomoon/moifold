### Changes Made
- `src/CodexWatcher/StateMachine.hs`: replaced the `CodexWatcher.Core.Ids` import with direct owner imports from `CodexWatcher.Workflow.GitHub.Ids` for `BranchName`, `CommitSha`, `IssueNumber`, `PrNumber`, and `ReviewThreadId`, and from `CodexWatcher.Workflow.Agent.Ids` for `ThreadId`.
- No function bodies, exports, constructors, validation logic, branch-attempt parsing/rendering, PR mismatch text, review-thread resolution, package descriptors, public facade modules, tests, docs, or roadmap files were changed.

### Tests
- `git diff --check`: passed.
- `rg -n "CodexWatcher\\.Core\\.Ids" src/CodexWatcher/StateMachine.hs || true`: produced no matches after the import migration.
- `rg -n "CodexWatcher\\.Core\\.Ids" src app test docs *.cabal agent-workflow-* || true`: still reports remaining users outside this selected file, including the public facade module/exposure, runtime compatibility, tests, CLI, event log, healthcheck, domain loops, docs, and package descriptor surfaces.
- `cabal build all` and `cabal test watcher-core-test` were not run in this implementer pass; leave the full roadmap baseline to the reviewer.

### Notes
This is import-only convergence work for round 176. `CodexWatcher.Core.Ids` remains available as a public compatibility facade, and remaining `Core.Ids` users are outside this round's scope. This round does not claim facade deprecation, removal, package exposure cleanup, milestone completion, or compatibility-surface approval.
