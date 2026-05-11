# Round 109 Merge Artifact

Merge decision: approved for controller merge.

Selected item: `round-109-pr-review-turn-classifier-appserverclient-import-convergence`

Recommended squash commit title:

```text
Move PR-review classifier to direct AppServerTurn import
```

Production file changed:

- `src/CodexWatcher/Domain/PrReview/TurnClassifier.hs`

Production change:

- Replaced `import CodexWatcher.AppServerClient` with `import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn)`.

Behavior changed: none. Classifier exports, type signatures, parsing, and logic are unchanged.

Validation summary:

- Old target import scan found no matches.
- Direct-owner import scan found the selected import.
- PR-review classifier test discovery passed.
- `cabal test watcher-core-test` passed.
- `cabal build all` passed.
- Descriptor/facade diff was empty.
- Confirmed no `worker-plan.json`.
- `git diff --check` passed.
- `git diff --cached --check` passed.
- `jq` validation passed.

Explicit non-goals preserved:

- No public facade removal or deprecation.
- No Cabal exposure or package descriptor changes.
- No docs, fixtures, tests, or protocol changes.
- No endpoint, session, timeout, fallback, command, or failure-formatting changes.
- No other importer migration.
- No release, milestone, or terminal completion approval.
