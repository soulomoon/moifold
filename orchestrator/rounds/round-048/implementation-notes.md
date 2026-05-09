### Changes Made
- `docs/agentic-workflow-framework/changelog.md`: added source-backed package-candidate changelog material for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` at `0.1.0.0`, including descriptor metadata, package-specific surfaces, docs/example evidence, validation commands, compatibility status, and explicit non-goals.
- `docs/agentic-workflow-framework/release-notes.md`: added release-note material for a future release-gate review, covering package scope, pre-1.0 expectations, ownership, compatibility facades, validation evidence, README/Haddock and consumer-guide evidence, remaining moifold-owned policy, and blockers before publication.
- `docs/agentic-workflow-framework/README.md`: linked the new changelog and release-note documents from the implemented contract document index.
- `agent-workflow-core/README.md`: added evidence links to the package-candidate changelog and release notes.
- `agent-workflow-codex/README.md`: added evidence links to the package-candidate changelog and release notes.
- `agent-workflow-github/README.md`: added evidence links to the package-candidate changelog and release notes.

### Tests
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed; one test suite completed with `Test suite watcher-core-test: PASS`.
- `scripts/validate-workflow-packages.sh`: passed; all three package candidates had clean `cabal check` output and the script produced and inspected `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`, `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`, and `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`.
- `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`: passed; the executable printed core planning output, Codex `thread/start`, `turn/start`, and `thread/read` requests, and GitHub `gh pr list`, `gh pr view`, and `git push --dry-run` command specs.
- Metadata descriptor scan: passed; all three descriptors report name, version `0.1.0.0`, synopsis, description, `MIT`, `soulomoon`, `Development`, and `https://github.com/soulomoon/moifold.git`.
- New-doc evidence scan: passed; the new changelog and release notes contain the required package names, version, pre-1.0 wording, metadata values, repository URL, validation commands, and consumer example references.
- Overclaim scan: passed after manual classification; matches are negated/non-goal wording, plus the pre-existing negated `agent-workflow-codex/README.md` sentence about not deciding whether compatibility facades are removed.
- Ownership scan: passed after manual classification; matches preserve moifold ownership for event schemas, compatibility files/facades, prompt policy, runtime ownership, healthcheck, and repair.
- Scope scan: reported only `orchestrator/state.json`, which was already modified before this implementation and was not edited by this round.
- `git diff --check`: passed.

### Notes
Pre-existing policy docs still include historical wording from before standalone package descriptors existed, while the current tree has `agent-workflow-core/agent-workflow-core.cabal`, `agent-workflow-codex/agent-workflow-codex.cabal`, and `agent-workflow-github/agent-workflow-github.cabal`. This round did not edit those policy docs because the selected scope was changelog and release-note preparation only.
