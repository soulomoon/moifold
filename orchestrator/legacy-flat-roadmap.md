# Legacy Flat Roadmap

Use this only when an existing terminal control plane has
`roadmap_style: "legacy-flat"` or missing `roadmap_style`, and the setup is
preserving that style instead of explicitly migrating to `strategy-backlog`.

## Required Shape

Legacy flat roadmaps are a single ordered item list:

```md
# Roadmap

## Goal

<roadmap family goal>

## Items

### [pending] Item 1: <title>
Item id: item-001-example
Depends on:
Description: <what this item delivers>
Completion signal: <how this item is known complete>
Parallel safe: false
Parallel group:
Merge after item ids:
```

Allowed item statuses are `[pending]`, `[in-progress]`, and `[done]`.

## Required Item Fields

- `Item id:` stable within the roadmap family
- `Depends on:` item ids that must complete first, or empty
- `Description:` item scope
- `Completion signal:` concrete completion evidence
- `Parallel safe:` `true` or `false`
- `Parallel group:` optional co-scheduling group
- `Merge after item ids:` item ids that must merge first, or empty

## Runtime Mapping

For legacy flat selections:

- `roadmap_item_id` is the selected `Item id:`.
- `extracted_item_id` should mirror `roadmap_item_id` unless the guider needs a
  narrower stable id.
- `milestone_id` and `direction_id` are `null`.
- `merge_after_item_ids` uses legacy item ids.

## Terminal Detection

A legacy flat roadmap is unfinished when any `## Items` entry has status
`[pending]` or `[in-progress]`. Unknown item status is not terminal; stop and
record the exact parse problem instead of assuming completion.
