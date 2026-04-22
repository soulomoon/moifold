{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.PromptTemplates
  ( PromptTemplate (..)
  , issueImplementationTemplate
  , issuePlanTemplate
  , issueTriageTemplate
  , plannerTemplate
  , prReviewWorkerTemplate
  , prReviewThreadDeveloperTemplate
  , renderTemplate
  , reviewerPromptVersion
  , reviewerTemplate
  ) where

import Data.Text (Text)
import Data.Text qualified as Text

data PromptTemplate = PromptTemplate
  { promptTemplateName :: Text
  , promptTemplateBody :: Text
  }
  deriving stock (Eq, Show)

renderTemplate :: PromptTemplate -> [(Text, Text)] -> Text
renderTemplate template variables =
  foldl replaceOne template.promptTemplateBody variables
 where
  replaceOne text (key, value) =
    Text.replace ("{{" <> key <> "}}") value text

reviewerPromptVersion :: Text
reviewerPromptVersion =
  "haskell-pro-style-v2-merge-clean"

plannerTemplate :: PromptTemplate
plannerTemplate =
  PromptTemplate
    "planner.md"
    ( Text.unlines
        [ "{{structuredInstructions}}"
        , ""
        , "For issue planning, inspect existing GitHub issues and existing sub-issues before splitting work."
        , "Use issues_to_create only for independent top-level issues."
        , "Use subissues_to_create for GitHub sub-issues, and every subissues_to_create item must include title, a concrete body, and parentIssueNumber."
        , "A sub-issue body must describe scope, acceptance criteria, dependencies/blockers, and how it stays compatible with sibling sub-issues."
        , "When a parent issue already has sub-issues, new sub-issues must be compatible with the existing set: do not duplicate titles/scopes, do not create overlapping work, and preserve dependency boundaries between siblings."
        , "After issue creation the watcher will re-enter planning."
        , "When no more issues need to be created, return ready_issues for issues safe to implement now, blocked_issues for issues that must wait, and dependencies for issue ordering."
        , "ready_issues must be an array of issue numbers, not objects."
        , "blocked_issues must use objects shaped as {\"issueNumber\": 27, \"blockedBy\": [26], \"reason\": \"...\"}."
        , "dependencies must use objects shaped as {\"issueNumber\": 27, \"dependsOn\": [26]}."
        , "Only issues listed in ready_issues can be started by fanout; do not list an issue as ready if another open issue must be completed first."
        , "Use outcome=complete only when the issue graph is stable and ready for dependency-aware implementer fanout."
        , "{{scopeInstructions}}"
        ]
    )

issueTriageTemplate :: PromptTemplate
issueTriageTemplate =
  PromptTemplate
    "issue-triage.md"
    ( Text.unlines
        [ "{{structuredInstructions}}"
        , ""
        , "This is an issue implementation triage turn."
        , "Only inspect the issue, repository state, existing branches, and existing PRs."
        , "Do not edit files, commit, push, create PRs, write watcher state, or write events.jsonl."
        , "Return already_fixed when the issue is already solved on the target branch, needs_implementation when implementation is still required, or blocked with reason when it cannot proceed."
        ]
    )

issuePlanTemplate :: PromptTemplate
issuePlanTemplate =
  PromptTemplate
    "issue-plan.md"
    ( Text.unlines
        [ "{{structuredInstructions}}"
        , ""
        , "This is an issue implementation plan turn."
        , "Produce and persist an implementation plan in the repository or PR body only when requested by the surrounding workflow."
        , "Do not implement code changes, commit, push, create PRs, write watcher state, or write events.jsonl."
        , "Return complete with a concise plan summary when the implementation plan is ready, or blocked with reason when planning cannot proceed."
        ]
    )

issueImplementationTemplate :: PromptTemplate
issueImplementationTemplate =
  PromptTemplate
    "issue-implementation.md"
    ( Text.unlines
        [ "{{structuredInstructions}}"
        , ""
        , "This is an issue implementation turn."
        , "Follow the existing implementation plan, edit code, run relevant tests, commit, and push to the configured branch when changes are ready."
        , "Do not create or mutate watcher events.jsonl, issue-state.json, daemon-state.json, pid files, or other watcher runtime state."
        , "Return complete only when the PR branch is ready for review, incomplete with reason when more implementation work remains, or blocked with reason when you cannot proceed."
        ]
    )

prReviewWorkerTemplate :: PromptTemplate
prReviewWorkerTemplate =
  PromptTemplate
    "pr-review-worker.md"
    ( Text.unlines
        [ "{{structuredInstructions}}"
        , ""
        , "This is a PR review-fix worker turn."
        , "Address unresolved review comments on the current PR, run relevant tests, commit, and push fixes."
        , "Do not mutate watcher runtime state files."
        , "Return complete when review comments were addressed, incomplete when follow-up work remains, or blocked with reason when you cannot proceed."
        ]
    )

prReviewThreadDeveloperTemplate :: PromptTemplate
prReviewThreadDeveloperTemplate =
  PromptTemplate
    "pr-review-thread-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only PR {{role}} for {{repoFullName}}#{{prNumber}}."
        , "PR URL: https://github.com/{{repoFullName}}/pull/{{prNumber}}."
        , "Your working directory is {{workdir}}."
        , "The PR branch is {{branch}}."
        , "Use {{model}}/{{effort}} for turns."
        , ""
        , "General responsibilities:"
        , "- Do not mutate watcher runtime state files unless a turn prompt explicitly asks for a reviewer-state JSON file."
        , "- Do not use dynamic client-only tools such as js_repl."
        , "- Use English for every message in this thread."
        ]
    )

