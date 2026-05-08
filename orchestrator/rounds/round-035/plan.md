### Goal

Produce a source-backed extraction readiness report for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` under `docs/agentic-workflow-framework/`, showing whether the current internal package boundaries are ready for a future external extraction decision without publishing packages or moving moifold lifecycle policy.

### Approach

Add a report-first artifact, preferably `docs/agentic-workflow-framework/package-extraction-readiness.md`, and link it from `docs/agentic-workflow-framework/README.md` only if that improves discoverability. The report should treat `orchestrator/project-contract.md`, `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/verification.md`, `docs/agentic-workflow-framework/implemented-api-freeze.md`, `moifold.cabal`, and the package-boundary assertions in `test/Main.hs` as the current evidence base.

Keep the round serial. The readiness report, Cabal exposed-module lists, dependency ownership, and compatibility-facade mapping are coupled enough that worker fan-out would create integration overhead without clear disjoint ownership. Do not write `worker-plan.json`.

Do not implement package publication, external release setup, broad compatibility-facade removal, event schema or golden fixture changes, lifecycle/runtime/healthcheck/repair migration, prompt policy changes, or speculative API redesign. Cabal, exposed-module, or package-boundary test edits are allowed only when the report demonstrates a concrete readiness gap that would make the report false if left unaddressed.

### Steps

1. Inspect the current source and docs surfaces before editing:
   - `docs/agentic-workflow-framework/README.md`
   - `docs/agentic-workflow-framework/implemented-api-freeze.md`
   - `moifold.cabal`
   - package-boundary/source-scan assertions in `test/Main.hs`, especially the checks for `workflowCoreCabalSublibraryKeepsPackageBoundary`, `workflowCodexCabalSublibraryKeepsPackageBoundary`, `workflowGithubCabalSublibraryKeepsPackageBoundary`, and `workflowMoifoldCabalLibraryDoesNotReexportAdapters`.

2. Generate import-graph evidence from the current tree and summarize it in the report. Use commands equivalent to:
   - `find agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src -name '*.hs' -print0 | xargs -0 rg -n '^import '`
   - `rg -n "import CodexWatcher\\.Workflow\\.(Agent|GitHub)|import CodexWatcher\\.AppServerProtocol|import CodexWatcher\\.Workflow\\.Agent\\.Codex|import CodexWatcher\\.Workflow\\.GitHub" src test agent-workflow-core agent-workflow-codex agent-workflow-github`
   - `rg -n "library agent-workflow-core|library agent-workflow-codex|library agent-workflow-github|exposed-modules:|build-depends:" moifold.cabal`

3. Write the readiness report with explicit sections for:
   - readiness verdict for each of `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`;
   - import-graph evidence, including allowed internal edges and forbidden edges that are currently absent;
   - dependency ownership from the Cabal sections, including why `agent-workflow-core` remains limited to generic dependencies, why `agent-workflow-codex` owns `aeson`/`websockets`/core, and why `agent-workflow-github` owns pure GitHub parsing/rendering dependencies without depending on moifold;
   - compatibility-facade and deprecation-readiness mapping, including `src/CodexWatcher/AppServerClient.hs` as a compatibility wrapper and the main-library decision not to reexport adapter modules;
   - moifold-owned blockers that must remain blockers, including lifecycle policy, concrete event schemas/golden logs, prompt/schema policy, daemon/runtime ownership, filesystem writes, healthcheck, repair, compatibility files, publication, and actual deprecation policy;
   - validation commands and the package-boundary assertions that reviewers should use as evidence.

4. If the report uncovers a real mismatch, make the minimal cleanup needed to keep the report truthful. Examples of allowed cleanup are adding a missing exposed module to the correct `agent-workflow-*` Cabal section, moving a dependency entry to the package that already owns the implementation, or extending an existing recursive package-boundary assertion. Do not remove compatibility modules or move behavior across package boundaries as part of this round.

5. If no concrete readiness gap is found, keep code and Cabal unchanged and state that the round is artifact-only. Avoid rewriting existing framework docs except for a narrow README link to the new report.

6. Re-read the report against the project contract and roadmap verification contract. Confirm it distinguishes implemented APIs from future package-publication decisions and does not imply that external package publication or facade removal is complete.

### Verification

Run these checks before handing the round to review:

- `git diff --check`
- `cabal build all`
- `cabal test watcher-core-test`

If any Cabal or package-boundary source-scan changes are made, also inspect the changed `moifold.cabal` sections manually and confirm that `test/Main.hs` still asserts the same ownership contracts for the touched package. If files are staged later by the implementer, run `git diff --cached --check` as required by the project contract.
