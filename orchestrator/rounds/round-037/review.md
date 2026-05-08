### Checks Run

- Command: `git status --short`
  Result: pass. Implementation scope is `docs/agentic-workflow-framework/README.md`,
  `docs/agentic-workflow-framework/release-metadata-policy.md`, and round
  artifacts under `orchestrator/rounds/round-037/`; `orchestrator/state.json`
  is changed only as controller bookkeeping for active round review state.
- Command: `git diff`
  Result: pass. Tracked implementation diff only adds a narrow README link to
  the new release metadata policy. The state diff records round-037 active
  review metadata and artifact paths.
- Command: `git ls-files --others --exclude-standard`
  Result: pass. Untracked paths before review artifacts were the new release
  metadata policy plus round selection, plan, and implementation notes.
- Command: `rg -n "^(name|version|synopsis|description|license|author|maintainer|category):|^source-repository|^  location:|^library agent-workflow" moifold.cabal`
  Result: pass. Current metadata is `moifold` `0.1.0.0`, `MIT`,
  `soulomoon` author/maintainer, `Development`, source repository
  `https://github.com/soulomoon/moifold.git`, with internal sublibraries
  `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github`.
- Command: `rg -n "release-gate|metadata truth|changelog|release note|release-note|publication|upload" docs/agentic-workflow-framework orchestrator/project-contract.md orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001`
  Result: pass. The new policy keeps publication blocked, creates no changelog
  or release-note artifact, and preserves metadata-truth requirements from the
  project contract and active verification contract.
- Command: `cabal build all`
  Result: pass. Built `agent-workflow-core`, `agent-workflow-github`,
  `agent-workflow-codex`, the main `moifold` library, and the `moifold`
  executable with GHC 9.12.2.
- Command: `cabal test watcher-core-test`
  Result: pass. Test suite `watcher-core-test` passed: `1 of 1 test suites
  (1 of 1 test cases) passed`.
- Command: `git diff --check`
  Result: pass. No whitespace errors.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors.
- Command: `git diff --cached --name-only`
  Result: pass. No staged files.

### Plan Compliance

- Inspect current source-backed metadata and release-contract evidence: met.
  Reviewed `moifold.cabal`, the package identity/versioning contract,
  readiness report, API freeze, project contract, active verification
  contract, README diff, and release-gate text.
- Confirm exact current metadata and package identity evidence: met. The
  `moifold.cabal` metadata inspection confirms the top-level metadata and
  three internal sublibraries; the release-policy search confirms changelog,
  release-note, publication, upload, release-gate, and metadata-truth
  constraints.
- Add a focused release metadata policy artifact: met. Added
  `docs/agentic-workflow-framework/release-metadata-policy.md` as a policy for
  future package candidates, explicitly not a descriptor migration,
  source-distribution readiness claim, release announcement, upload approval,
  or publication decision.
- Define package-level metadata requirements: met. The policy covers license,
  author, maintainer, category, synopsis, description, and source-repository
  requirements for `agent-workflow-core`, `agent-workflow-codex`, and
  `agent-workflow-github`, with descriptor-time reconfirmation where the
  current `moifold` metadata is only evidence.
- Define changelog and release-note requirements: met. The policy creates no
  changelog or release-note entry and requires later release notes to call out
  pre-1.0 status, package ownership, compatibility expectations, breaking
  changes, validation evidence, moifold-owned policy, and release-gate limits.
- Define metadata truth requirements: met. The policy requires descriptor,
  README/Haddock, changelog, release-note, and source-distribution claims to be
  backed by implemented source, current docs, or release-gate evidence, and it
  blocks claims about upload, descriptor readiness, source-distribution
  validity, CI coverage, public API stability, compatibility-facade removal,
  event-schema ownership, healthcheck, repair, prompt policy, daemon/runtime
  ownership, lifecycle support, merge readiness, and review/publication
  decisions without later approval.
- Add structured metadata defaults or wording constraints: met. The package
  metadata table gives defaults and package-specific synopsis/description
  constraints for all three future package candidates.
- Add only a narrow README link if useful: met. README diff adds one concise
  link in the implemented contract document list.
- Re-read policy against contracts and remove overclaims: met. The policy
  stays aligned with the project contract, active verification contract,
  package identity/versioning contract, readiness report, implemented API
  freeze, and release-gate limits.
- Keep edits limited and avoid prohibited implementation changes: met. No
  Cabal descriptor, Haskell source, test, generated fixture, changelog, release
  note, package descriptor, source-distribution artifact, compatibility facade,
  source layout, upload, or publication state changed.

### Decision

**APPROVED**

### Evidence

The integrated result is artifact-only apart from the narrow README link. It
adds a source-backed metadata policy for the three future external package
candidates and does not modify package descriptors, source layout, source
modules, tests, generated fixtures, changelogs, release notes, package
artifacts, compatibility facades, upload state, or publication state.

`orchestrator/state.json` is outside implementation scope and its diff is
controller bookkeeping: it activates `round-037` in `review`, records the
requested branch, task, lineage ids, and round artifact paths. It does not
change the roadmap id, revision, base branch, project contract, verification
contract, or implementation docs.

The new policy preserves the package ownership split: generic workflow kernel
metadata remains in `agent-workflow-core`, Codex app-server/protocol adapter
metadata remains in `agent-workflow-codex`, GitHub parser/command-spec
metadata remains in `agent-workflow-github`, and moifold remains the concrete
product/runtime owner for lifecycle, prompts, compatibility files, event
schemas, healthcheck, repair, daemon/runtime ownership, merge/review policy,
and publication decisions.

Baseline verification passed: `cabal build all`, `cabal test
watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
