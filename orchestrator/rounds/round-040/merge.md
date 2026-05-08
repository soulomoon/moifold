### Squash Commit
- Title: Add standalone agent-workflow-codex package descriptor
- Summary: This round creates the standalone `agent-workflow-codex` local package candidate, wires it into `cabal.project`, and extends package-boundary assertions so the Codex adapter package is validated independently while the existing `moifold:agent-workflow-codex` internal sublibrary remains available for current moifold consumers.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; the round worktree HEAD matches the base branch tip, and `git merge-base --is-ancestor codex/workflow-facade-extraction HEAD` passed.
- Merge ordering satisfied: yes. `round-040` depends on `round-039` / `item-039-core-package-layout`, and local history shows `codex/workflow-facade-extraction` at `Mark core package layout round complete`.
- Pending dependencies: none for this merge artifact. The reviewed payload is approved in `review.md` and `review-record.json`.

### Follow-Up Notes
- Payload files: `agent-workflow-codex/agent-workflow-codex.cabal`, `cabal.project`, and focused Codex package-boundary assertions in `test/Main.hs`.
- Approved validation evidence: `cabal build agent-workflow-codex:lib:agent-workflow-codex`, `(cd agent-workflow-codex && cabal check)`, source-boundary scans, forbidden descriptor scan, approved dependency-bound scan, `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` all passed. No staged files were present, so cached diff checking was not applicable.
- Scope exclusions preserved: no standalone `agent-workflow-github` descriptor, no moifold local-consumer rewiring, no compatibility facade removal, no prompt/runtime/lifecycle behavior changes, no event schema or golden fixture changes, no source distribution, no CI, no public docs, no changelog or release notes, no package upload, and no roadmap edits.
- Merge note: the existing internal `moifold:agent-workflow-codex` sublibrary intentionally remains in `moifold.cabal`; moifold consumer rewiring belongs to the later `direction-007-moifold-local-consumer-wiring` round.
