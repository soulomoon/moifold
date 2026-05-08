### Squash Commit
- Title: Add standalone agent-workflow-github package descriptor
- Summary: This round creates the standalone `agent-workflow-github` local package candidate, wires it into `cabal.project`, and extends the GitHub package-boundary assertions so the GitHub adapter package is validated independently while the existing `moifold:agent-workflow-github` internal sublibrary remains available for current moifold consumers.

### Merge Readiness
- Base branch freshness: confirmed against local `codex/workflow-facade-extraction`; `HEAD`, merge base, and the local base branch are all `506a0978789c4098b81721ee1f4ffa4b92309fc1`. Remote freshness was not checked because neither the round branch nor the local base branch has an upstream configured.
- Merge ordering satisfied: yes. `round-041` depends on `round-039` and `round-040`, requires merge after `item-040-codex-package-layout`, and controller state records `last_completed_round: round-040` with no pending merge rounds.
- Pending dependencies: none for this merge artifact. The reviewed payload is approved in `review.md` and `review-record.json`.

### Follow-Up Notes
- Payload files: `agent-workflow-github/agent-workflow-github.cabal`, `cabal.project`, and focused GitHub package-boundary assertions in `test/Main.hs`.
- Approved validation evidence: `cabal build agent-workflow-github:lib:agent-workflow-github`, `(cd agent-workflow-github && cabal check)`, source-boundary scans, forbidden descriptor scan with manual allowance for only the source repository URL, approved dependency-bound scan, `cabal build all`, `cabal test watcher-core-test`, and `git diff --check` all passed. No staged files were present, so cached diff checking was not applicable.
- Scope exclusions preserved: no moifold local-consumer rewiring, no compatibility facade removal, no production behavior changes, no command execution, no healthcheck changes, no PR/issue lifecycle policy changes, no merge/review publication policy changes, no event schema or golden fixture changes, no source distribution, no CI, no public docs or examples, no changelog or release notes, no package upload, no roadmap edits, and no module moves or renames.
- Dependency/order readiness: the standalone core and Codex package layout rounds are already complete, so this GitHub descriptor slice is ready before the later `direction-007-moifold-local-consumer-wiring` work that depends on locally buildable package descriptors.
- Merge note: the existing internal `moifold:agent-workflow-github` sublibrary intentionally remains in `moifold.cabal`; moifold consumer rewiring belongs to a later round.
