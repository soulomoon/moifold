### Checks Run
- Command: `sed -n '1,240p' orchestrator/roles/reviewer.md`
  Result: pass. Loaded the update-roadmap reviewer instructions and confirmed the required output artifact is `orchestrator/roadmap-updates/round-085-roadmap-update-review.md`.
- Command: `sed -n '1,260p' orchestrator/state.json`
  Result: pass. State selects roadmap `2026-05-11-00-highest-value-cleanup`, revision `rev-001`, controller stage `update-roadmap`, source round `round-085`, prior revision `rev-001`, proposed revision `rev-001`, and review artifact `orchestrator/roadmap-updates/round-085-roadmap-update-review.md`.
- Command: `sed -n '1,260p' orchestrator/project-contract.md`
  Result: pass. Contract requires public compatibility facades and compatibility files to remain available until exact reviewed removal gates, and names baseline checks for shared contracts.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md`
  Result: pass. Active roadmap remains `rev-001`; the proposed status marks `direction-003-facade-import-policy-test-split` complete by `round-085` at `fec075a` while keeping milestone 001 pending because direction 004 remains open.
- Command: `sed -n '1,220p' orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/verification.md`
  Result: pass. Verification allows artifact-only roadmap-update review to skip package build/test when changed-path evidence shows no production, test, package descriptor, runtime compatibility file, public API, fixture, docs, or behavior surface changed.
- Command: `sed -n '1,260p' orchestrator/roadmap-updates/round-085-roadmap-update.md`
  Result: pass. Update rationale cites round-085 evidence, keeps proposed revision `rev-001`, preserves non-removal boundaries, and states no state.json roadmap metadata update is required.
- Command: `sed -n '1,220p' orchestrator/rounds/round-085/selection.md`
  Result: pass. Source round selected `direction-003-facade-import-policy-test-split` under milestone 001 and explicitly kept production code, docs, fixtures, runtime compatibility files, public deprecation, facade removal, Cabal exposed modules, and state changes out of scope.
- Command: `sed -n '1,260p' orchestrator/rounds/round-085/plan.md`
  Result: pass. Plan required a test-only split into `test/FacadeImportPolicySpec.hs`, runner reachability through `workflowFacadeExtractionTests`, and preservation of compatibility-facade policy classifications.
- Command: `sed -n '1,260p' orchestrator/rounds/round-085/implementation-notes.md`
  Result: pass. Notes record the new focused test module, `test/Main.hs` aggregation, `watcher-core-test` metadata scope, no production/docs/fixture/runtime compatibility/roadmap/state changes, and line-count evidence from 15910 to 15473 lines.
- Command: `sed -n '1,280p' orchestrator/rounds/round-085/review.md`
  Result: pass. Round reviewer approved after `cabal test watcher-core-test`, `cabal build all`, `git diff --check`, `git diff --cached --check`, runner reachability, metadata scope, and non-removal checks.
- Command: `sed -n '1,220p' orchestrator/rounds/round-085/review-record.json && sed -n '1,220p' orchestrator/rounds/round-085/merge.md`
  Result: pass. Review record approved direction 003 for roadmap `rev-001`; merge notes identify merged commit `fec075a` and record no production, public facade exposure, docs, fixtures, roadmap files, or runtime compatibility files changed by the round.
- Command: `git status --short --untracked-files=all`
  Result: pass. Before writing this review, changed paths were the proposed roadmap edit, the controller-owned `orchestrator/state.json` review-stage update, and untracked `orchestrator/roadmap-updates/round-085-roadmap-update.md`.
- Command: `git diff --stat && git diff -- orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md orchestrator/roadmap-updates/round-085-roadmap-update.md`
  Result: pass. Tracked roadmap diff is status-only in the active `rev-001` roadmap. The untracked roadmap-update artifact was reviewed separately because it is not included in tracked diff output.
- Command: `git diff --name-status && git diff --cached --name-status`
  Result: pass. Tracked diff contains only `orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md` and controller-owned `orchestrator/state.json`; no staged diff exists.
- Command: `jq empty orchestrator/state.json orchestrator/rounds/round-085/review-record.json`
  Result: pass. JSON validation succeeded.
- Command: `git diff --check`
  Result: pass. No whitespace errors reported.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.
- Command: `rg -n 'Roadmap revision: `rev-001`|Prior revision: `rev-001`|Proposed revision: `rev-001`|Status: completed by `round-085`|milestone remains pending|direction 004|This status does not approve|Requires state\.json roadmap metadata update: no|proposed_roadmap_revision|roadmap_revision|roadmap_dir' orchestrator/state.json orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup/rev-001/roadmap.md orchestrator/roadmap-updates/round-085-roadmap-update.md`
  Result: pass. Confirmed active and proposed revisions remain `rev-001`, direction 003 is marked completed by round 085, milestone 001 remains pending because direction 004 remains open, non-removal disclaimers are present, and no state roadmap metadata update is requested.
- Command: `git diff -- orchestrator/state.json`
  Result: pass. State diff only adds the controller-owned `roadmap_update` review metadata; it does not activate a new roadmap revision, change `roadmap_revision`, or change `roadmap_dir`.
- Command: `git show --stat --oneline --no-renames fec075a --`
  Result: pass. Merged source commit is `fec075a Extract facade import policy tests`; changed paths match the round evidence for the focused test split plus round artifacts and state transition.
- Command: `find orchestrator/roadmaps/2026-05-11-00-highest-value-cleanup -maxdepth 2 -type d | sort`
  Result: pass. Only `rev-001` exists under the active roadmap family; no new revision directory was created.

### Roadmap Compliance
- Round evidence justifies the update: met. Round 085 selected and completed `direction-003-facade-import-policy-test-split`; implementation and review artifacts record the focused `test/FacadeImportPolicySpec.hs` extraction, preserved runner reachability through `workflowFacadeExtractionTests`, preserved facade/import-policy assertions, and passing `watcher-core-test` plus `cabal build all`.
- Direction 003 is marked complete: met. The roadmap now records `Status: completed by round-085 at fec075a` for `direction-003-facade-import-policy-test-split` and names the reviewed evidence from the split.
- Milestone 001 remains pending for direction 004: met. The milestone status remains `[pending]` and the current-status paragraph says the milestone remains pending because direction 004 still needs focused workflow behavior test extraction before the completion signal is met.
- Non-removal boundaries are preserved: met. The roadmap update states that the direction 003 status does not approve production import convergence, public deprecation, facade removal, Cabal exposure removal, runtime compatibility-file removal, or compatibility-file rename/deletion. This matches the project contract and source round boundaries.
- Proposed revision remains `rev-001`: met. State, active roadmap, and update artifact all keep prior and proposed roadmap revision at `rev-001`; no `rev-002` directory exists for this family.
- No state roadmap metadata activation is needed: met. The update artifact says state roadmap metadata update is not required, and the state diff only records controller `roadmap_update` review metadata. It does not change `roadmap_revision` or `roadmap_dir`.
- Changed-path rationale supports skipping package build/test for this update review: met. The update-roadmap diff is roadmap/status artifact work only. Source round behavior checks were already recorded in the approved round review, and no production, test, package descriptor, runtime compatibility file, public API, fixture, docs, or behavior surface changed in this update worktree.

### Decision
**APPROVED**
