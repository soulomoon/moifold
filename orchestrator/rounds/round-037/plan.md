### Goal

Define the release metadata policy for the future external package candidates
`agent-workflow-core`, `agent-workflow-codex`, and
`agent-workflow-github`, covering license, maintainer, category, synopsis,
description, source repository, changelog, release-note, and metadata truth
requirements before any package descriptor migration or publication work.

### Approach

Keep this round serial and artifact-only. The selected item is one coupled
release-policy surface: metadata fields, package-specific wording rules,
changelog/release-note gates, and truth requirements all need to agree with the
same package identity, implemented API freeze, readiness report, and release
gate boundaries. Splitting the work across workers would create overlapping
ownership of the same metadata table and publication constraints, so do not
write `worker-plan.json`.

Add a focused policy artifact under `docs/agentic-workflow-framework/`,
preferably
`docs/agentic-workflow-framework/release-metadata-policy.md`, and link it
narrowly from `docs/agentic-workflow-framework/README.md` only if that improves
discoverability. Treat `orchestrator/project-contract.md`,
`orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
`docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
`docs/agentic-workflow-framework/package-extraction-readiness.md`,
`docs/agentic-workflow-framework/implemented-api-freeze.md`, and
`moifold.cabal` as the evidence base.

The policy should define requirements that later descriptor, docs,
changelog/release-note, package-check, source-distribution, and release-gate
rounds can validate. It must not edit Cabal descriptors, create changelog or
release-note entries, move source files, rename modules, publish packages,
authorize upload, or imply that source distributions are ready.

### Steps

1. Inspect the current source-backed metadata and release-contract evidence
   before editing:
   - `moifold.cabal`, especially the current top-level `license`, `author`,
     `maintainer`, `category`, `synopsis`, `description`, and
     `source-repository head` fields;
   - `docs/agentic-workflow-framework/package-identity-versioning-contract.md`
     for final package names, pre-1.0 version policy, module namespace policy,
     version-bound expectations, and release-gate limits;
   - `docs/agentic-workflow-framework/package-extraction-readiness.md` for
     package ownership, dependency ownership, remaining blockers, and surfaces
     not included in readiness;
   - `docs/agentic-workflow-framework/implemented-api-freeze.md` for the
     implemented API surface and moifold-owned policy boundary;
   - `orchestrator/project-contract.md` and the active roadmap verification
     contract for metadata truth, compatibility, release-note, and publication
     constraints.
2. Confirm the exact current metadata and package identity evidence with
   commands equivalent to:
   - `rg -n "^(name|version|synopsis|description|license|author|maintainer|category):|^source-repository|^  location:|^library agent-workflow" moifold.cabal`
   - `rg -n "release-gate|metadata truth|changelog|release note|release-note|publication|upload" docs/agentic-workflow-framework orchestrator/project-contract.md orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001`
3. Add the release metadata policy artifact. It should state that this is a
   metadata policy for future package candidates, not a descriptor migration,
   source-distribution readiness claim, release announcement, upload approval,
   or publication decision.
4. Define package-level metadata requirements for
   `agent-workflow-core`, `agent-workflow-codex`, and
   `agent-workflow-github`:
   - license requirement, including whether each candidate may inherit the
     current repository `MIT` license and what evidence must be checked before
     standalone descriptors are written;
   - maintainer requirement, using the current repository metadata as evidence
     while requiring an explicit maintainer field for each standalone package
     candidate;
   - category requirement, including the default category to use and a rule
     that category text must describe reusable workflow/package surfaces, not
     moifold watcher operations;
   - synopsis requirement, with one concise, package-specific synopsis per
     candidate that does not overpromise release readiness or moifold lifecycle
     ownership;
   - description requirement, with package-specific description constraints
     that name the implemented public surface and the explicit non-goals;
   - source-repository requirement, including the current repository URL as
     evidence and a rule for how later descriptor rounds should represent the
     source location before any package upload.
5. Define changelog and release-note requirements:
   - no changelog or release-note entry is created in this round;
   - later changelog work must distinguish internal extraction history from
     public package API promises;
   - release notes must call out pre-1.0 status, package ownership, compatible
     import/module expectations, breaking changes, validation evidence, and
     remaining moifold-owned policy;
   - release notes must not read as an announcement or upload approval before
     the terminal release-gate round.
6. Define metadata truth requirements:
   - every descriptor field, README/Haddock claim, changelog entry,
     release-note statement, and source-distribution description must be
     backed by implemented source, current docs, or explicit release-gate
     evidence;
   - metadata must not claim package upload, standalone descriptor readiness,
     source-distribution validity, CI coverage, public API stability,
     compatibility-facade removal, event schema ownership, healthcheck/repair
     ownership, prompt policy, daemon/runtime ownership, or moifold issue/PR
     lifecycle support unless a later approved round proves that specific
     claim;
   - package descriptions must preserve the ownership split in
     `orchestrator/project-contract.md` and the package identity/versioning
     contract.
7. Add a concise package metadata table or equivalent structured section that
   gives later descriptor rounds direct default values or wording constraints
   for all required fields. Mark any value that must be reconfirmed at
   descriptor time rather than treating current top-level `moifold` metadata as
   automatically final for every standalone package.
8. If useful, add one narrow link from
   `docs/agentic-workflow-framework/README.md` to the new policy. Do not
   rewrite unrelated framework docs.
9. Re-read the final policy against the project contract, active verification
   contract, package identity/versioning contract, readiness report, and API
   freeze. Remove any text that implies descriptor migration, source movement,
   package layout completion, `cabal check` or source-distribution success, CI
   readiness, changelog/release-note completion, upload approval, public
   release readiness, compatibility-facade removal, event schema migration, or
   moifold lifecycle migration.
10. Keep edits limited to the new release metadata policy artifact, the
    optional narrow framework README link, and this round's orchestrator plan
    artifact. Do not edit `orchestrator/state.json`, roadmap files,
    implementation notes, review or merge artifacts, Haskell source, Cabal
    descriptors, tests, generated fixtures, changelogs, release notes, package
    descriptors, source-distribution artifacts, or publication artifacts.

### Verification

- `git diff --check`
- Confirm `git diff --name-only` is limited to
  `orchestrator/rounds/round-037/plan.md`,
  `docs/agentic-workflow-framework/release-metadata-policy.md`, and optionally
  `docs/agentic-workflow-framework/README.md`.
- Directly review the policy against
  `orchestrator/project-contract.md`,
  `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
  `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
  `docs/agentic-workflow-framework/package-extraction-readiness.md`,
  `docs/agentic-workflow-framework/implemented-api-freeze.md`, and
  `moifold.cabal` to confirm all metadata defaults, wording constraints,
  changelog/release-note gates, and truth requirements are source-backed.
- Run `cabal build all` and `cabal test watcher-core-test` if the implementer
  touches any Haskell source, Cabal descriptor, test, generated fixture, or
  other non-documentation implementation file. For the expected artifact-only
  implementation, those commands are optional baseline checks rather than
  required acceptance gates.
- Run `git diff --cached --check` if any files are staged during the round.
