### Goal

Create package-facing documentation for the three reusable workflow package
candidates without changing package identity, source layout, release status, or
moifold ownership boundaries.

This round should leave reviewers with source-backed READMEs and Haddock-facing
module docs for:

- `agent-workflow-core`: the typed workflow kernel, replay, codec, permission,
  transaction, audit, daemon projection, and reusable failure-classification
  package.
- `agent-workflow-codex`: the Codex app-server protocol, typed agent adapter,
  client/protocol/interpreter/transport, and agent-observation bridge package.
- `agent-workflow-github`: the GitHub id, remote parser/classifier, and pure
  command-spec package.

The docs must make the thesis explicit: these packages expose typed workflow
protocol surfaces and adapter contracts; moifold remains the concrete product
that owns issue/PR lifecycle, event schemas, compatibility files, runtime
ownership, healthcheck, repair, prompts, release gates, and publication
decisions.

### Approach

Keep the implementation as a sequential docs pass. Worker fan-out is not
justified because the three package READMEs need shared wording and cross-links,
and the Haddock edits should be reviewed as one coherent public API boundary.

Use the existing source-backed docs as evidence, not as text to duplicate:

- `docs/agentic-workflow-framework/README.md` for the typed-control-plane
  thesis and document index.
- `docs/agentic-workflow-framework/implemented-api-freeze.md` for exposed API
  surfaces and moifold-owned policy.
- `docs/agentic-workflow-framework/package-extraction-readiness.md` for
  package readiness, dependency ownership, compatibility facades, boundary
  tests, and blockers.
- `docs/agentic-workflow-framework/package-identity-versioning-contract.md` for
  names, versions, module namespace policy, and release-gate limits.
- `docs/agentic-workflow-framework/release-metadata-policy.md` for metadata
  truth rules and wording constraints.
- `docs/agentic-workflow-framework/compatibility-deprecation-policy.md` for
  preferred imports and non-removal status.
- `docs/agentic-workflow-framework/package-validation.md` for repeatable
  package checks and no-upload validation.

Write package READMEs as thesis + architecture + guarantees:

- State what the package owns.
- State the shape of the public API by module group.
- State what the package deliberately does not own.
- Link to the evidence docs above.
- Say the package is a local external-package candidate and not a publication
  or upload claim.

Avoid examples, consumer guides, changelog text, release notes, upload language,
and package-public stability claims beyond the approved pre-1.0 candidate
contract.

### Steps

1. Create `agent-workflow-core/README.md`.
   - Anchor it on `State -> Event -> Decision -> EffectPlan -> Interpreter`.
   - Group the exposed modules from `agent-workflow-core/agent-workflow-core.cabal`:
     `Spec`, `Indexed.Spec`, `DSL`, `Codec`, `EventLog.*`, `Execution.Core`,
     `Permission.Core`, `Transaction.Core`, `Audit`, `Daemon.Core`, and
     `Failure`.
   - Document guarantees: pure replay, explicit observations, inspectable
     effect plans, permission validation before interpretation, event commit
     boundaries, stage-aware transaction failures, audit/daemon projections,
     and no concrete moifold event schema ownership.
   - Document non-goals: no Aeson event schema, no Codex/GitHub adapter
     ownership, no filesystem/runtime/process/healthcheck/repair ownership, no
     moifold lifecycle policy, no package publication claim.
   - Link to `docs/agentic-workflow-framework/workflow-spec.md`,
     `event-log-and-transactions.md`, `monad-dsl.md`,
     `implemented-api-freeze.md`, `package-extraction-readiness.md`, and
     `package-validation.md`.

2. Create `agent-workflow-codex/README.md`.
   - Describe the package as the typed Codex app-server adapter, not as
     moifold's prompt or app-server process policy.
   - Group the exposed modules from `agent-workflow-codex/agent-workflow-codex.cabal`:
     `CodexWatcher.AppServerProtocol`, `Workflow.Agent`, `Workflow.Agent.Ids`,
     `Workflow.Agent.Types`, `Workflow.Agent.Codex`, `Client`, `Interpreter`,
     `Protocol`, `Transport`, and `Workflow.Observation.Agent`.
   - Document guarantees: deterministic request construction, typed thread/turn
     ids, role metadata, retry metadata, classified app-server turns, response
     parsing, websocket transport ownership, endpoint-backed interpreter
     helpers, and explicit observation planning.
   - Document non-goals: no app-server startup or persistent-runtime policy,
     no role prompt policy, no structured-output compatibility policy, no
     issue/PR lifecycle decisions, no compatibility facade removal, no package
     publication claim.
   - Link to `docs/agentic-workflow-framework/agent-turn-contract.md`,
     `implemented-api-freeze.md`, `compatibility-deprecation-policy.md`,
     `package-extraction-readiness.md`, and `package-validation.md`.

3. Create `agent-workflow-github/README.md`.
   - Describe the package as typed GitHub identifiers, pure remote parsers, and
     pure `gh`/`git` command specifications.
   - Group the exposed modules from `agent-workflow-github/agent-workflow-github.cabal`:
     `Workflow.GitHub.Ids`, `Workflow.GitHub.Remote`, and
     `Workflow.GitHub.Command`.
   - Document guarantees: typed repository/issue/PR/branch/review-thread/SHA
     values, pure parser/classifier surfaces for GitHub/git observations,
     deterministic command-spec rendering, and no command execution authority.
   - Document non-goals: no PR or issue lifecycle policy, no merge/readiness
     decisions, no review-publication policy, no healthcheck/repair ownership,
     no Codex adapter dependency, no moifold runtime ownership, no package
     publication claim.
   - Link to `docs/agentic-workflow-framework/implemented-api-freeze.md`,
     `package-extraction-readiness.md`,
     `compatibility-deprecation-policy.md`, and `package-validation.md`.

