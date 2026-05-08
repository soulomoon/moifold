### Squash Commit
- Title: Add workflow package validation script and docs
- Summary: This round adds repeatable local release-validation plumbing for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`. The payload is `scripts/validate-workflow-packages.sh`, `docs/agentic-workflow-framework/package-validation.md`, a narrow index link from `docs/agentic-workflow-framework/README.md`, and the round implementation notes. The script and docs cover package-level `cabal check`, local source distribution generation, expected tarball paths, tarball descriptor inspection, and the explicit no-upload boundary.

### Merge Readiness
- Base branch freshness: confirmed locally. `codex/workflow-facade-extraction` and `orchestrator/round-043-external-package-slice` both resolve to `218b431286432efd01ce433cce88092c35677656`; `git ls-remote --heads origin codex/workflow-facade-extraction orchestrator/round-043-external-package-slice` returned no matching remote heads, so no remote freshness evidence is available.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `last_completed_round` as `round-042`, `pending_merge_rounds` as empty, and this round depends on `round-042` / `item-042-moifold-local-consumer-wiring`.
- Pending dependencies: none. The review record status is `approved`, and `review.md` marks the round `APPROVED`.

### Follow-Up Notes
Approved validation evidence includes `scripts/validate-workflow-packages.sh`, the expanded manual `cabal check` commands, the expanded manual `cabal sdist --output-directory=dist-newstyle/sdist ...` commands, tarball existence checks, tarball `.cabal` descriptor checks, `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and the cached-diff applicability check.

Generated source distributions are local ignored build artifacts under `dist-newstyle/sdist/`:
- `dist-newstyle/sdist/agent-workflow-core-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-codex-0.1.0.0.tar.gz`
- `dist-newstyle/sdist/agent-workflow-github-0.1.0.0.tar.gz`

The reviewer verified `dist-newstyle/` is ignored, the generated tarballs are not tracked or staged, and the reviewed files contain no executable package-upload command. This round preserves the no-upload/no-publication boundary.

Scope exclusions remain unchanged: no package identity, version, dependency-bound, compatibility facade, event schema, golden fixture, lifecycle/runtime/healthcheck/repair ownership, CI, changelog, release note, example, Haddock, public README, package upload, roadmap, or merge-order policy change is part of this merge.

Merge note: squash only the approved payload and round artifacts for `round-043`; do not include generated `dist-newstyle/` artifacts.
