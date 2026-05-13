### Goal

Migrate `test/ObserveCommandSpec.hs` off the combined `CodexWatcher.Core.Ids`
compatibility facade for its existing id imports, using direct owner modules for
GitHub and Codex app-server ids while preserving the current observe-command
behavior coverage.

### Approach

Make a one-file import-only change in `test/ObserveCommandSpec.hs`. Replace the
single `CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..),
unThreadId)` import with:

- `CodexWatcher.Workflow.GitHub.Ids (RepoName (..))`
- `CodexWatcher.Workflow.Agent.Ids (ThreadId (..), TurnId (..), unThreadId)`

Do not rewrite test bodies, helpers, assertions, package descriptors, public
facades, docs, runtime compatibility files, or broader `Core.Ids` users. This
round is import convergence only; it does not approve deprecation, exposed-module
cleanup, or facade removal. No worker fan-out is justified because the selected
slice has one file, one ownership boundary, and no integration split.

### Steps

1. Open `test/ObserveCommandSpec.hs` and edit only the import block.
2. Remove the `CodexWatcher.Core.Ids` import that currently provides
   `RepoName`, `ThreadId`, `TurnId`, and `unThreadId`.
3. Add the direct `CodexWatcher.Workflow.GitHub.Ids` import for
   `RepoName (..)`.
4. Add the direct `CodexWatcher.Workflow.Agent.Ids` import for
   `ThreadId (..)`, `TurnId (..)`, and `unThreadId`.
5. Leave all observe execute, dry-run, configured-endpoint, planner-thread,
   event-log, and app-server request assertions unchanged.
6. Confirm no other files were intentionally changed and no worker plan was
   created.

### Verification

- Run `git diff -- test/ObserveCommandSpec.hs` and confirm the diff is limited
  to the import migration.
- Run `rg -n "CodexWatcher\\.Core\\.Ids" test/ObserveCommandSpec.hs` and
  confirm there is no remaining `Core.Ids` import in the selected file.
- Run `cabal test watcher-core-test` to preserve the observe-command assertions
  and the shared watcher-core behavior surface.
- Run `git diff --check`.
- Do not stage; `git diff --cached --check` is not required unless a later role
  stages changes.
