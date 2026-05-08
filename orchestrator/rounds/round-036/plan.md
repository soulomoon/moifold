### Goal

Define the package identity and versioning contract for the future external
package candidates `agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github`, using source-backed evidence from the current
sublibrary layout and round 035 readiness report, without changing Cabal
descriptors, moving files, renaming modules, publishing packages, or removing
compatibility facades.

### Approach

Keep this round serial and artifact-only. The selected scope is one coupled
release-contract decision surface: package names, initial version policy,
module namespace policy, semantic-versioning expectations, and compatibility
analysis for the names already present in the source tree. Splitting this
across workers would create overlapping ownership over the same package
identity table and compatibility conclusions, so do not write
`worker-plan.json`.

Add a focused contract artifact under `docs/agentic-workflow-framework/`,
preferably
`docs/agentic-workflow-framework/package-identity-versioning-contract.md`, and
link it narrowly from `docs/agentic-workflow-framework/README.md` only if that
improves discoverability. Treat `orchestrator/project-contract.md`,
`orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
`docs/agentic-workflow-framework/implemented-api-freeze.md`,
`docs/agentic-workflow-framework/package-extraction-readiness.md`, and
`moifold.cabal` as the evidence base.

The contract should make stable decisions where the current tree already has
reviewable evidence, and explicitly mark any identity choice as provisional
only when later release-metadata or package-layout rounds must still confirm
it. Do not use the artifact to authorize descriptor migration, package upload,
source movement, module renames, compatibility-facade removal, CI changes, or
changelog/release-note work.

### Steps

1. Inspect the current identity evidence before editing:
   - `moifold.cabal`, especially the top-level `name` and `version` fields and
     the `library agent-workflow-core`, `library agent-workflow-codex`, and
     `library agent-workflow-github` stanzas;
   - `docs/agentic-workflow-framework/package-extraction-readiness.md`;
   - `docs/agentic-workflow-framework/implemented-api-freeze.md`;
   - `docs/agentic-workflow-framework/README.md`;
   - `orchestrator/project-contract.md`;
   - the active roadmap verification contract for metadata truth, release-gate
     limits, compatibility, and package ownership.
2. Confirm the exact current package and module names with source-backed
   commands equivalent to:
   - `rg -n "^(name|version):|^library agent-workflow" moifold.cabal`
   - `rg -n "exposed-modules:|CodexWatcher\\.Workflow|CodexWatcher\\.AppServerProtocol" moifold.cabal`
   - `find agent-workflow-core/src agent-workflow-codex/src agent-workflow-github/src -name '*.hs' -print | sort`
3. Add the package identity/versioning contract artifact. It should include:
   - status text stating that this is a package identity and versioning
     contract for release candidates, not a package publication decision;
   - a decision table for `agent-workflow-core`, `agent-workflow-codex`, and
     `agent-workflow-github` with package name, whether the name is final or
     provisional, intended package role, initial version policy, module
     namespace policy, and dependencies/ordering that affect versioning;
   - a short explanation for keeping the three existing package names, unless
     the source evidence reveals a concrete reason to record a provisional
     alternative;
   - an initial version rule for the external candidates. Prefer a conservative
     pre-1.0 policy unless the evidence supports a stronger stable-public
     contract. Explain how the current `moifold` package version relates to
     the future standalone package versions and do not imply that internal
     sublibrary versioning already exists.
4. Record semantic-versioning expectations in the artifact:
   - what counts as a breaking change for exposed modules, exported types,
     constructors, functions, class methods, type families, and behavior that
     downstream code may rely on;
   - how adapter package version bounds should relate to
     `agent-workflow-core` when standalone descriptors exist;
   - that event JSON schemas, golden replay behavior, compatibility files,
     daemon/runtime ownership, prompt policy, and moifold issue/PR lifecycle
     are not part of these reusable package version promises unless a later
     release-gate contract explicitly says so;
   - that package publication remains blocked until a terminal release-gate
     round explicitly approves it.
5. Record the module namespace policy:
   - current exposed modules stay under `CodexWatcher.Workflow.*` and
     `CodexWatcher.AppServerProtocol` for this contract;
   - no module renames or source moves are authorized in this round;
   - future namespace changes, if any, require a separate migration plan with
     import, build, documentation, and compatibility evidence;
   - compatibility modules such as `CodexWatcher.AppServerClient` remain
     moifold-owned facades and are not removed or repurposed by this contract.
6. Add a compatibility analysis section for the current names:
   - identify the current internal Cabal shape as `moifold` with three
     named sublibraries, not three standalone package descriptors yet;
   - explain why external package descriptors must not guess different names
     after this contract is approved;
   - describe downstream migration implications for users importing current
     module names through moifold versus future standalone packages;
   - list the package-identity assumptions that later metadata, layout,
     validation, docs, and release-gate rounds may rely on.
7. If the artifact needs a link for discoverability, add one narrow entry to
   `docs/agentic-workflow-framework/README.md`. Do not rewrite existing docs
   beyond the minimum link/context needed for the new contract.
8. Re-read the final artifact against `orchestrator/project-contract.md` and
   the active roadmap verification contract. Remove any text that implies
   package upload approval, descriptor migration completion, package layout
   completion, compatibility-facade removal, event schema migration, CI
   readiness, changelog/release-note completion, or public release readiness.
9. Keep edits limited to the new contract artifact, the optional narrow
   framework README link, and this round's orchestrator plan artifact. Do not
   edit `orchestrator/state.json`, roadmap files, implementation notes, review
   or merge artifacts, Haskell source, Cabal files, tests, generated fixtures,
   package descriptors, release notes, or changelogs.

### Verification

- `git diff --check`
- Confirm `git diff --name-only` is limited to
  `orchestrator/rounds/round-036/plan.md`,
  `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
  and optionally `docs/agentic-workflow-framework/README.md`.
- Directly review the contract against
  `orchestrator/project-contract.md`,
  `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
  `docs/agentic-workflow-framework/package-extraction-readiness.md`, and
  `moifold.cabal` to confirm package names, current version evidence, module
  namespace policy, semantic-versioning expectations, compatibility analysis,
  and release-gate limits are source-backed.
- Run `cabal build all` and `cabal test watcher-core-test` if the implementer
  touches any Haskell source, Cabal file, test, generated fixture, or other
  non-documentation file. For the expected artifact-only implementation, those
  commands are optional but may still be run as baseline confidence checks.
- Run `git diff --cached --check` if any files are staged during the round.

