# Project Contract

This file records repo-wide invariants shared by every roadmap family and
round. Keep roadmap revisions focused on current coordination; point here for
stable contracts instead of restating them in every role or roadmap file.

## Stable Interfaces

- Event schemas: preserve current `WatcherEvent` JSON `type` fields, schema
  versions, parse behavior, and golden event-log fixtures unless a roadmap
  explicitly authorizes a compatibility migration with old-log coverage.
- Golden logs and fixtures: golden replay fixtures for PR review, issue
  planning, issue implementation, and DocsMigration are compatibility
  contracts. A round that touches replay or codecs must prove old fixture
  behavior remains stable.
- Dry-run or command-rendering output: dry-run reports, rendered GitHub/git
  command text, app-server request rendering, action ordering, and request-id
  progression are user-visible contracts.
- Package and module boundaries: `agent-workflow-core` owns generic workflow
  kernel contracts only; `agent-workflow-codex` owns Codex app-server protocol
  and typed agent adapters; `agent-workflow-github` owns GitHub identifiers,
  remote metadata, and command rendering helpers; the main moifold library owns
  concrete issue/PR lifecycle policy, daemon ownership, process execution,
  filesystem writes, compatibility snapshots, healthcheck, and repair.
- Public compatibility facades: keep existing moifold compatibility modules
  available until a round proves safe removal with import, build, and behavior
  coverage. Compatibility files such as `issue-state.json`, `daemon-state.json`,
  `planning-state.json`, PR URL files, block state, repair state, and runtime
  owner files keep their current names and field meanings unless explicitly
  migrated.

## Alignment Invariants

- Human-approved architecture constraints: preserve the framework thesis
  `State -> Event -> Decision -> EffectPlan -> Interpreter`; event logs remain
  truth; agent output enters workflow policy only as classified observations;
  effects remain inspectable data before interpretation.
- Compatibility promises: no event schema, golden log, daemon result shape,
  dry-run rendering, action ordering, compatibility write timing, runtime
  command rendering, prompt schema, or structured-output requirement may change
  as incidental cleanup.
- Explicit non-goals that should not be reopened without a new roadmap family:
  no package publishing yet; no generic prompt runner; no workflow `liftIO`;
  no YAML-defined state machines; no moving concrete moifold issue/PR lifecycle
  policy into generic core just to satisfy package shape.

## Verification Anchors

- Invariants every reviewer should consider when touched: replay determinism,
  observation-to-event consistency, permission soundness, dry-run safety,
  terminal-state closure, package-boundary imports, compatibility facade
  availability, and adapter ownership.
- Baseline commands that protect shared contracts: `cabal build all`,
  `cabal test watcher-core-test`, `git diff --check`, and
  `git diff --cached --check` when staging is involved.

## Update Rule

Update this file only when the repo-wide invariant itself changes. When a
roadmap temporarily narrows or extends an invariant, record the override in the
active roadmap bundle and keep the durable rule here.
