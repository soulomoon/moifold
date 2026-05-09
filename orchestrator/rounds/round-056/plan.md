### Goal

Write an evidence-backed import-facade cleanup policy for the six selected
public moifold compatibility modules:

- `CodexWatcher.AppServerClient`
- `CodexWatcher.Core.Ids`
- `CodexWatcher.Workflow.Types`
- `CodexWatcher.Workflow.EventLog`
- `CodexWatcher.Workflow.Execution`
- `CodexWatcher.Workflow.Permission`

The round should produce documentation that tells reviewers and later removal
rounds which facades are `keep` versus `defer`, which replacement imports are
preferred for reusable package consumers, which tests protect the current
boundary, and which evidence is still missing before any deprecation or
removal can be proposed. It must not add deprecation pragmas, rewrite imports,
change Cabal exposure, remove or narrow modules, touch runtime
compatibility-file policy, migrate runtime files, expand the roadmap, or claim
removal approval.

### Approach

Keep this as a sequential docs-and-evidence round. Start from the approved
round 052 inventory and round 054 replacement-readiness artifact, then refresh
the live source scans before editing docs so the policy cites current tree
state rather than only prior conclusions.

Primary implementation artifacts:

- Update `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
  with a source-backed import-facade policy section if its current wording is
  stale or less precise than round 052/054 evidence.
- Add round-local policy evidence at
  `orchestrator/rounds/round-056/import-facade-cleanup-policy.md` summarizing
  the refreshed scans, Cabal exposure, preferred replacements, protecting
  tests, missing evidence, and `keep`/`defer` classifications.
- Check `orchestrator/project-contract.md` only for alignment. Update it only
  if the durable repo-wide compatibility-facade invariant is now inaccurate;
  otherwise leave it unchanged and cite that it already requires facades to
  stay available until a later round proves safe removal.

Use these source facts from the prior approved artifacts as the starting
classification, but refresh them against the current tree:

| Facade | Preferred replacement imports | Current classification |
| --- | --- | --- |
| `CodexWatcher.AppServerClient` | `CodexWatcher.Workflow.Agent.Codex.Client`; `CodexWatcher.Workflow.Agent.Codex.Transport` | `defer` |
| `CodexWatcher.Core.Ids` | `CodexWatcher.Workflow.Agent.Ids`; `CodexWatcher.Workflow.GitHub.Ids` | `defer` |
| `CodexWatcher.Workflow.Types` | `CodexWatcher.Workflow.Spec` for reusable code; keep this module for `MoifoldSpec` and concrete moifold labels/transitions | `keep` |
| `CodexWatcher.Workflow.EventLog` | `CodexWatcher.Workflow.EventLog.Core`; `CodexWatcher.Workflow.EventLog.File.Core`; `CodexWatcher.Workflow.EventLog.Commit.Core`; `CodexWatcher.Workflow.Audit` | `defer` |
| `CodexWatcher.Workflow.Execution` | `CodexWatcher.Workflow.Execution.Core` for reusable generic execution contracts | `keep` |
| `CodexWatcher.Workflow.Permission` | `CodexWatcher.Workflow.Permission.Core` for reusable permission checks | `defer` |

Do not upgrade any selected facade to `remove-later`. Round 054 did not approve
that classification for any import facade, and this selected item is policy
from evidence, not final cleanup.

### Steps

1. Re-read the selected scope and evidence inputs:
   `orchestrator/rounds/round-056/selection.md`,
   `orchestrator/rounds/round-052/import-facade-inventory.md`,
   `orchestrator/rounds/round-054/import-replacement-readiness.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/roadmap.md`,
   `orchestrator/roadmaps/2026-05-09-01-compatibility-surface-cleanup/rev-001/verification.md`,
   and `orchestrator/project-contract.md`. Use
   `orchestrator/rounds/round-055/runtime-file-behavior-gates.md` only to
   confirm that runtime compatibility-file policy remains a separate sibling
   direction and must not be edited in this round.

2. Refresh the current selected-facade import scan from the round worktree and
   capture the command plus high-level counts in the round-local evidence
   artifact:

   ```sh
   rg -n '^ *import +(qualified +)?CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission))($| +|\()' src app test examples agent-workflow-core agent-workflow-codex agent-workflow-github
   ```

   Treat matches in `agent-workflow-core`, `agent-workflow-codex`,
   `agent-workflow-github`, or `examples` as policy-relevant regressions, since
   round 054 found none there. Keep the summary focused on the six selected
   facade imports, not broad replacement submodule hits.

3. Refresh Cabal exposure and replacement-module exposure with:

   ```sh
   rg -n 'exposed-modules|CodexWatcher\.(AppServerClient|Core\.Ids|Workflow\.(Types|EventLog|Execution|Permission)|Workflow\.Agent\.Codex\.(Client|Transport)|Workflow\.Agent\.Ids|Workflow\.GitHub\.Ids|Workflow\.Spec|Workflow\.EventLog\.Core|Workflow\.EventLog\.File\.Core|Workflow\.EventLog\.Commit\.Core|Workflow\.Execution\.Core|Workflow\.Permission\.Core)' *.cabal */*.cabal
   ```

   The policy should state that the selected facades remain exposed by the main
   `moifold` library, while replacement modules are exposed by
   `agent-workflow-core`, `agent-workflow-codex`, and
   `agent-workflow-github`. Do not edit Cabal descriptors.

4. Inspect the selected facade modules and note whether the current module
   shape still matches round 052/054:
   `src/CodexWatcher/AppServerClient.hs`,
   `src/CodexWatcher/Core/Ids.hs`,
   `src/CodexWatcher/Workflow/Types.hs`,
   `src/CodexWatcher/Workflow/EventLog.hs`,
   `src/CodexWatcher/Workflow/Execution.hs`, and
   `src/CodexWatcher/Workflow/Permission.hs`. Preserve the distinction between
   pure reexport facades, combined convenience facades, and product-facing
   concrete moifold bridges.

5. Inspect the protecting tests in `test/Main.hs` and related compile-through
   tests named by rounds 052/054. The evidence artifact should cite the
   existing protections rather than adding tests in this docs-only round:
   package-boundary assertions, main-library facade availability,
   `AppServerClient` adapter ownership checks, workflow event-log parity,
   execution dry-run preservation, permission policy parity, indexed workflow
   compatibility, and compile-through coverage in `test/AppServerSpec.hs`,
   `test/CliSpec.hs`, `test/GhGitSpec.hs`, and `test/RuntimeSpec.hs`.

6. Write
   `orchestrator/rounds/round-056/import-facade-cleanup-policy.md` with these
   sections: scope and non-goals, refreshed scan evidence, Cabal exposure,
   surface-by-surface policy table, protecting tests, missing evidence before
   deprecation, missing evidence before removal, and explicit non-approval for
   removal. For each selected facade, include current source shape, current
   repo-local usage summary or count, preferred replacement imports, protecting
   tests, missing evidence, and the `keep` or `defer` classification.

7. Update `docs/agentic-workflow-framework/compatibility-deprecation-policy.md`
   so it points at the round 052 inventory, round 054 readiness, and round 056
   policy evidence. Align its table with the conservative classifications:
   `keep` for `CodexWatcher.Workflow.Types` and
   `CodexWatcher.Workflow.Execution`; `defer` for
   `CodexWatcher.AppServerClient`, `CodexWatcher.Core.Ids`,
   `CodexWatcher.Workflow.EventLog`, and
   `CodexWatcher.Workflow.Permission`. The wording must say preferred imports
   are guidance for reusable consumers only and do not create a deprecation
   warning, import migration requirement, Cabal exposure change, or removal
   approval.

8. Review `orchestrator/project-contract.md` against the updated policy. If it
   already says public compatibility facades stay available until safe removal
   is proven, leave it unchanged. If it is updated, keep the edit durable and
   narrow: compatibility cleanup sequencing and facade availability only, with
   no runtime compatibility-file policy changes.

9. Do a final grep over the diff to ensure the round did not introduce banned
   claims or accidental scope expansion. In particular, reject wording that
   says any selected facade is approved for removal, that deprecation pragmas
   should be added now, that Cabal exposed modules should change now, or that
   runtime compatibility files are part of this policy slice.

### Verification

Run the evidence scans from steps 2 and 3 and record the relevant summary in
the round-local policy evidence. Then run:

```sh
git diff --check
cabal test watcher-core-test
```

If only Markdown/project-contract documentation changed, `cabal test
watcher-core-test` is still the preferred compatibility check because
`test/Main.hs` protects the package-boundary and facade assertions cited by
the policy. If it cannot be run, record the blocker explicitly in the final
round notes and do not imply test validation.

Before handoff, inspect the final diff and confirm:

- no production Haskell source was edited;
- no import was rewritten;
- no Cabal descriptor was edited;
- no deprecation pragma, warning policy, or removal approval was added;
- no runtime compatibility-file behavior, schema, filename, or policy was
  changed;
- the policy cites current scans, Cabal exposure, preferred replacements,
  protecting tests, missing evidence, and the round 052/054 classifications.
