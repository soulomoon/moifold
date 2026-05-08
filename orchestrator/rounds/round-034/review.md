### Checks Run

- Command: `git diff --check`
  Result: pass. No whitespace diagnostics.

- Command: `git diff --cached --check`
  Result: pass. No staged diff and no whitespace diagnostics.

- Command: `git diff --no-index --check /dev/null docs/agentic-workflow-framework/implemented-api-freeze.md`
  Result: pass for whitespace. The command produced no diagnostics; exit code 1 is the expected `--no-index` difference status for a new file.

- Command: `git status --short`
  Result: pass. Scope is limited to docs, the new round artifacts, and controller state: `docs/agentic-workflow-framework/README.md`, `agent-turn-contract.md`, `event-log-and-transactions.md`, `extraction-plan.md`, `monad-dsl.md`, `workflow-spec.md`, new `implemented-api-freeze.md`, optional `docs/correctness-model.md`, `orchestrator/state.json`, and `orchestrator/rounds/round-034/`.

- Command: `git diff --name-only`
  Result: pass for tracked scope. Tracked changes are only framework docs, optional `docs/correctness-model.md`, and `orchestrator/state.json`; no Haskell source, Cabal file, tests, fixtures, or roadmap files are modified.

- Command: `git ls-files --others --exclude-standard`
  Result: pass for untracked scope. Untracked files are `docs/agentic-workflow-framework/implemented-api-freeze.md` and expected round artifacts under `orchestrator/rounds/round-034/`.

- Command: `rg -n "^library agent-workflow-(core|codex|github)|^  exposed-modules:|^    CodexWatcher|^    Paths_" moifold.cabal`
  Result: pass. `moifold.cabal` exposes 13 `agent-workflow-core` modules, 10 `agent-workflow-codex` modules, and 3 `agent-workflow-github` modules; the new API-freeze page names the same exposed modules.

- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Reviewed stable ownership invariants: framework packages own generic kernel/adapter contracts; moifold owns issue/PR lifecycle policy, daemon ownership, process execution, filesystem writes, compatibility snapshots, healthcheck, repair, and publication/deprecation policy.

- Command: `sed -n '1,280p' orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/verification.md`
  Result: pass. Reviewed extraction-readiness override and manual docs checks. Cabal build/test are not required for this docs-only round because no Haskell, Cabal, test, fixture, or generated non-doc files changed beyond orchestrator state/artifacts.

- Command: `rg -n "^(data|newtype|class|type) |^[a-z][A-Za-z0-9_']* ::|^[a-z][A-Za-z0-9_']* =|^pattern |^module " agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs agent-workflow-core/src/CodexWatcher/Workflow/Codec.hs agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/EventLog/File/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/EventLog/Commit/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/Permission/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/Transaction/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs agent-workflow-core/src/CodexWatcher/Workflow/Daemon/Core.hs agent-workflow-core/src/CodexWatcher/Workflow/Failure.hs`
  Result: pass. Source inspection confirms the documented core API tokens: `WorkflowSpec`, `PlannedTransition`, indexed spec/existentials/bridge, pure `WorkflowM`/`Transition`, codec contracts, replay/commit helpers, execution metadata, permission policy, transaction failure stages, audit, daemon projections, and failure classification.

- Command: `rg -n "^(data|newtype|class|type) |^[a-z][A-Za-z0-9_']* ::|^[a-z][A-Za-z0-9_']* =|^module " agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Ids.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Types.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Client.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Interpreter.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Protocol.hs agent-workflow-codex/src/CodexWatcher/Workflow/Agent/Codex/Transport.hs agent-workflow-codex/src/CodexWatcher/Workflow/Observation/Agent.hs`
  Result: pass. Source inspection confirms the documented Codex adapter API tokens: typed ids, role metadata, retry and side-effect scope, thread/turn plans, `AgentRole`, app-server protocol/client/interpreter/transport helpers, and observation bridge.

- Command: `rg -n "^(data|newtype|class|type) |^[a-z][A-Za-z0-9_']* ::|^[a-z][A-Za-z0-9_']* =|^module " agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Ids.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Remote.hs agent-workflow-github/src/CodexWatcher/Workflow/GitHub/Command.hs`
  Result: pass. Source inspection confirms the documented GitHub adapter API tokens: typed GitHub ids, remote issue/PR/check/review-thread parsers and classifiers, branch/SHA parsers, merge-state helpers, and pure command specs.

- Command: `sed -n '6990,7868p' test/Main.hs`
  Result: pass. Representative assertions cover package boundaries, forbidden imports/ownership tokens, compatibility facade availability, healthcheck read-only behavior, and GitHub command rendering parity.

