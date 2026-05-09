### Goal

Produce source-backed migration-readiness evidence for the `CodexWatcher.AppServerClient` compatibility facade without changing production imports, module exposure, app-server behavior, runtime compatibility behavior, publication state, or removal/deprecation policy.

The round should leave a reviewed evidence artifact under `orchestrator/rounds/round-061/` that records the refreshed import count, groups every current caller by client, transport, and parser ownership, reads back the current app-server client behavior tests, proves replacement module exposure, and names the dry-run migration blockers for a later selected cleanup round.

### Approach

Keep this as a sequential evidence-only round. Do not fan out workers: the work is one compatibility surface, the ownership grouping depends on a single import inventory, and the final readiness/blocker classification should be internally consistent rather than stitched from parallel partial reports.

Use `orchestrator/project-contract.md` as the invariant source for compatibility facades, package/module ownership, dry-run request rendering, action ordering, request-id progression, and baseline verification. Use the active verification bundle's `CodexWatcher.AppServerClient` task-specific checks as the acceptance gate.

The evidence should distinguish these ownership buckets:

- Client/parser ownership: values and helpers from `CodexWatcher.Workflow.Agent.Codex.Client`, including `AppServerTurn`, `AppServerClientFailure`, JSON-RPC errors, parse helpers, thread-read materialization fallback helpers, and failure formatting.
- Transport/session ownership: values and helpers from `CodexWatcher.Workflow.Agent.Codex.Transport`, including `AppServerEndpoint`, `AppServerClientOptions`, endpoint sessions, websocket send/read helpers, `startThreadWithEndpoint`, `startThreadWithInterpreter`, and endpoint-backed interpreters.
- Protocol/request ownership: request rendering remains in `CodexWatcher.AppServerProtocol` and typed adapter request mapping remains in `CodexWatcher.Workflow.Agent.Codex.Protocol`; record any caller that would need those modules during a later import migration, but do not migrate imports in this round.
- Product-policy ownership: moifold daemon, healthcheck, CLI, lifecycle, classifier, and runtime policy modules may still consume the facade until a later round explicitly migrates imports and proves parity.

### Steps

1. Create one evidence artifact, `orchestrator/rounds/round-061/app-server-client-migration-readiness.md`.
2. Refresh the selected-facade import inventory with an anchored import scan across source, tests, examples, standalone package candidates, docs, README files, Cabal descriptors, and app files:

   ```sh
   rg -n '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
   rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | wc -l
   ```

   Record the command, count, and file list. At planning time the scan finds 28 import statements/files; the implementation must refresh this count from the current tree and not rely on the plan's snapshot.
3. Add a broader reference scan for public and downstream/operator evidence:

   ```sh
   rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test app
   ```

   Classify each reference as observed usage, documentation/policy evidence, replacement guidance, package exposure, or non-user test assertion. If an expected downstream/operator source is unavailable in this checkout, record it as unavailable, not as removal approval.
4. Group current import callers by likely replacement ownership. Use the import list plus local symbol usage to classify each file into client/parser, transport/session, protocol/request, and product-policy categories. It is acceptable for one file to appear in multiple categories when it imports the facade unqualified and uses both parser and transport symbols. Name the concrete symbols or behavior that drove the grouping.
5. Read back the facade and replacement implementation shape:

   - `src/CodexWatcher/AppServerClient.hs` should remain a compatibility module reexporting `CodexWatcher.Workflow.Agent.Codex.Client` and `CodexWatcher.Workflow.Agent.Codex.Transport`.
   - `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs` should own response parsing, turn materialization, JSON-RPC matching/errors, thread/turn parsing, fallback markers, and failure formatting.
   - `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs` should own websocket transport, endpoint/session handling, initialize/initialized sequencing, timeouts, fallback send, and endpoint-backed interpreters.
   - `agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs` should own typed agent request mapping.

6. Prove replacement module exposure without changing Cabal files. Read back `moifold.cabal` and `agent-workflow-codex/agent-workflow-codex.cabal` to show that the moifold main library still exposes `CodexWatcher.AppServerClient`, while `agent-workflow-codex` exposes `CodexWatcher.Workflow.Agent.Codex.Client`, `CodexWatcher.Workflow.Agent.Codex.Protocol`, and `CodexWatcher.Workflow.Agent.Codex.Transport`.
7. Read back the current behavior coverage protecting the app-server client and typed Codex adapter. Include at least:

   - `test/AppServerSpec.hs` properties for JSON-RPC request shape, initialize/initialized handling, thread/start and turn/start parsing, thread/read parsing, mismatched response ids, JSON-RPC errors, materialization fallback, unsupported versions, and `startThreadWithInterpreter`.
   - `test/Main.hs` registrations around `workflowMoifoldCabalLibraryDoesNotReexportAdapters`, `workflowAgentCodexStartRequestsMatchCompiledEffects`, `workflowAgentCodexStartsThreadsThroughTypedAdapter`, and `workflowAgentCodexParsesTurnLifecycle`.
   - Any dry-run/request-id/action-ordering tests whose evidence is needed for migration blockers, especially app-server request-id progression and typed request parity.

8. Record dry-run migration readiness and blockers. The expected conclusion should be evidence-based, not policy approval: replacement modules are exposed and behavior tests exist, but production import migration remains blocked on per-caller import rewrites, focused parity readback after rewrites, public/downstream confirmation, and a later selected round authorizing any facade narrowing, deprecation, or Cabal exposure change.
9. Keep the diff limited to the round evidence artifact and implementation notes when the implementer runs. Do not edit `orchestrator/state.json`, roadmap files, source modules, tests, docs outside the round, Cabal descriptors, runtime compatibility files, review artifacts, or merge artifacts.

### Verification

Run artifact and scope checks:

```sh
git diff --name-only
git status --short
git diff --check
```

The changed files should be limited to `orchestrator/rounds/round-061/app-server-client-migration-readiness.md` and the round-level implementation notes produced by the implementer. If any production source, tests, docs outside the round, Cabal descriptors, roadmap files, `orchestrator/project-contract.md`, or `orchestrator/state.json` change, the round has escaped this plan.

Run the evidence scans and include their refreshed output summaries in the implementation notes:

```sh
rg -n '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal
rg -l '^ *import +(qualified +)?CodexWatcher\.AppServerClient(\b| +as +| *$| *\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github README.md docs *.cabal */*.cabal | wc -l
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' README.md docs examples *.cabal */*.cabal agent-workflow-core agent-workflow-codex agent-workflow-github src test app
rg -n 'CodexWatcher\.AppServerClient|CodexWatcher\.Workflow\.Agent\.Codex\.(Client|Transport|Protocol)' moifold.cabal agent-workflow-codex/agent-workflow-codex.cabal
```

Because this is evidence-only, the implementer may skip `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh` only if the diff remains limited to round-local orchestrator artifacts. If the diff touches any production code, tests, package descriptors, public docs, scripts, or runtime compatibility files, require the full baseline from `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`.

### Worker Fan-Out

Worker fan-out is not used. No `worker-plan.json` should be written for this round.
