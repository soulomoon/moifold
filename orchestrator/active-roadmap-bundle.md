# Active Roadmap Bundle Contract

This file is the repo-local Interface for the active roadmap bundle. The active
roadmap bundle is the revision directory named by `orchestrator/state.json`
`roadmap_dir`.

The controller and roles must load this file before interpreting the active
bundle. If this file is missing from this control plane, runtime must record a
migration-needed controller error in `orchestrator/state.json.resume_errors`
and stop instead of falling back to scattered roadmap rules.

This file is not a shortcut to the active roadmap files. It defines how callers
read the active bundle, which files are required, when the roadmap is terminal,
and when a roadmap update must create a new revision.

## Required State Metadata

`orchestrator/state.json` must name the active bundle with all of:

- `roadmap_id`
- `roadmap_revision`
- `roadmap_dir`

Treat `roadmap_id` as an opaque scaffolded identifier. Preserve it verbatim and
do not recompute it from roadmap titles or directory names.

`roadmap_dir` must point at the active revision directory:

```text
orchestrator/roadmaps/<roadmap_id>/<roadmap_revision>/
```

## Required Files

The active revision directory must contain:

- `roadmap.md`
- `verification.md`
- `retry-subloop.md`

The roadmap family directory must contain:

- `roadmap-history.md`

Do not create or use top-level pointer stubs such as
`orchestrator/roadmap.md`, `orchestrator/verification.md`, or
`orchestrator/retry-subloop.md`.

## `roadmap.md`

`roadmap.md` is the coordination source for live and future work in the family.
It must be strategic: milestones are larger than rounds, and candidate
directions are extraction hints rather than implementation plans.

Required top-level sections:

- `## Goal`
- `## Alignment Summary`
- `## Outcome Boundaries`
- `## Global Sequencing Rules`
- `## Parallel Lanes`
- `## Milestones`

Each milestone heading under `## Milestones` must include one of these status
markers:

- `[pending]`
- `[in-progress]`
- `[completed]`
- `[done]`

The existing numbered heading form is valid, for example
`### 3. [in-progress] Import Convergence And Package-Boundary Cleanup`.
Unnumbered headings in the scaffold form, for example `### [pending] ...`, are
also valid. Treat `[completed]` and `[done]` as terminal-complete statuses for
that milestone.

Each milestone must include:

- `Milestone id:`
- `Depends on:`
- `Intent:`
- `Completion signal:`
- `Parallel lane:`
- `Coordination notes:`

Each candidate direction must include:

- `Direction id:`
- `Summary:`
- `Why it matters now:`
- `Preconditions:`
- `Parallel hints:`
- `Boundary notes:`
- `Extraction notes:`

## Terminal Detection

To decide whether the active roadmap bundle has unfinished work, inspect
milestone headings under `## Milestones` in `roadmap.md`.

- Any milestone marked `[pending]` is unfinished.
- Any milestone marked `[in-progress]` is unfinished.
- A roadmap is terminal only when every milestone under `## Milestones` is
  marked `[completed]` or `[done]`.

The following are parse errors, not terminal roadmaps:

- missing `## Milestones`
- milestone headings without a supported status marker
- unknown status markers
- malformed required milestone fields that make extraction or terminal
  detection ambiguous

On parse error, runtime must record the exact controller error in
`orchestrator/state.json.resume_errors.controller` instead of treating the
roadmap as terminal.

Terminal roadmap status alone is not controller completion. Runtime may claim
terminal completion only when the active bundle is terminal,
`state.json.active_rounds` is empty, no active `roadmap_update` remains, and no
unresolved resume errors remain.

## `verification.md`

`verification.md` is the repo- and roadmap-specific checklist for the active
revision.

It must include:

- `## Baseline Checks`
- `## Alignment Checks`
- `## Task-Specific Checks`
- `## Manual Checks`
- `## Roadmap Overrides`

Keep universal reviewer duties, lineage requirements, evidence requirements,
and approve/reject output formats in `orchestrator/roles/reviewer.md`. Keep
repo-wide invariants in `orchestrator/project-contract.md`.

## `retry-subloop.md`

`retry-subloop.md` records only repo- and roadmap-specific retry policy for the
active revision.

It must include:

- `## Retry Policy`
- `## Common Retry Cases`
- `## Removal Retry Boundary`
- `## Verification Carry-Forward`
- `## Roadmap Expansion Boundary`

Keep shared runtime mechanics in the runtime skill references and controller
state schema.

## Revision And History Rules

Used roadmap revisions are durable history. A roadmap update may modify the
current active revision only for status-only evidence, such as marking
completed work or adding compact completion pointers, when the reviewer
approves that no future coordination meaning changed.

Publish a new `rev-00N+1` directory under the same `roadmap_id` when a roadmap
update changes any of:

- future coordination
- milestone or direction meaning
- sequencing
- parallel lanes
- extraction scope
- verification meaning
- retry policy

Move completed detail to
`orchestrator/roadmaps/<roadmap_id>/roadmap-history.md`, or keep only compact
completion pointers in the active revision when those pointers affect remaining
work.
