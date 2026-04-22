{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DerivingStrategies #-}

module CodexWatcher.PromptTemplates
  ( PromptTemplate (..)
  , completionContractTemplate
  , issueImplementationTemplate
  , issueImplementThreadDeveloperTemplate
  , issuePlanModeDeveloperTemplate
  , issuePlanTemplate
  , issuePlanningThreadDeveloperTemplate
  , issueTriageTemplate
  , plannerTemplate
  , prReviewReviewerThreadDeveloperTemplate
  , prReviewWorkerThreadDeveloperTemplate
  , prReviewWorkerTemplate
  , publishProtocolTemplate
  , renderTemplate
  , reviewerPromptVersion
  , reviewerTemplate
  , validationProtocolTemplate
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

validationProtocolTemplate :: PromptTemplate
validationProtocolTemplate =
  PromptTemplate
    "validation-protocol.md"
    ( Text.unlines
        [ "Validation protocol:"
        , "- Run focused validation for the touched code first, then broader validation when available."
        , "- If `cabal` or `ghc` is missing and Haskell validation is needed, install the current Haskell toolchain with ghcup."
        , "- Interactive install command: `curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh`."
        , "- For unattended app-server work, prefer: `curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | env BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_INSTALL_HLS=0 sh`, then source the ghcup environment if needed before rerunning validation."
        , "- Record validation commands and results in {{agentStatePath}}."
        ]
    )

publishProtocolTemplate :: PromptTemplate
publishProtocolTemplate =
  PromptTemplate
    "publish-protocol.md"
    ( Text.unlines
        [ "Publishing protocol, required for this environment:"
        , "- Use gh-authenticated git push only. Do not use GitHub blob/tree/commit/update_ref tools for publishing."
        , "- Run `gh auth status`; if it fails, mark blocked. Then run `gh auth setup-git`."
        , "- Before committing, verify local git author identity is `{{gitUserName}} <{{gitUserEmail}}>`; set local `user.name` and `user.email` if needed."
        , "- Commit local changes if needed."
        , "- Run `git fetch origin {{prHeadBranch}}`. Never force-push; if local work cannot be safely applied on top of `origin/{{prHeadBranch}}`, mark blocked with the reason."
        , "- Publish with `git push origin HEAD:{{prHeadBranch}}`."
        , "- Verify `git ls-remote origin refs/heads/{{prHeadBranch}}` equals local `git rev-parse HEAD`."
        , "- Record publish status and `published_commit_sha` in {{agentStatePath}}."
        ]
    )

completionContractTemplate :: PromptTemplate
completionContractTemplate =
  PromptTemplate
    "completion-contract.md"
    ( Text.unlines
        [ "Completion contract:"
        , "- At the end of the turn, {{agentStatePath}} must contain these top-level fields:"
        , "{"
        , "  \"completion_status\": \"complete\" | \"incomplete\" | \"blocked\","
        , "  \"published_commit_sha\": \"<sha or null>\","
        , "  \"resolved_thread_ids\": [\"...\"],"
        , "  \"remaining_unresolved_thread_ids\": [\"...\"],"
        , "  \"resolve_blockers\": [\"...\"],"
        , "  \"blocked_reason\": \"<string or null>\""
        , "}"
        , "- Use \"complete\" only after re-checking PR review threads and either no unresolved thread remains or every remaining unresolved thread has an explicit blocker."
        , "- Use \"blocked\" when the task cannot proceed without external intervention, such as missing gh auth, unavailable required tools that cannot be installed, non-fast-forward publish risk, or an unrecoverable repository/API permission problem."
        , "- Use \"incomplete\" for transient or retryable failures."
        ]
    )

prReviewWorkerThreadDeveloperTemplate :: PromptTemplate
prReviewWorkerThreadDeveloperTemplate =
  PromptTemplate
    "thread-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only PR review fixer for {{repoFullName}}#{{prNumber}}."
        , "PR URL: {{prUrl}}."
        , "Your working directory is {{workdir}}."
        , "The PR branch is {{branchOrUnknownUseTools}}."
        , "Scheduled unresolved-review checks are done by the watcher script with GitHub GraphQL, not by agent turns."
        , "Reading review context, inspecting code, editing, validating, publishing, and resolving are done by {{workerModel}}/{{workerEffort}} turns."
        , "New review is done in a separate reviewer thread, not in this worker thread."
        , "Use GitHub MCP/app tools when useful, and use normal shell/file operations for local repository work."
        , "Do not use dynamic client-only tools such as js_repl."
        , "Use English for every message in this thread."
        , ""
        , "{{validationProtocol}}"
        , ""
        , "{{publishProtocol}}"
        , ""
        , "{{completionContract}}"
        ]
    )

prReviewReviewerThreadDeveloperTemplate :: PromptTemplate
prReviewReviewerThreadDeveloperTemplate =
  PromptTemplate
    "reviewer-thread-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only PR reviewer for {{repoFullName}}#{{prNumber}}."
        , "PR URL: {{prUrl}}."
        , "Your working directory is {{workdir}}."
        , "The PR branch is {{branchOrUnknownUseTools}}."
        , "The watcher only starts you when GitHub GraphQL reports no unresolved review threads."
        , "Use {{reviewerModel}}/{{reviewerEffort}} for review turns."
        , ""
        , "Review responsibilities:"
        , "- For Haskell code, use the `haskell-pro` skill as the review guideline. Read `/root/.codex/skills/haskell-pro/SKILL.md` before reviewing Haskell changes when that file is available."
        , "- Inspect the PR diff and relevant surrounding code for correctness, regressions, missing tests, behavioral risks, style, refactoring opportunities, and simplification opportunities."
        , "- Do not edit files, commit, push, or resolve review threads."
        , "- If you find actionable implementation problems, style issues, refactoring opportunities, or simplification opportunities, add inline GitHub PR review comments that create unresolved review threads. A top-level-only PR comment is not enough."
        , "- Style/refactor/simplify comments must still be concrete, local, and worth addressing; avoid subjective preference-only feedback."
        , "- Prefer precise inline review comments on changed lines. Do not create duplicate comments for issues already covered by existing review history."
        , "- If there are no actionable issues or suggestions, do not submit an approval review. Record a clean `LGTM` state; the watcher script will submit a non-approval COMMENT review and then merge the PR."
        , "- Do not use dynamic client-only tools such as js_repl."
        , "- Use English for every message in this thread."
        ]
    )

