# Round 107 Merge

Merge decision: approved for controller merge.

Recommended squash commit title: Move issue-planning classifier to direct AppServerTurn import

Production file changed:
- `src/CodexWatcher/Domain/IssuePlanning/TurnClassifier.hs`

Validation summary:
- Target import scans passed.
- `cabal test watcher-core-test` passed.
- `cabal build all` passed.
- Descriptor/facade diff check passed.
- Confirmed no `worker-plan.json`.
- `git diff --check` passed.
- `git diff --cached --check` passed.
- JSON validation passed.

Non-goals:
- No facade removal or deprecation.
- No package descriptor or exposure changes.
- No docs, fixtures, tests, or protocol changes.
- No migration of other importers.