4. Add minimal package descriptor references for the READMEs if validation
   confirms Cabal accepts them.
   - Add `extra-doc-files: README.md` to
     `agent-workflow-core/agent-workflow-core.cabal`,
     `agent-workflow-codex/agent-workflow-codex.cabal`, and
     `agent-workflow-github/agent-workflow-github.cabal`.
   - Do not change package names, versions, synopsis, description, dependencies,
     exposed modules, source layout, or source-repository fields.
   - If `cabal check` rejects `extra-doc-files` placement or wording, keep the
     README files and either fix only the descriptor doc-field placement or
     omit the descriptor reference; do not broaden into descriptor cleanup.

5. Add Haddock-facing module docs for exposed modules where the current source
   lacks public identity or boundary context.
   - Add a concise module header comment directly before each exposed `module`
     declaration, using `-- | ...` or a short multi-line Haddock block.
   - Cover all exposed modules unless a module already has adequate
     module-level Haddock after implementation inspection.
   - Keep module docs descriptive, not tutorial-oriented. Each header should
     answer what this module owns and, when relevant, what remains outside the
     package.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/Spec.hs`, mention the
     core spec contract and the pure state/event/observation/effect boundary.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/Indexed/Spec.hs`,
     mention the indexed compatibility surface and bridge role, without
     claiming a richer indexed public redesign.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/DSL.hs`, mention the
     pure planning DSL and explicitly avoid `liftIO`.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/Codec.hs`,
     `EventLog/Core.hs`, `EventLog/File/Core.hs`, and
     `EventLog/Commit/Core.hs`, mention generic codec/replay/line/commit
     contracts and that concrete schemas and files remain workflow-owned.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/Execution/Core.hs`,
     `Permission/Core.hs`, and `Transaction/Core.hs`, mention inspectable
     effect plans, permission checks, and transaction ordering/stages.
   - For `agent-workflow-core/src/CodexWatcher/Workflow/Audit.hs`,
     `Daemon/Core.hs`, and `Failure.hs`, mention operator-facing projections
     and reusable failure classification, not daemon loop ownership.
   - For `agent-workflow-codex/src/CodexWatcher/AppServerProtocol.hs`, mention
     deterministic JSON-RPC request construction.
   - For `agent-workflow-codex/src/CodexWatcher/Workflow/Agent*.hs` and
     `Workflow/Observation/Agent.hs`, mention typed roles, turn ids, retry
     metadata, classification, adapter helpers, transport/interpreter
     boundaries, and observation planning without prompt or lifecycle policy.
   - For `agent-workflow-github/src/CodexWatcher/Workflow/GitHub/*.hs`,
     mention typed ids, parser/classifier ownership, and pure command specs
     without command execution or lifecycle ownership.

6. Check documentation claims against the source surfaces before verification.
   - Compare every README module list against each package's `exposed-modules`
     field.
   - Verify README non-goals match `orchestrator/project-contract.md` and the
     package docs under `docs/agentic-workflow-framework/`.
   - Search the new docs for overclaims such as `published`, `uploaded`,
     `stable 1.0`, `generic prompt runner`, `healthcheck`, `repair`, or
     `lifecycle` when used as package-owned language.

### Verification

Run these commands from the repository root:

```sh
cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github
scripts/validate-workflow-packages.sh
cabal build all
cabal test watcher-core-test
git diff --check
```

If staging is performed later, also run:

```sh
git diff --cached --check
```

Add a short implementation note recording which commands passed and any local
environment failures. Do not report package readiness from docs-only edits
unless the validation command actually ran.

### Acceptance Criteria

- `agent-workflow-core/README.md`, `agent-workflow-codex/README.md`, and
  `agent-workflow-github/README.md` exist and describe the package candidates
  as reusable typed workflow packages, not as moifold lifecycle policy.
- The READMEs link to the existing evidence docs for API freeze, package
  identity, readiness, compatibility/deprecation, metadata truth, and
  validation where relevant.
- Each README's module list matches the corresponding `exposed-modules` field.
- Exposed modules in the three package source trees have useful Haddock-facing
  module docs that clarify ownership boundaries and public non-goals.
- Descriptor changes, if any, are limited to README documentation references.
- No examples, consumer guides, changelog entries, release notes, upload
  commands, package publication claims, event/golden changes, compatibility
  facade removal, CI redesign, or roadmap/state edits are introduced.
- Baseline and task-specific verification commands are run or their exact
  failure/blocker is recorded.

### Risks

- Documentation may overstate public stability. Mitigate by using pre-1.0
  candidate language and linking to the release-gate limits instead of claiming
  publication readiness.
- Package READMEs may drift from exposed modules. Mitigate by comparing each
  module list to the Cabal descriptor before review.
- Haddock comments may accidentally describe moifold-specific behavior as
  reusable package behavior. Mitigate by checking against
  `orchestrator/project-contract.md` and the moifold-owned policy sections in
  the framework docs.
- Descriptor `extra-doc-files` changes may affect `cabal check` or sdist
  contents. Mitigate by keeping descriptor edits limited to README references
  and running `scripts/validate-workflow-packages.sh`.
- Full baseline commands may be slower than the docs diff suggests. They are
  still the roadmap baseline; if an environment failure occurs, record the
  exact failing command and first actionable error.
