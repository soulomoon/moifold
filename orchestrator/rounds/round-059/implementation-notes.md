# Implementation Notes

Round: `round-059`
Milestone: `milestone-004-expand-follow-up-backlog`
Direction: `direction-008-roadmap-expansion-update`
Extracted item: `round-059-roadmap-expansion-update`

## Summary

Created immutable roadmap revision `rev-002` for
`2026-05-09-01-compatibility-surface-cleanup`. The revision carries forward
the evidence-first cleanup thesis, marks milestones 001-004 complete with
compact progress pointers through round 059, and inserts follow-up evidence
milestones before any gated removal work:

- import-facade evidence from round 058 candidates;
- runtime compatibility evidence from round 058 candidates;
- cross-cutting external operator/downstream inventory;
- gated removals only after those evidence milestones and explicit reviewer
  approval;
- closeout after removal rounds or an explicit hold.

This round did not edit production source, tests, Cabal descriptors, docs
policy, fixtures, scripts, runtime compatibility files, import surfaces,
`orchestrator/project-contract.md`, `orchestrator/state.json`, or used
`rev-001` artifacts.

## Activation Notes

After this branch merges and update-roadmap accepts the revision, the
controller should set:

- `roadmap_id`: `2026-05-09-01-compatibility-surface-cleanup`
- `roadmap_revision`: `rev-002`
- `roadmap_dir`:
  `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002`

## Files Written

- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/roadmap.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/verification.md`
- `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-002/retry-subloop.md`
- `orchestrator/rounds/round-059/implementation-notes.md`

## Verification

- `test -f` readback for round plan, the three `rev-002` files, and absence
  of `orchestrator/rounds/round-059/worker-plan.json`: pass.
- `rg` readback for roadmap id, revision `rev-002`, `strategy-backlog`,
  activation metadata, evidence milestones, and gated-removal boundaries:
  pass after rerunning with corrected shell quoting.
- `rg '^### [0-9]+\\. \\[(complete|pending)\\]'` on `rev-002/roadmap.md`:
  pass. Milestones 001-004 are complete; milestones 005-007 are follow-up
  evidence before milestone 008 gated removals and milestone 009 closeout.
- `git status --short` and `git diff --name-only`: pass. Only the expected
  untracked orchestrator artifact directories are present; tracked diff is
  empty.
- Forbidden tracked diff check for `rev-001`, `roadmap-history.md`,
  `project-contract.md`, `state.json`, source, tests, app, scripts, docs,
  golden fixtures, and Cabal descriptors: pass. No output.
- `git diff --check`: pass.
- `git diff --no-index --check /dev/null <new artifact>` for the four new
  untracked artifacts: pass for whitespace.

Full Cabal/package baselines were not run because the diff is artifact-only
and does not touch production source, tests, Cabal descriptors, docs policy,
fixtures, scripts, runtime compatibility files, import surfaces, or package
metadata.

## Blockers

No implementation blockers. Later cleanup remains blocked on the rev-002
evidence milestones and explicit reviewer approval for exact selected removal
surfaces.
