# Package Candidate Changelog

Status: source-backed changelog material for local package candidates. This is
not a release announcement, not upload approval, and not a publication
decision.

This changelog records candidate-facing changes for:

- `agent-workflow-core`
- `agent-workflow-codex`
- `agent-workflow-github`

The entries below describe the current local `0.1.0.0` package candidates and
the evidence that should be reviewed at a future release gate. The packages
remain pre-1.0, and this document does not widen their compatibility promise
beyond the package identity, metadata, compatibility, validation, README, and
consumer-guide evidence already recorded in this tree.

## 0.1.0.0 Local Package Candidates

### Shared Metadata

- Added standalone package candidate descriptors for `agent-workflow-core`,
  `agent-workflow-codex`, and `agent-workflow-github`, each at version
  `0.1.0.0`.
- Recorded descriptor metadata aligned with the release-metadata policy:
  `license: MIT`, `author: soulomoon`, `maintainer: soulomoon`,
  `category: Development`, and `source-repository head` at
  `https://github.com/soulomoon/moifold.git`.
- Kept the candidates as local pre-1.0 package surfaces. The matching version
  number does not imply a 1.0 contract, public release approval, or moifold
  lifecycle ownership.
- Kept moifold as the concrete product owner for workflow lifecycle policy,
  compatibility files, app-server startup policy, event schemas, prompt policy,
  runtime ownership, healthcheck, repair, and release decisions.

### agent-workflow-core

- Added the reusable workflow-kernel candidate for typed workflow specs,
  replay helpers, codec contracts, event-log cores, effect metadata,
  permission policies, transaction runners, audit projections, daemon
  projections, and failure classification.
- Kept the dependency set generic: `base`, `bytestring`, and `text`.
- Kept adapter and product ownership out of the core package. The core
  candidate does not own Codex protocol, GitHub command parsing, concrete
  `WatcherEvent` codecs, event JSON `type` labels, schema version policy,
  golden replay policy, filesystem IO, process execution, or moifold lifecycle
  decisions.
- Documented the package surface in `agent-workflow-core/README.md` and the
  module Haddock headers under `agent-workflow-core/src`.

### agent-workflow-codex

- Added the reusable Codex adapter candidate for app-server JSON-RPC request
  construction, typed request/thread/turn ids, agent plan and retry metadata,
  Codex protocol mapping, client parsing, interpreter boundaries, websocket
  transport, and observation helpers.
- Recorded the package dependency on `agent-workflow-core >=0.1 && <0.2` plus
  its adapter dependencies: `aeson`, `base`, `bytestring`, `text`, and
  `websockets`.
- Kept product policy outside the adapter. The package does not decide
  app-server process supervision, role prompts, structured-output acceptance,
  issue/PR lifecycle transitions, compatibility facade removal, healthcheck,
  repair, runtime ownership, or package publication.
- Documented the package surface in `agent-workflow-codex/README.md` and the
  module Haddock headers under `agent-workflow-codex/src`.

### agent-workflow-github

- Added the reusable GitHub adapter candidate for typed repositories, issues,
  PRs, branches, review threads, commit SHAs, pure remote parsers/classifiers,
  and pure `gh`/`git` command specs.
- Kept the package dependency set to `aeson`, `base`, and `text`; it does not
  depend on `agent-workflow-core`, `agent-workflow-codex`, or moifold.
- Kept command execution and lifecycle policy outside the adapter. The package
  does not decide issue/PR state transitions, merge readiness, review
  publication, local worktree mutation, healthcheck, repair, Codex agent
  behavior, runtime ownership, or package publication.
- Documented the package surface in `agent-workflow-github/README.md` and the
  module Haddock headers under `agent-workflow-github/src`.

### Documentation And Example Evidence

- Added package READMEs for all three candidates, with links to the implemented
  API freeze, package extraction readiness report, package validation recipe,
  compatibility policy where relevant, package consumer guide, and the
  buildable local consumer example.
- Added `docs/agentic-workflow-framework/package-consumer-guide.md` guidance
  for direct package-facing imports and local path dependencies.
- Added `examples/workflow-package-consumer`, which consumes
  `agent-workflow-core`, `agent-workflow-codex`, and `agent-workflow-github`
  through local package paths and avoids moifold product imports.

### Validation Evidence

The candidate validation path for this changelog entry is:

- `cabal build all`
- `cabal test watcher-core-test`
- `scripts/validate-workflow-packages.sh`
- `(cd examples/workflow-package-consumer && cabal run workflow-package-consumer)`

Round-048 local validation on 2026-05-09 passed all four commands above.

The validation script runs `cabal check` for each package candidate, creates
local source distributions under `dist-newstyle/sdist/`, verifies the expected
`agent-workflow-*-0.1.0.0.tar.gz` files, checks that each archive has the
expected package root, and checks that each archive contains the matching Cabal
descriptor. Those artifacts are local evidence only.

### Compatibility Status

- The current compatibility facade policy remains unchanged. Existing moifold
  compatibility modules and compatibility files stay available until a later
  selected round proves and approves a migration.
- Preferred imports point at package-facing modules such as
  `CodexWatcher.Workflow.*`, `CodexWatcher.AppServerProtocol`,
  `CodexWatcher.Workflow.Agent*`, and
  `CodexWatcher.Workflow.GitHub.*`.
- No deprecation pragma, import migration, compatibility facade removal,
  compatibility-file migration, event-schema migration, prompt-policy
  migration, healthcheck ownership change, repair ownership change, or runtime
  ownership change is part of this changelog entry.

### Explicit Non-Goals

- No `cabal upload`, `stack upload`, `gh release`, or `git tag` action is
  described or approved by this changelog.
- No final go/no-go decision is recorded here.
- No public API stability beyond the pre-1.0 contract is claimed here.
- No package publication, source-distribution approval beyond local validation
  commands, compatibility facade removal, or moifold lifecycle migration is
  claimed here.
