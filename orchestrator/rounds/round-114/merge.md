### Squash Commit
- Title: Add AppServerProbe command coverage
- Summary: Adds endpoint-backed `probeAppServer` command tests covering initialize-only probing, existing-thread smoke checks, smoke thread creation, smoke turn start, request id progression, selected params, success output, and representative JSON-RPC/decode failure formatting. The implementation is test-only: it adds `test/AppServerProbeSpec.hs`, wires it into `test/Main.hs`, and adds the module to `watcher-core-test` metadata in `moifold.cabal`.

### Merge Readiness
- Base branch freshness: confirmed locally; `HEAD`, `codex/workflow-facade-extraction`, and `orchestrator/round-114-highest-value-cleanup-slice` are all at `f46f120`, and local ancestry checks show the base and round branch match before the approved uncommitted round diff. Remote freshness could not be established because `origin` did not advertise `codex/workflow-facade-extraction` or `orchestrator/round-114-highest-value-cleanup-slice`.
- Merge ordering satisfied: yes; `round-114` is approved, state is `stage = merge`, `merge_ready = true`, and there are no declared `depends_on_round_ids` or `merge_after_item_ids`.
- Pending dependencies: none.

### Follow-Up Notes
Changed paths are limited to expected test/controller/artifact scope: `test/AppServerProbeSpec.hs`, `test/Main.hs`, `moifold.cabal`, `orchestrator/state.json`, and `orchestrator/rounds/round-114/*`. Production, facade, direct-owner, and protocol modules are unchanged. This round records command-level coverage for later `AppServerClient` import convergence; it does not perform production import migration, facade removal, Cabal/API cleanup, public deprecation, milestone completion, or release approval.