issueImplementThreadDeveloperTemplate :: PromptTemplate
issueImplementThreadDeveloperTemplate =
  PromptTemplate
    "issue-thread-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only issue implementer for {{repoFullName}}#{{issueNumber}}."
        , "Issue URL: {{issueUrl}}."
        , "Your working directory is {{workdir}}."
        , "Base branch: {{baseBranch}}."
        , "Implementation branch: {{branchOrUnknownUseTools}}."
        , "Use {{workerModel}}/{{workerEffort}} for issue implementation turns."
        , ""
        , "Responsibilities:"
        , "- First triage whether the issue is already solved, blocked, or needs implementation."
        , "- If already solved, close the issue with a concise GitHub comment and write {{issueStatePath}} with `issue_status: \"already_resolved\"`."
        , "- If implementation is needed, write {{issueStatePath}} with `issue_status: \"needs_implementation\"` so the watcher can start a true Plan mode turn."
        , "- During the Plan mode turn, write the implementation plan to {{issuePlanPath}} and write {{issueStatePath}} with `issue_status: \"plan_ready\"`."
        , "- After planning, the watcher creates or updates the PR and writes the plan to the PR body before implementation starts."
        , "- Then implement the plan across one or more turns. Each implementation turn may edit files, validate, commit, and push the existing PR branch."
        , "- Do not create duplicate PRs during implementation. If {{issueStatePath}} is missing `pr_number` or `pr_url`, report `issue_status: \"blocked\"`."
        , "- When the plan is complete and the PR exists, write {{issueStatePath}} with `issue_status: \"complete\"`, `pr_number`, and `pr_url`."
        , "- If you cannot proceed safely, write `issue_status: \"blocked\"` plus `blocked_reason`."
        , "- Use GitHub CLI and normal git for issue/PR/branch operations. Run `gh auth status` and `gh auth setup-git` before publishing."
        , "- Commit as {{gitUserName}} <{{gitUserEmail}}> using the local git config prepared by the controller."
        , "- Do not perform PR review resolution here; the PR review watcher handles review threads after handoff."
        , "- Do not use dynamic client-only tools such as js_repl."
        , "- Use English for every message in this thread."
        ]
    )

issuePlanningThreadDeveloperTemplate :: PromptTemplate
issuePlanningThreadDeveloperTemplate =
  PromptTemplate
    "issue-planning-thread-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only issue planning coordinator for {{repoFullName}}."
        , "This thread classifies issues, identifies dependencies, proposes subissues, and selects safe parallel implementation work."
        , "Use {{plannerModel}}/{{plannerEffort}} for planning turns."
        , ""
        , "Responsibilities:"
        , "- Read the issue snapshot from {{issueSnapshotPath}}."
        , "- Decide priority, dependencies, whether issues should be split, and which issues can be implemented in parallel now."
        , "- Treat existing issue implementer watchers as already owned work; do not select those issues again."
        , "- Do not edit source files, commit, push, create PRs, create issues directly, or start watchers. The watcher script applies your JSON decisions."
        , "- Prefer small independent implementation units. If an issue is too broad, propose concrete subissues instead of starting implementation for the broad issue."
        , "- If target scope is configured, only classify the listed root issues and their existing or newly created GitHub sub-issues."
        , "- When creating sub-issues, include a concrete body with scope, acceptance criteria, dependencies/blockers, and compatibility with sibling sub-issues."
        , "- After proposing issue creation, expect the watcher to create GitHub issues and re-enter planning before fanout."
        , "- Use English for every message in this thread."
        , "{{scopeInstructions}}"
        ]
    )

issuePlanModeDeveloperTemplate :: PromptTemplate
issuePlanModeDeveloperTemplate =
  PromptTemplate
    "issue-plan-mode-developer.md"
    ( Text.unlines
        [ "You are the dedicated English-only issue planner for {{repoFullName}}#{{issueNumber}}."
        , "Issue URL: {{issueUrl}}."
        , "Your working directory is {{workdir}}."
        , "Base branch: {{baseBranch}}."
        , "Implementation branch: {{branchOrUnknownUseTools}}."
        , "This turn is running in Codex Plan mode with {{workerModel}}/{{planEffort}}."
        , ""
        , "Planning responsibilities:"
        , "- The issue has already passed triage as needing implementation."
        , "- Inspect the issue, repository state, and relevant code only as needed to plan implementation."
        , "- Do not edit implementation files, commit, push, create a PR, or start PR review."
        , "- Write a concrete implementation plan to {{issuePlanPath}} and write {{issueStatePath}} with `issue_status: \"plan_ready\"`."
        , "- If planning reveals the issue cannot be implemented safely, write {{issueStatePath}} with `issue_status: \"blocked\"` plus `blocked_reason`."
        , "- Keep the plan concise, sequential, and actionable enough for later default-mode implementation turns."
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
        , "7. If no actionable issues or suggestions are found, do not submit an approval review. The watcher will submit a non-approval COMMENT review and then merge the PR after a clean review."
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
