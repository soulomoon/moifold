### Checks Run
- Command: `git diff --check`
  Result: pass. No whitespace errors reported in the roadmap-update diff.
- Command: `git diff --cached --check`
  Result: pass. No staged whitespace errors reported.
- Command: `rg -n "milestone-003|direction-006|direction-007|pending|complete|remains pending|TODO|TBD|unfinished" orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md orchestrator/roadmap-updates/round-031-roadmap-update.md`
  Result: pass. The scan shows milestone 003 is complete, direction 006 remains complete via round 030, direction 007 is complete via round 031, and later milestones 004 and 005 remain pending. No TODO, TBD, unfinished, or stale "remains pending" marker was found for milestone 003 or direction 007.
- Command: `git show --stat --oneline --decorate --find-renames f36a9cc`
  Result: pass. The source merge commit is `f36a9cc` / `Extract generic daemon failure projection into workflow core`, touching the daemon core, moifold daemon wrapper, focused tests, and round-031 artifacts.
- Command: `git show --name-only --format='%H%n%s' f36a9cc`
  Result: pass. The commit hash is `f36a9ccdbb3e1380517093810250890319242cbd`, matching the roadmap update's merged commit reference.
- Command: `jq '{roadmap_id, roadmap_revision, roadmap_dir, controller_stage, last_completed_round, roadmap_update}' orchestrator/state.json`
  Result: pass. Roadmap metadata remains `2026-05-08-00-framework-kernel-migration`, `rev-001`, and `orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001`; roadmap_update records source round `round-031`, source commit `f36a9cc`, prior revision `rev-001`, proposed revision `rev-001`, and status `review`.
- Command: `git diff -U0 -- orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`
  Result: pass. The roadmap diff changes only milestone 003 status/progress text and direction 007 status.
- Command: `rg -n "Roadmap id|Roadmap revision|Roadmap style|Depends on|Parallel lane|Coordination notes|Preconditions|Boundary notes|Status: complete|round 031|f36a9cc|milestone-003|direction-007|direction-006" orchestrator/roadmaps/2026-05-08-00-framework-kernel-migration/rev-001/roadmap.md`
  Result: pass. Roadmap id, revision, style, dependencies, lanes, coordination notes, preconditions, and boundary notes remain unchanged; the only new status is direction 007 complete via round 031.
- Command: `git diff --name-only && git status --short`
  Result: pass. Candidate update changes are limited to the active roadmap file and controller state metadata, with the update artifact untracked before this review artifact was written.

### Roadmap Compliance
- Source-round evidence supports the update. `orchestrator/rounds/round-031/selection.md` selected `milestone-003-core-runtime-contracts`, `direction-007-daemon-core-boundary`, and `item-031-daemon-core-boundary`; `plan.md` required an ownership-neutral daemon boundary with concrete lifecycle ownership staying in moifold; `implementation-notes.md`, `review.md`, `review-record.json`, and `merge.md` record that the approved round added `WorkflowObservedDaemonTickFailure`, routed the moifold compatibility wrapper through it, strengthened focused tests and recursive scans, and passed `cabal build all`, `cabal test watcher-core-test`, `git diff --check`, and `git diff --cached --check`.
- The roadmap update marks only status/progress justified by round 031. It adds round-031 progress text for the daemon-core boundary, marks direction 007 complete via `f36a9cc`, and does not claim adapter API stabilization, extraction readiness, package publishing, event-schema migration, compatibility facade removal, or any unrelated milestone progress.
- Milestone 003 completion is justified. Direction 006 was already marked complete via round 030 in the existing roadmap, and round 031 now completes direction 007, which was the remaining milestone-003 direction.
- Roadmap metadata and sequencing are preserved. The update keeps roadmap id, revision, style, dependencies, preconditions, parallel lanes, coordination notes, boundary notes, future milestone ordering, and active roadmap revision at `rev-001`.
- State/revision metadata is consistent with an update-roadmap review. `state.json` records source round `round-031`, source commit `f36a9cc`, branch `orchestrator/roadmap-update-round-031-daemon-core-boundary`, prior revision `rev-001`, proposed revision `rev-001`, and review status without activating a new roadmap revision.

### Decision
**APPROVED**
