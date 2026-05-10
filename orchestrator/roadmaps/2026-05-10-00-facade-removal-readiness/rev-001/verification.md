# Verification: Facade Removal Readiness

Roadmap id: `2026-05-10-00-facade-removal-readiness`
Roadmap revision: `rev-001`

## Baseline Checks

- `cabal build all`
- `cabal test watcher-core-test`
- `git diff --check`
- `git diff --cached --check` when staging is involved

If a round changes package descriptors, exposed modules, README/Haddock wording,
or source-distribution metadata, the reviewer must require a focused validation
command or manual check for that touched surface in addition to the baseline.

## Alignment Checks

- Confirm the round records roadmap lineage for
  `2026-05-10-00-facade-removal-readiness` and does not append work to the
  closed `2026-05-09-01-compatibility-surface-cleanup` family.
- Confirm no round treats the previous terminal hold as deprecation, migration,
  Cabal exposure, or removal approval.
- Confirm the round scope stays focused on the selected import facades:
  `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
  `CodexWatcher.Workflow.EventLog`, and `CodexWatcher.Workflow.Permission`.
- Confirm `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.Execution`,
  runtime compatibility files, event JSON `type` values, healthcheck, repair,
  and release/publication decisions remain out of scope unless a reviewed
  roadmap update explicitly changes scope.
- Confirm every deprecation or removal decision names the exact surface and
  records current import scans, behavior evidence, package-boundary evidence,
  documentation/Cabal evidence when relevant, and reviewer approval.
- Confirm internal import migrations preserve compatibility facade availability
  until an exact later removal is approved.

## Task-Specific Checks

Reviewers should require each round to add or record focused checks matching the
surface it touches, such as:

- import-scan evidence over `src`, `app`, `test`, package descriptors, and docs;
- package-boundary assertions when imports move between moifold and reusable
  package candidates;
- golden replay, event-log, permission, or phase-validation checks when
  `Workflow.EventLog` or `Workflow.Permission` behavior is touched;
- command-rendering, app-server protocol, endpoint, or failure-formatting checks
  when `AppServerClient` imports are changed;
- parser/rendering checks for ids, branch names, PR numbers, issue numbers,
  thread ids, request ids, and review thread ids when `Core.Ids` imports are
  split;
- Cabal exposed-module and documentation checks when public surface changes.

## Manual Checks

- Review the final decision record for each selected facade and verify the
  status is one of keep, defer, deprecate, or remove.
- For any externally visible change, verify docs, package descriptors, release
  metadata policy, and compatibility policy agree on the exact status.
- For terminal closeout, verify the final report lists kept, deferred,
  deprecated, removed, and blocked surfaces and does not imply package upload or
  release approval.

## Roadmap Overrides

- `remove-later` or preferred-import wording is not removal approval.
- Local absence of an import is not enough to remove an exposed module unless
  the round records the consumer inventory scope and reviewer approval accepts
  that scope.
- Any broadened runtime compatibility-file cleanup requires a reviewed roadmap
  update before implementation.
