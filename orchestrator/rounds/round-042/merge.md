### Squash Commit
- Title: Wire moifold to standalone workflow packages
- Summary: This round switches the root `moifold` package and `watcher-core-test` from internal `moifold:agent-workflow-*` sublibrary dependencies to the local standalone `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github` package candidates, while preserving existing compatibility facades and package-boundary assertions.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `git rev-list --left-right --count codex/workflow-facade-extraction...HEAD` returned `0 0`, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed. Remote freshness was not checked because `origin` does not advertise `codex/workflow-facade-extraction`.
- Merge ordering satisfied: yes. `round-042` depends on `round-039`, `round-040`, and `round-041`, requires merge after `item-041-github-package-layout`, and controller state records `last_completed_round: round-041` with no pending merge rounds.
- Pending dependencies: none for this merge artifact. The reviewed payload is approved in `review.md` and `review-record.json`.

### Follow-Up Notes
- Payload files: `moifold.cabal`, focused package-boundary assertions in `test/Main.hs`, and `orchestrator/rounds/round-042/implementation-notes.md`.
- Approved validation evidence: standalone package builds for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`; product builds for `moifold:lib:moifold` and `moifold:exe:moifold`; `cabal build all`; `cabal test watcher-core-test`; required boundary scans for removed internal sublibrary wiring, approved standalone bounds, and reusable-package ownership; and `git diff --check` all passed. No files were staged, so cached diff checking was not applicable.
- Scope exclusions preserved: no source-module edits, no compatibility facade removal, no event schema or golden fixture changes, no runtime owner, daemon, lifecycle, healthcheck, repair, prompt, CI, source distribution, public docs/examples, changelog, release-note, package-upload, or roadmap changes were made for the reviewed implementation payload.
- Dependency/order readiness: the standalone core, Codex, and GitHub package layout rounds are already complete, and this local-consumer wiring closes the remaining standalone package layout direction for milestone 002 without broadening into release validation.
- Merge note: `cabal.project` already listed the standalone local packages, so the consumer change is confined to root package dependency wiring and focused boundary tests.
