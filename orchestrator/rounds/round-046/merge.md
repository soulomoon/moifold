### Squash Commit
- Title: Add package READMEs and Haddock boundary docs
- Summary: Adds package-facing READMEs for `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`, records each package's public module surface, guarantees, and non-goals, and adds concise Haddock module headers across the exposed package APIs. The staged payload also adds `extra-doc-files: README.md` to the three package descriptors and records the approved round plan, implementation notes, review, and review record.

### Merge Readiness
- Base branch freshness: confirmed. The round worktree branch `orchestrator/round-046-external-package-slice` is at the same local commit as `codex/workflow-facade-extraction` (`e0dad9b5916285bd7cba0500740d4cef36eb06af`) before applying the staged payload.
- Merge ordering satisfied: yes. `orchestrator/state.json` records `last_completed_round` as `round-045`, `pending_merge_rounds` as empty, and `merge_ready` as true for `round-046`. The declared dependencies on rounds 036, 039, 040, 041, 042, and 045 are therefore ordered before this merge.
- Pending dependencies: none for this approved payload. The staged diff intentionally excludes `orchestrator/state.json`; its current unstaged change is controller-owned bookkeeping.

### Follow-Up Notes
The reviewer approved the staged payload with no findings. Validation recorded in the review passed for `git diff --cached --check`, `git diff --check`, `cabal haddock agent-workflow-core agent-workflow-codex agent-workflow-github`, `scripts/validate-workflow-packages.sh`, `cabal build all`, `cabal test watcher-core-test`, README module-list checks, Haddock header checks, static overclaim scans, descriptor-scope inspection, and staged-path scope scans.

Haddock still reports missing per-export documentation, but that is outside this README and module-header round. Later public-docs rounds can add examples, consumer guides, changelog or release notes, and release-gate material without treating this round as a package publication claim.