- Command: `sed -n '1,220p' test/AppServerSpec.hs`
  Result: pass. Representative assertions cover Codex app-server request construction and parser behavior.

- Command: `sed -n '1,260p' test/GhGitSpec.hs`
  Result: pass. Representative assertions cover GitHub issue/PR/check/review-thread parser behavior and git branch/SHA parser behavior.

- Command: `rg -n "\b(should|eventual|future|publish|publication|Cabal cleanup|package-readiness|readiness report|deprecat|facade removal|lifecycle policy|healthcheck|repair|compatibility|runtime ownership|liftIO|YAML|generic prompt)\b" docs/agentic-workflow-framework docs/correctness-model.md`
  Result: pass. Future/design language remains either in `extraction-plan.md`, which is now explicitly historical migration background, or is explicitly labelled deferred/future. Current implemented-contract docs do not imply package publication, Cabal readiness, compatibility facade removal, or lifecycle policy migration into the framework.

### Plan Compliance

- Inspect implemented surface before editing docs: met. The exposed modules in `moifold.cabal`, listed core/Codex/GitHub source modules, and representative tests were reviewed against the docs.
- Add or update one thesis-first contract page: met. `docs/agentic-workflow-framework/implemented-api-freeze.md` records the implemented internal API freeze and groups modules by responsibility.
- Record moifold-owned surfaces outside the reusable framework: met. The freeze page explicitly leaves concrete `WatcherEvent`, `SomeWatcherState`, Aeson event codecs, golden replay policy, issue/PR lifecycle, prompts, compatibility files, filesystem/process/runtime ownership, healthcheck, repair, daemon loops, publication, and compatibility-facade removal in moifold.
- Update framework README: met. The README now distinguishes implemented contract pages from historical migration background and preserves the typed-protocol thesis.
- Align `workflow-spec.md`: met. It describes the current associated-type `WorkflowSpec`, `PlannedTransition`, indexed spec, existentials, bridge, laws, and deferred richer domain/phase design.
- Align `monad-dsl.md`: met. It describes the implemented pure `WorkflowM`, `Transition`, `emit`, `failWorkflow`, `advance`, `transitionFromPlan`, transition accessors, no-`liftIO` boundary, and permission validation ownership.
- Align `event-log-and-transactions.md`: met. It documents codec, line decoding, replay, commit, execution metadata, permission, transaction, failure-stage, audit, and daemon projection contracts while leaving concrete event-log IO and repair policy in moifold.
- Align `agent-turn-contract.md`: met. It documents typed role ids, start/read/interrupt data, retries, side-effect scope, app-server protocol/client/interpreter/transport helpers, turn refs, and the observation bridge while leaving role prompts, schemas, evidence, and lifecycle decisions in moifold.
- Document GitHub adapter surface: met. The API-freeze page covers `GitHubCommandSpec`, typed ids, remote parsers/classifiers, merge-state helpers, branch/SHA parsing, and pure command rendering; it leaves command execution timing and irreversible lifecycle policy in moifold.
- Keep navigation minimal and avoid out-of-scope edits: met. Only `docs/correctness-model.md` gained a short link. No root README, Haskell source, Cabal files, tests, golden fixtures, compatibility facades, or roadmap files were changed. `orchestrator/state.json` is present as controller state for the active review round and was not modified by this review.
- Review tense and claims: met. The older extraction plan is marked historical; implemented pages use current-contract language; deferred/future language is explicitly scoped.

### Decision

**APPROVED**

### Evidence

The integrated result is docs-only apart from orchestrator state/artifacts. The tracked diff touches only `docs/agentic-workflow-framework/`, optional `docs/correctness-model.md`, and `orchestrator/state.json`; untracked files are the new API-freeze doc and expected round artifacts.

The new API-freeze page matches the current exposed-module lists for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`. Direct source inspection confirmed the documented APIs exist in the listed modules, including the workflow spec/bridge, DSL, codec/replay/commit/execution/permission/transaction/audit/daemon surfaces, Codex adapter protocol/client/interpreter/transport surfaces, and GitHub ids/remote/command surfaces.

The docs satisfy the project contract and roadmap non-goals. They keep `State -> Event -> Decision -> EffectPlan -> Interpreter`, event logs as truth, classified agent observations before durable events, effect plans as inspectable data, and no workflow `liftIO`. They explicitly keep lifecycle policy, runtime ownership, daemon loops, process/filesystem IO, healthcheck, repair, compatibility snapshots/file names, prompt/schema policy, package publication, deprecation, and compatibility-facade removal in moifold.

No Cabal build or test run was required by the round instructions because no Haskell source, Cabal file, test, fixture, or generated non-doc implementation file changed.
