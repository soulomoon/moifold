### Goal
Migrate the smallest behavior-neutral internal `CodexWatcher.AppServerClient` import slice to direct owner modules while keeping `CodexWatcher.AppServerClient` exposed, available, and unchanged as a compatibility facade.

This round should reduce internal facade usage only where the replacement is mechanically clear from round 075 and round 076: app-server protocol parsing and failure values come from `CodexWatcher.Workflow.Agent.Codex.Client`; endpoint/session/transport values come from `CodexWatcher.Workflow.Agent.Codex.Transport`. It must not approve deprecation, removal, Cabal exposure changes, docs/release wording, or downstream/public API policy.

### Approach
Use a single sequential implementer pass. Worker fan-out is not justified because the migration is import-only, the files are small, and one implementer can keep the replacement mapping consistent without integration overhead.

Keep the slice to explicit import-list sites plus the focused app-server behavior spec:

- Move endpoint-only imports to `CodexWatcher.Workflow.Agent.Codex.Transport`.
- Move `AppServerClientFailure`, `JsonRpcError`, `AppServerTurn`, and `formatAppServerClientFailure` imports to `CodexWatcher.Workflow.Agent.Codex.Client`.
- Split `test/AppServerSpec.hs` away from the facade so the app-server parsing, session, materialization fallback, request-id mismatch, JSON-RPC failure, and thread/turn parsing checks exercise the direct owner modules.
- Leave broad `import CodexWatcher.AppServerClient` sites for a later round unless a touched file requires a local explicit split to compile.
- Do not edit `src/CodexWatcher/AppServerClient.hs`, any `.cabal` file, docs, README, release notes, runtime compatibility files, event JSON, healthcheck behavior, or repair behavior.

### Steps
1. Confirm the starting inventory with `rg -n "^import (qualified )?CodexWatcher\\.AppServerClient\\b" src app test agent-workflow-* examples` and keep the count in implementation notes.
2. In these endpoint-only source/test files, replace the facade import with `CodexWatcher.Workflow.Agent.Codex.Transport` preserving the same explicit import lists:
   - `src/CodexWatcher/AutomaticLoop/IssuePlanningFanout.hs`
   - `src/CodexWatcher/AutomaticLoop/PrReviewHandoff.hs`
   - `src/CodexWatcher/Cli/Command/RunnerGuard.hs`
   - `src/CodexWatcher/Cli/Command/Service.hs`
   - `src/CodexWatcher/Cli/Parser/Common.hs`
   - `src/CodexWatcher/Cli/Types.hs`
   - `src/CodexWatcher/Healthcheck/Types.hs`
   - `test/CliSpec.hs`
3. In these client-value source files, replace the facade import with `CodexWatcher.Workflow.Agent.Codex.Client` preserving the same explicit import lists:
   - `src/CodexWatcher/AutomaticLoop/StartupThreads.hs`
   - `src/CodexWatcher/DaemonLoop.hs`
   - `src/CodexWatcher/DaemonLoop/Types.hs`
   - `src/CodexWatcher/Failure.hs`
   - `src/CodexWatcher/Workflow/DocsMigration.hs`
   - `src/CodexWatcher/Workflow/Moifold/PrReview/Agent.hs`
4. Update `test/AppServerSpec.hs` to import direct owner modules instead of `CodexWatcher.AppServerClient`:
   - Import parsing/failure/turn APIs from `CodexWatcher.Workflow.Agent.Codex.Client`.
   - Import session/start-thread APIs from `CodexWatcher.Workflow.Agent.Codex.Transport`.
   - Keep `CodexWatcher.AppServerProtocol` separate and unchanged.
5. Compile-check the changed imports and adjust only import lists needed by the selected files. Do not broaden to unrelated broad-import sites just to chase the global count.
6. Re-run the import inventory and record which `CodexWatcher.AppServerClient` imports remain. The expected remaining imports are the broad source/test imports and any explicit sites intentionally deferred because they were outside this slice.
7. Write `orchestrator/rounds/round-077/implementation-notes.md` with the changed paths, direct replacement mapping, remaining facade import count, confirmation that the facade module and Cabal exposure were untouched, and validation results.

### Verification
Run focused validation first:

- `rg -n "^import (qualified )?CodexWatcher\\.AppServerClient\\b" src app test agent-workflow-* examples`
- `rg -n "CodexWatcher\\.Workflow\\.Agent\\.Codex\\.(Client|Transport)" src test`
- `cabal test watcher-core-test`

Also run the roadmap baseline checks that apply to source/test edits:

- `cabal build all`
- `git diff --check`

Do not run `git diff --cached --check` unless the implementer stages files. If either Cabal command is too slow or blocked by the environment, record the exact command, failure/blocker, and any narrower compile/test command that was successfully run.

Reviewers should specifically confirm:

- `src/CodexWatcher/AppServerClient.hs` remains a live compatibility reexport.
- No `.cabal`, docs, README, release metadata, runtime compatibility file, event JSON, healthcheck, repair, deprecation, or removal decision changed.
- `test/AppServerSpec.hs` now protects app-server protocol parsing, endpoint/session initialization, materialization fallback, request-id mismatch, JSON-RPC failure formatting, timeout/failure formatting where covered, and thread/turn parsing through direct owner imports.
- Any remaining facade imports are recorded as deferred migration work, not used as evidence for removal approval.

### Worker Fan-Out
No worker fan-out. This is a single sequential import migration slice with overlapping validation and no non-overlapping ownership boundary that would justify parallel workers.
