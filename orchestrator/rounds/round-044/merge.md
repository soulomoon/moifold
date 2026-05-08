### Squash Commit
- Title: Add CI matrix package validation
- Summary: Adds an explicit GitHub Actions matrix row for the supported GHC `9.12.2` and Cabal `3.14.2.0` toolchain, wires setup to the matrix values, and expands CI to run `cabal build all`, `cabal test watcher-core-test`, and `scripts/validate-workflow-packages.sh`. The workflow also installs `ripgrep` before package validation so the round 043 check/sdist validator has its required hosted-runner dependency.

### Merge Readiness
- Base branch freshness: confirmed. The round worktree is on `orchestrator/round-044-external-package-slice`; local `HEAD` matches `codex/workflow-facade-extraction` at `c3c04e746c305a94ae54d434518dd8ffa5b29dc5`, and the base controller state has `last_completed_round` set to `round-043`.
- Merge ordering satisfied: yes. This round depends on `round-043` / `item-043-package-check-and-sdist`, and the base state records `last_completed_round: round-043` with `pending_merge_rounds: []`.
- Pending dependencies: none. `review.md` and `review-record.json` mark the round approved, the controller set `merge_ready: true`, and all local review gates passed.

### Follow-Up Notes
Remote GitHub Actions has not been run from this local review; readiness is based on approved local review evidence and static workflow inspection. The next maintainer should watch the first hosted CI run for package-validator environment drift, but no merge blocker remains for this round.
