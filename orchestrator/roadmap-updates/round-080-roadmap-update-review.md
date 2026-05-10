### Checks Run
- Command: `git status --short --untracked-files=all`
  Result: pass. Worktree contains the expected roadmap update changes only before this review: modified `orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md` and untracked `orchestrator/roadmap-updates/round-080-roadmap-update.md`.
- Command: `git diff --check`
  Result: pass. No whitespace errors in tracked unstaged diff.
- Command: `git diff --cached --check`
  Result: pass. No staged diff.
- Command: `git diff --name-only && git diff --cached --name-only`
  Result: pass. Tracked unstaged diff is limited to the active roadmap file; there are no staged files.
- Command: `git diff -- orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md orchestrator/roadmap-updates/round-080-roadmap-update.md`
  Result: pass. The tracked roadmap diff changes only milestone 003 status/progress and direction 006 status; the update artifact is untracked and was read directly.
- Command: `git show --stat --oneline --decorate --no-renames 7c8a3cd`
  Result: pass. Commit `7c8a3cd` is `Defer deprecation for selected public facades` and contains round-080 artifacts plus state transition metadata.
- Command: `sed -n '1,260p' orchestrator/state.json`
  Result: pass. State is in `update-roadmap`, source round is `round-080`, source commit is `7c8a3cd`, prior and proposed roadmap revisions are both `rev-001`, and the review artifact path is this file.
- Command: `sed -n '1,240p' orchestrator/project-contract.md`
  Result: pass. Contract preserves public compatibility facades until safe removal is proven and forbids treating the prior terminal hold as deprecation, migration, Cabal exposure, or removal approval.
- Command: `sed -n '1,260p' orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/verification.md`
  Result: pass. Verification rules require selected-facade scope, no runtime compatibility/event/healthcheck/repair/release expansion, and explicit approval for deprecation or removal decisions.
- Command: `sed -n '1,240p' orchestrator/roadmap-updates/round-080-roadmap-update.md`
  Result: pass. The update artifact describes a status-only update within `rev-001` and states no `state.json` roadmap metadata update is required.
- Command: `sed -n '1,260p' orchestrator/rounds/round-080/deprecation-readiness-decision.md`
  Result: pass. The merged decision records all four selected facades as `defer` and states no production code, tests, docs, Cabal/package descriptors, API, deprecation pragmas, public wording, exposed modules, runtime compatibility files, event schemas, healthcheck, repair, import migrations, or facade removals changed.
- Command: `sed -n '1,260p' orchestrator/rounds/round-080/review.md`
  Result: pass. Round review approved the artifact-only decision and confirmed missing gates are blockers, not approval for public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, or removal.
- Command: `sed -n '1,220p' orchestrator/rounds/round-080/selection.md`
  Result: pass. Selection identifies milestone 003, direction 006, and explicitly keeps production code, tests, docs, package descriptors, public deprecation wording, `DEPRECATED` pragmas, Cabal exposure changes, facade removal, event schema changes, runtime compatibility files, healthcheck, repair, release/publication decisions, `Workflow.Types`, and `Workflow.Execution` out of scope.
- Command: `sed -n '1,200p' orchestrator/rounds/round-080/merge.md && sed -n '1,160p' orchestrator/rounds/round-080/review-record.json`
  Result: pass. Merge and review record approve the artifact-only defer decision and identify roadmap `2026-05-10-00-facade-removal-readiness`, revision `rev-001`, milestone 003, and direction 006.
- Command: `rg -n "public deprecation wording|DEPRECATED|docs changes|Cabal exposure|public API|facade removal|runtime compatibility|event schema|healthcheck|repair|release|publication|direction-007|milestone 003|in progress|rev-001|State Activation" orchestrator/roadmaps/2026-05-10-00-facade-removal-readiness/rev-001/roadmap.md orchestrator/roadmap-updates/round-080-roadmap-update.md orchestrator/state.json`
  Result: pass. The roadmap/update text frames those surfaces as explicitly unapproved, keeps milestone 003 in progress because direction 007 remains pending, and keeps revision metadata at `rev-001`.

### Roadmap Compliance
- The roadmap update is justified by merged round evidence. Round 080 approved an artifact-only public deprecation-readiness decision for `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`, `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`, with all four selected facades recorded as `defer`.
- Direction 006 is correctly marked complete. The update cites round 080 and commit `7c8a3cd`, and the round review plus review record approve the direction-006 decision.
- Milestone 003 is correctly marked in progress, not complete. Direction 006 is complete, but direction 007, `direction-007-cabal-exposure-decision`, remains pending and has no completion status in the roadmap.
- No new roadmap revision activation is required. `orchestrator/state.json` records `prior_roadmap_revision: rev-001` and `proposed_roadmap_revision: rev-001`, and the update artifact states the change is status-only with no roadmap metadata update.
- The update does not imply public deprecation wording, `DEPRECATED` pragmas, docs/Haddock/Cabal/API/exposure changes, release/publication, runtime compatibility-file cleanup, event schema changes, healthcheck changes, repair changes, or facade removal approval. It repeatedly states these surfaces were not approved or changed.
- The update does not convert preferred-import or migration-path evidence into removal approval. It preserves the roadmap rule that deprecation, Cabal exposure, and removal require later exact reviewed approval.
- The update stays inside the active facade-removal-readiness family and does not cite the closed compatibility-surface cleanup terminal hold as deprecation, migration, Cabal exposure, or removal approval.

### Decision
**APPROVED**
