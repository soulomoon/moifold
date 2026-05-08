### Changes Made
- `src/CodexWatcher/Workflow/Moifold/PrReview/Reviewer/Indexed.hs`: Added the PR-review reviewer outcome indexed adapter as a thin `MoifoldSpec` wrapper with reviewer-specific typed points, observations, events, effect plans, replay results, and source/target labels.
- `moifold.cabal`: Exposed `CodexWatcher.Workflow.Moifold.PrReview.Reviewer.Indexed` from the main library.
- `test/Main.hs`: Added reviewer indexed parity coverage for normal clean, verification clean, missing fixed-thread normalization, problems, normal and verification incomplete outcomes, blocked outcomes, classifier-backed reviewer outputs, invalid observations, replay parity, apply parity, effect-plan labels, validation, and permissions.

### Tests
- `test/Main.hs`: Verifies reviewer indexed planning matches `prReviewObserve` and `MoifoldSpec` compatibility behavior for reviewer outcome transitions and classifier-backed observations.
- `test/Main.hs`: Verifies effect ordering remains unchanged for reviewer verification clean, reviewer problems, incomplete retries, and blocked terminal effects.

### Notes
The live daemon PR-review route was not changed. Event schemas, event type fields, golden logs, daemon result shapes, dry-run rendering, action ordering, compatibility facade exports, roadmap files, and `orchestrator/state.json` were left untouched by this implementation.

Verification run:
- `cabal build all`: passed.
- `cabal test watcher-core-test`: passed.
- `git diff --check`: passed.
- `git diff --cached --check`: passed.
