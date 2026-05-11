### Goal
Move the single production facade import in `src/CodexWatcher/Cli/Command/IssueFanout.hs` off `CodexWatcher.AppServerClient` and onto the direct Codex app-server owner modules, while preserving the round-125 app-server-backed issue-fanout behavior exactly.

This round is import-only. It must not change code bodies, tests, support modules, public facade exposure, direct owner client/transport/protocol implementations, Cabal descriptors, docs, fixtures, runtime compatibility files, roadmap files, `selection.md`, or `orchestrator/state.json`.

### Approach
Replace only the unqualified `import CodexWatcher.AppServerClient` line in `IssueFanout.hs` with explicit owner imports for the symbols already used by this module:

- `CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)`
- `CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..), defaultAppServerClientOptions, startThreadWithEndpoint)`

Keep `CodexWatcher.AppServerProtocol` and all other existing imports unchanged unless the compiler requires import-list formatting after the swap. The implementation must preserve the existing call sites for `startThreadWithEndpoint`, `defaultAppServerClientOptions`, and `formatAppServerClientFailure`, plus the existing `AppServerEndpoint` record field usage in launch modes and child argument rendering.

No worker fan-out is justified: the expected implementation is one sequential import-block edit in one production file, and fan-out would add coordination risk without a separable ownership boundary. Do not write `worker-plan.json`.

Reference `orchestrator/project-contract.md` for the stable compatibility and package-boundary invariants. This round records preferred production imports only; it is not deprecation, removal, Cabal exposure cleanup, milestone completion, or terminal completion for `CodexWatcher.AppServerClient`.

### Steps
1. Reconfirm controller selection and lineage before editing:
   - `jq '{roadmap_id, roadmap_revision, controller_stage, max_parallel_rounds, active_rounds}' orchestrator/state.json`
   - Confirm the active round is `round-126`, stage is plan/implementation handoff as expected, roadmap is `2026-05-11-00-highest-value-cleanup` `rev-001`, selected item is `round-126-issue-fanout-appserverclient-import-convergence`, and `max_parallel_rounds` is `1`.
2. Open `src/CodexWatcher/Cli/Command/IssueFanout.hs` and replace only:
   - `import CodexWatcher.AppServerClient`
   with:
   - `import CodexWatcher.Workflow.Agent.Codex.Client (formatAppServerClientFailure)`
   - `import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..), defaultAppServerClientOptions, startThreadWithEndpoint)`
3. Do not edit any function bodies. In particular preserve:
   - endpoint-backed `thread/start` launch behavior
   - request ids from `RequestId <$> [8000 ..]`
   - launch workdir `cwd` in `issueImplementerThreadStartOptions`
   - developer instruction context from `issueImplementerThreadDeveloperInstructions`
   - persisted manifest/config/event thread ids
   - child command rendering in `issueImplementerChildArgs`
   - retryable clone failure classification in `retryableLaunchCommandFailure`
   - fallback child-start ordering in `startIssueImplementerChildDetailed`
   - app-server failure formatting through `formatAppServerClientFailure`
4. Keep tests/support imports through `CodexWatcher.AppServerClient` untouched, including `test/IssueFanoutAppServerSpec.hs`, `test/TestSupport/AppServer.hs`, and the broad test-policy imports. Keep `src/CodexWatcher/AppServerClient.hs` unchanged and publicly exposed.
5. Prove the diff is import-only:
   - `git diff -- src/CodexWatcher/Cli/Command/IssueFanout.hs`
   - The only changed lines should be the removed facade import and the two added direct owner imports.
   - `git diff --name-only` should list only `src/CodexWatcher/Cli/Command/IssueFanout.hs` for implementation changes, aside from orchestrator artifacts owned by this round.
6. Prove no unauthorized files changed:
   - `git status --short`
   - Leave pre-existing unrelated orchestrator changes alone. Do not revert or rewrite edits made by other roles.

### Verification
Run the focused behavior gate first:

```sh
printf ':set -v0\n:m + IssueFanoutAppServerSpec\nissueFanoutAppServerTests\n:quit\n' | cabal repl watcher-core-test
```

Then run the required baseline gates:

```sh
cabal test watcher-core-test
cabal build all
git diff --check
```

If staging happens later, also run:

```sh
git diff --cached --check
```

Run import and ownership scans, and record the results in implementation notes:

```sh
rg -n "import CodexWatcher\\.AppServerClient" src/CodexWatcher/Cli/Command/IssueFanout.hs
rg -n "CodexWatcher\\.AppServerClient" src app test agent-workflow-codex agent-workflow-core agent-workflow-github moifold.cabal docs README.md
rg -n "startThreadWithEndpoint|defaultAppServerClientOptions|formatAppServerClientFailure|AppServerEndpoint" src/CodexWatcher/Cli/Command/IssueFanout.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs
```

Expected scan results:

- The first scan returns no matches, proving `IssueFanout.hs` no longer imports the facade.
- Remaining `CodexWatcher.AppServerClient` matches in tests, support, docs, Cabal exposure, and `src/CodexWatcher/AppServerClient.hs` are out of scope and must remain untouched.
- `IssueFanout.hs` still references the same app-server symbols, now supplied by direct owner imports.

Reviewers should reject the round if any behavior code, tests/support imports, public facade module, direct owner client/transport/protocol code, Cabal/API exposure, docs, fixtures, runtime compatibility files, roadmap files, `selection.md`, or `state.json` changed.

### Worker Fan-Out
No worker fan-out. Do not create `orchestrator/rounds/round-126/worker-plan.json`.
