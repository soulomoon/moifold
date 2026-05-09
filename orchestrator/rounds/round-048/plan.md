### Goal

Prepare source-backed changelog entries and release-note material for the
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
package candidates so milestone 004 has reviewable public-docs release
metadata without claiming package publication, upload approval, release
readiness, or compatibility-facade removal.

### Approach

Keep this round sequential and documentation-only. The implementation should
add release metadata artifacts that summarize the package candidates from
existing truth sources, then link them from the workflow-framework docs index
and, if useful for discoverability, from the package READMEs as evidence links
only.

Likely files to change:

- Add `docs/agentic-workflow-framework/changelog.md`.
- Add `docs/agentic-workflow-framework/release-notes.md`.
- Update `docs/agentic-workflow-framework/README.md` to link both new files.
- Optionally update `agent-workflow-core/README.md`,
  `agent-workflow-codex/README.md`, and `agent-workflow-github/README.md` with
  link-only evidence entries to the new changelog and release notes.

Do not edit package descriptors, versions, `cabal.project`, CI, validation
scripts, source modules, tests, event/golden/runtime/healthcheck/repair/prompt
policy, compatibility facades, roadmap files, merge artifacts, review
artifacts, or `orchestrator/state.json` unless a concrete metadata-truth
contradiction is found while drafting. If such a contradiction is found, stop
and document the exact file and claim before broadening the change.

### Steps

1. Re-read the round boundaries and release constraints:
   `orchestrator/rounds/round-048/selection.md`,
   `orchestrator/roadmaps/2026-05-09-00-external-package-extraction/rev-001/verification.md`,
   and `orchestrator/project-contract.md`.
2. Build the source-backed evidence table before writing prose. Inspect:
   `docs/agentic-workflow-framework/package-identity-versioning-contract.md`,
   `docs/agentic-workflow-framework/release-metadata-policy.md`,
   `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`,
   `docs/agentic-workflow-framework/package-extraction-readiness.md`,
   `docs/agentic-workflow-framework/implemented-api-freeze.md`,
   `docs/agentic-workflow-framework/package-validation.md`,
   `docs/agentic-workflow-framework/package-consumer-guide.md`,
   `agent-workflow-core/agent-workflow-core.cabal`,
   `agent-workflow-codex/agent-workflow-codex.cabal`,
   `agent-workflow-github/agent-workflow-github.cabal`,
   `.github/workflows/ci.yml`,
   `scripts/validate-workflow-packages.sh`,
   `test/Main.hs`,
   package READMEs, and
   `examples/workflow-package-consumer/{README.md,cabal.project,workflow-package-consumer.cabal,app/Main.hs}`.
3. Draft `docs/agentic-workflow-framework/changelog.md` as a package-candidate
   changelog, not a release announcement. Use one current local-candidate entry
   for the three packages, with package-specific bullets for implemented
   public surfaces, descriptor/layout status, docs/examples, validation
   evidence, compatibility status, and explicit non-goals. Keep version wording
   aligned with the current `0.1.0.0` descriptors and pre-1.0 policy.
4. Draft `docs/agentic-workflow-framework/release-notes.md` as release-note
   material for a future release-gate review. Include sections for package
   scope, pre-1.0 expectations, package ownership, compatibility facades,
   validation evidence, README/Haddock and consumer-guide evidence, remaining
   moifold-owned policy, and blockers before publication. State clearly that
   the material is not a release announcement, not upload approval, not a final
   go/no-go decision, and not source-distribution approval beyond commands run
   and recorded in the current round.
5. Update `docs/agentic-workflow-framework/README.md` to include the new
   changelog and release-note files under implemented contract documents. If
   updating package READMEs, add only short evidence links; do not alter module
   lists, guarantees, descriptor metadata, Haddock claims, or public API
   promises.
6. Compare the new docs against the exact package descriptors and current docs.
   Every package name, version, dependency relationship, synopsis-level claim,
   validation claim, compatibility statement, and non-goal must point back to
   a source inspected in step 2. Do not infer release readiness from existing
   package descriptors or local `sdist` capability.
7. Keep wording conservative:
   use "package candidate", "local validation", "future release gate",
   "pre-1.0", "compatibility facade remains available", and "moifold-owned"
   where accurate. Avoid "released", "published", "ready to upload",
   "approved", "stable API", "deprecated", or "removed" unless the sentence is
   explicitly negating that claim and is backed by policy.
8. Before handoff, inspect the final diff and confirm that only the planned
   docs files changed. If a metadata-truth issue forced a descriptor or policy
   change, call that out for reviewer attention with the exact source-backed
   reason.

### Verification

Run the baseline checks from the verification contract:

```sh
cabal build all
cabal test watcher-core-test
scripts/validate-workflow-packages.sh
git diff --check
```

If any files are staged later, also run:

```sh
git diff --cached --check
```

Run the consumer example because the release notes must cite consumer-guide
evidence accurately:

```sh
(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)
```

Run metadata-truth and overclaim scans, then manually inspect every match:

```sh
rg -n "^(name|version|synopsis|description|license|author|maintainer|category):|source-repository|location:" \
  agent-workflow-core/agent-workflow-core.cabal \
  agent-workflow-codex/agent-workflow-codex.cabal \
  agent-workflow-github/agent-workflow-github.cabal

rg -n "agent-workflow-(core|codex|github)|0\\.1\\.0\\.0|pre-1\\.0|MIT|soulomoon|Development|https://github.com/soulomoon/moifold\\.git|validate-workflow-packages|cabal build all|watcher-core-test|workflow-package-consumer" \
  docs/agentic-workflow-framework/changelog.md \
  docs/agentic-workflow-framework/release-notes.md

rg -n "cabal upload|stack upload|Hackage|gh release|git tag|release announcement|go/no-go|approved publication|uploaded|published|ready to upload|release-ready|stable API|deprecated|removed" \
  docs/agentic-workflow-framework/changelog.md \
  docs/agentic-workflow-framework/release-notes.md \
  docs/agentic-workflow-framework/README.md \
  agent-workflow-core/README.md \
  agent-workflow-codex/README.md \
  agent-workflow-github/README.md

rg -n 'WatcherEvent|event JSON `type`|schema version|golden|healthcheck|repair|prompt policy|runtime ownership|compatibility file|compatibility facade' \
  docs/agentic-workflow-framework/changelog.md \
  docs/agentic-workflow-framework/release-notes.md

git diff --name-only | rg -v '^(docs/agentic-workflow-framework/(README|changelog|release-notes)\\.md|agent-workflow-(core|codex|github)/README\\.md)$' || true
```

The final `git diff --name-only` scan should return no output unless the
implementer documented a concrete metadata-truth reason for a broader file.

### Worker Fan-Out

Worker fan-out is not used. The likely edits are tightly coupled
documentation artifacts that must stay consistent across package identity,
metadata policy, compatibility policy, validation evidence, package READMEs,
and consumer-guide wording; splitting them would add integration overhead
without a meaningful ownership boundary.
