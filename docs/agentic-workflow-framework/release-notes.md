# Package Candidate Release Notes

Status: release-note material for a future release-gate review. This is not a
release announcement, not upload approval, not source-distribution approval
beyond the local commands recorded for the current round, and not a final
go/no-go decision.

These notes cover the local `0.1.0.0` pre-1.0 package candidates:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

They summarize current package scope, metadata, validation evidence,
compatibility status, and remaining blockers. A reviewer still needs a separate
release-gate decision before any package publication action.

## Package Scope

`agent-workflow-core` provides the reusable workflow kernel. It owns typed
workflow specs, indexed bridge helpers, the pure `WorkflowM` authoring layer,
generic codec contracts, event-log core helpers, effect metadata, permission
policies, transaction runners, audit projections, daemon projections, and
failure classification. It intentionally does not own concrete moifold
`WatcherEvent` schemas, event JSON `type` labels, schema version policy,
golden replay policy, filesystem IO, runtime ownership, app-server transport,
GitHub command execution, healthcheck, repair, prompt policy, or lifecycle
decisions.

`agent-workflow-codex` provides the reusable Codex app-server adapter. It owns
JSON-RPC request construction, typed request/thread/turn ids, agent plan and
retry metadata, Codex protocol mapping, client parsing, interpreter records,
websocket transport, and the bridge from classified app-server turns into
workflow observations. It intentionally does not own app-server startup policy,
role prompt policy, structured-output acceptance policy, issue/PR lifecycle
routing, compatibility facade removal, healthcheck, repair, runtime ownership,
or release decisions.

`agent-workflow-github` provides the reusable GitHub adapter. It owns typed
repositories, issues, PRs, branches, review threads, commit SHAs, pure remote
parsers/classifiers, and pure `gh`/`git` command specs. It intentionally does
not execute commands, mutate worktrees, decide issue/PR lifecycle state, decide
merge readiness, publish review feedback, run healthcheck or repair, own Codex
adapter behavior, own moifold runtime policy, or make publication decisions.

## Metadata

The current descriptors record:

| Package | Version | Synopsis | License | Author | Maintainer | Category |
| --- | --- | --- | --- | --- | --- | --- |
| `agent-workflow-core` | `0.1.0.0` | Typed workflow kernel, replay, and effect plans | `MIT` | `soulomoon` | `soulomoon` | `Development` |
| `agent-workflow-codex` | `0.1.0.0` | Codex app-server protocol and typed agent adapter | `MIT` | `soulomoon` | `soulomoon` | `Development` |
| `agent-workflow-github` | `0.1.0.0` | GitHub identifiers, remote metadata, and command specs | `MIT` | `soulomoon` | `soulomoon` | `Development` |

Each descriptor points `source-repository head` at
`https://github.com/soulomoon/moifold.git`.

## Pre-1.0 Expectations

The package candidates are pre-1.0. The current `0.1.0.0` descriptors support
local validation and downstream example consumption, but they do not establish
a 1.0 compatibility line, package publication approval, or moifold product
policy ownership.

Breaking API changes before 1.0 must still be called out in changelog and
release-gate evidence when a future round makes such a change. This note does
not record any new breaking change; it summarizes the current package
candidates and public-doc evidence.

## Package Ownership

The package split follows this ownership model:

- `agent-workflow-core`: generic workflow kernel, replay, codecs, event-log
  cores, effect plans, permissions, transactions, audit, daemon projections,
  and reusable failure classification.
- `agent-workflow-codex`: Codex app-server protocol, typed agent plans and ids,
  client/protocol/interpreter/transport helpers, and agent observation helpers.
- `agent-workflow-github`: typed GitHub ids, pure remote parsers/classifiers,
  and pure command specs.
- `moifold`: issue planning, issue implementation, PR review, merge readiness,
  concrete event schemas, compatibility files, daemon/runtime ownership,
  app-server startup policy, healthcheck, repair, prompts, operator runbooks,
  and release decisions.

## Compatibility Facades

Compatibility facades remain available. Preferred imports are documented for
new reusable-package consumers, but this release-note material does not add a
deprecation pragma, require an import migration, remove a facade, or migrate
compatibility files.

Notable status:

- `CodexWatcher.AppServerClient` remains a moifold-owned facade over Codex
  client and transport modules.
- `CodexWatcher.Core.Ids` remains a moifold convenience facade over agent and
  GitHub ids.
- `CodexWatcher.Workflow.Types`, `CodexWatcher.Workflow.EventLog`,
  `CodexWatcher.Workflow.Execution`, and `CodexWatcher.Workflow.Permission`
  remain moifold product-facing surfaces where they expose concrete state,
  concrete events, concrete effect plans, replay policy, runtime action types,
  or phase validation.

## Validation Evidence

The validation evidence expected for the package-candidate release gate is:

- `cabal build all`
- `cabal test watcher-core-test`
- `scripts/validate-workflow-packages.sh`
- `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`

Round-048 local validation on 2026-05-09 passed all four commands above.

`scripts/validate-workflow-packages.sh` runs `cabal check` for
`agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`,
creates local source distributions, and verifies that each
`agent-workflow-*-0.1.0.0.tar.gz` archive contains its package root and Cabal
descriptor. The script prints that no upload or package publication command was
run.

## README, Haddock, And Consumer Evidence

Package-facing documentation currently includes:

- `agent-workflow-core/README.md`
- `agent-workflow-codex/README.md`
- `agent-workflow-github/README.md`
- Haddock module headers under `agent-workflow-core/src`,
  `agent-workflow-codex/src`, and `agent-workflow-github/src`
- `docs/agentic-workflow-framework/package-consumer-guide.md`
- `examples/workflow-package-consumer`

The consumer example has its own `cabal.project`, depends on the three package
candidates by local path, uses direct package-facing imports, and does not
depend on moifold.

## Remaining Moifold-Owned Policy

These topics remain outside the reusable package candidates:

- concrete `WatcherEvent` values, event JSON `type` labels, schema version
  policy, event codecs, and golden replay policy;
- compatibility files and compatibility facade lifecycle policy;
- issue planning, issue implementation, PR review, merge readiness, and review
  publication decisions;
- role prompts, structured-output policy, evidence rules, retry escalation, and
  classifier compatibility;
- filesystem writes, process execution, PID files, locks, leases, runtime
  ownership, daemon loops, app-server startup, and watcher supervision;
- healthcheck, repair tools, operator recovery choices, and runbooks;
- package publication, release-gate approval, and final release decisions.

## Blockers Before Publication

Before any publication action, a later release-gate review still needs to
approve the exact release evidence. At minimum, that review should check:

- descriptor metadata against current source and policy;
- package READMEs, Haddock, changelog, and release-note text against
  implemented APIs and public non-goals;
- local package checks and source-distribution validation results;
- `cabal build all` and `watcher-core-test` results for moifold plus package
  candidates;
- consumer-example output from `workflow-package-consumer`;
- compatibility facade status and any migration note;
- proof that moifold-owned event schemas, compatibility files, prompt policy,
  runtime ownership, healthcheck, and repair remain outside reusable package
  promises;
- explicit reviewer approval for the terminal release gate.