reviewerTemplate :: PromptTemplate
reviewerTemplate =
  PromptTemplate
    "reviewer.md"
    ( Text.unlines
        [ "Scheduled PR reviewer tick for {{repoFullName}}#{{prNumber}}."
        , ""
        , "PR URL: https://github.com/{{repoFullName}}/pull/{{prNumber}}"
        , "Working directory: {{workdir}}"
        , "PR branch: {{branch}}"
        , "Review target commit SHA: {{reviewTargetSha}}"
        , "Reviewer prompt version: {{reviewerPromptVersion}}"
        , "Write reviewer state: {{reviewerStatePath}}"
        , ""
        , "The watcher only starts you when GitHub GraphQL reports no unresolved review threads."
        , "Use English for every message in this thread."
        , ""
        , "Review responsibilities:"
        , "1. If the PR touches Haskell code and `/root/.codex/skills/haskell-pro/SKILL.md` is available, read it and use it as your review guideline."
        , "2. Review the PR diff for {{reviewTargetSha}} and inspect only the surrounding code needed to verify findings or suggestions."
        , "3. If you find actionable bugs, regressions, missing tests, behavioral risks, style issues, refactoring opportunities, or simplification opportunities, add inline GitHub PR review comments that create unresolved review threads. Do not rely on top-level-only PR comments."
        , "4. Style/refactor/simplify comments must be concrete, local, and worth addressing; avoid subjective preference-only feedback."
        , "5. Prefer precise inline review comments on changed lines. Do not create duplicate comments for issues already covered by existing review history."
        , "6. Do not edit files, commit, push, or resolve review threads."
        , "7. If no actionable issues or suggestions are found, do not submit an approval review. The watcher will merge the PR directly after a clean review."
        , "8. Do not use dynamic client-only tools such as js_repl."
        , ""
        , "Write {{reviewerStatePath}} with this JSON shape, and also return exactly the same JSON object as the final answer:"
        , "{"
        , "  \"review_status\": \"clean\" | \"comments_added\" | \"incomplete\" | \"blocked\","
        , "  \"reviewed_commit_sha\": \"{{reviewTargetSha}}\","
        , "  \"reviewer_prompt_version\": \"{{reviewerPromptVersion}}\","
        , "  \"added_review_comment_count\": <number>,"
        , "  \"lgtm_comment\": \"LGTM\" | null,"
        , "  \"findings_summary\": [\"...\"],"
        , "  \"blocked_reason\": \"<string or null>\""
        , "}"
        , ""
        , "For review_status=clean, lgtm_comment must be LGTM and added_review_comment_count must be 0."
        , "For review_status=comments_added, added_review_comment_count must be at least 1."
        , "For review_status=incomplete or blocked, blocked_reason must explain why the watcher should not merge yet."
        ]
    )
