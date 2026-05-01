{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.TurnOutput
  ( issueImplementerThreadDeveloperInstructions
  , issueImplementationTurnOutputSchema
  , issueImplementationTurnInput
  , issueFinalReviewTurnInput
  , issueFinalReviewTurnOutputSchema
  , issuePlanTurnOutputSchema
  , issuePlanModeDeveloperInstructions
  , issuePlanTurnInput
  , issuePlanningThreadDeveloperInstructions
  , plannerTurnOutputSchema
  , prReviewWorkerTurnInput
  , prReviewWorkerTurnOutputSchema
  , prReviewThreadDeveloperInstructions
  , plannerTurnInputForScope
  , prReviewWorkerTurnInputWithEvidence
  , reviewerPromptVersion
  , reviewerTurnInput
  , reviewerTurnOutputSchema
  , reviewerVerificationTurnInput
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  ) where

import CodexWatcher.PromptTemplates
  ( issueImplementationTemplate
  , issueImplementThreadDeveloperTemplate
  , issuePlanModeDeveloperTemplate
  , issuePlanTemplate
  , issuePlanningThreadDeveloperTemplate
  , plannerTemplate
  , prReviewReviewerThreadDeveloperTemplate
  , prReviewWorkerThreadDeveloperTemplate
  , prReviewWorkerTemplate
  , publishProtocolTemplate
  , renderTemplate
  , reviewerPromptVersion
  , reviewerTemplate
  , validationProtocolTemplate
  )
import CodexWatcher.IssueText (issueNumbersText)
import CodexWatcher.Core.Ids
  ( BranchName (..)
  , CommitSha (..)
  , IssueNumber (..)
  , PrNumber (..)
  , RepoName (..)
  , ReviewThreadId (..)
  )
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.PrReview.Types (PrConfig (..), ReviewEvidence (..), reviewEvidenceSummaries, reviewEvidenceThreadComments, reviewEvidenceThreadIds)
import CodexWatcher.Runtime.Defaults (defaultEffort, defaultModel)
import Data.Aeson (Value, object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath ((</>))

structuredTurnOutputSchema :: Value
structuredTurnOutputSchema =
  issueImplementationTurnOutputSchema

plannerTurnOutputSchema :: Value
plannerTurnOutputSchema =
  strictObjectSchema
    [ "outcome"
    , "reason"
    , "summary"
    , "issues_to_create"
    , "subissues_to_create"
    , "ready_issues"
    , "blocked_issues"
    , "dependencies"
    ]
    [ ( "outcome"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= (["complete", "incomplete", "blocked"] :: [Text])
          ]
      )
    , ("reason", stringField)
    , ("summary", stringField)
    , ("issues_to_create", issueArrayField nullableIssueNumberField)
    , ("subissues_to_create", issueArrayField issueNumberField)
    , ("ready_issues", issueNumberArrayField)
    , ("blocked_issues", blockedIssueArrayField)
    , ("dependencies", dependencyArrayField)
    ]

issuePlanTurnOutputSchema :: Value
issuePlanTurnOutputSchema =
  strictObjectSchema
    ["outcome", "reason", "summary", "plan_markdown"]
    [ ( "outcome"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= (["complete", "blocked"] :: [Text])
          ]
      )
    , ("reason", stringField)
    , ("summary", stringField)
    , ("plan_markdown", stringField)
    ]

issueImplementationTurnOutputSchema :: Value
issueImplementationTurnOutputSchema =
  turnOutcomeSchema ["complete", "incomplete", "blocked"] [("evidence", stringField)]

prReviewWorkerTurnOutputSchema :: Value
prReviewWorkerTurnOutputSchema =
  turnOutcomeSchema ["complete", "incomplete", "blocked"] [("comment", stringField), ("evidence", stringField)]

reviewerTurnOutputSchema :: Value
reviewerTurnOutputSchema =
  strictObjectSchema
    [ "review_status"
    , "reviewed_commit_sha"
    , "reviewer_prompt_version"
    , "added_review_comment_count"
    , "lgtm_comment"
    , "findings_summary"
    , "blocked_reason"
    , "solved_threads"
    , "remaining_review_threads"
    ]
    [ ( "review_status"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= (["clean", "new_findings", "remaining_findings", "incomplete", "blocked"] :: [Text])
          ]
      )
    , ("reviewed_commit_sha", stringField)
    , ("reviewer_prompt_version", stringField)
    , ("added_review_comment_count", object ["type" .= ("integer" :: Text), "minimum" .= (0 :: Int)])
    , ("lgtm_comment", nullableStringField)
    , ("findings_summary", object ["type" .= ("array" :: Text), "items" .= stringField])
    , ("blocked_reason", nullableStringField)
    , ("solved_threads", solvedReviewThreadsField)
    , ("remaining_review_threads", remainingReviewThreadsField)
    ]

issueFinalReviewTurnOutputSchema :: Value
issueFinalReviewTurnOutputSchema =
  strictObjectSchema
    [ "completion_status"
    , "reviewed_commit_sha"
    , "reviewer_prompt_version"
    , "issue_solved"
    , "plan_implemented"
    , "tests_sufficient"
    , "rework_required"
    , "verification_summary"
    , "findings_summary"
    , "blocked_reason"
    , "lgtm_comment"
    ]
    [ ( "completion_status"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= (["clean", "rework_required", "incomplete", "blocked"] :: [Text])
          ]
      )
    , ("reviewed_commit_sha", stringField)
    , ("reviewer_prompt_version", stringField)
    , ("issue_solved", booleanField)
    , ("plan_implemented", booleanField)
    , ("tests_sufficient", booleanField)
    , ("rework_required", booleanField)
    , ("verification_summary", stringArrayField)
    , ("findings_summary", stringArrayField)
    , ("blocked_reason", nullableStringField)
    , ("lgtm_comment", nullableStringField)
    ]

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Every schema includes outcome, reason, and summary; include every schema field, using empty strings or arrays when a field is not applicable."
    , "Use outcome=blocked with a non-empty reason when you cannot proceed safely."
    , "Use outcome=incomplete with a non-empty reason when follow-up is required."
    , "Use outcome=complete with a non-empty summary when the turn is done; reason may be an empty string."
    ]

issuePlanStructuredTurnOutcomeInstructions :: Text
issuePlanStructuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Include every schema field, using an empty string when a string field is not applicable."
    , "Use outcome=blocked with a non-empty reason when planning cannot proceed safely."
    , "Use outcome=complete with a non-empty summary, empty reason, and non-empty plan_markdown when the plan is ready."
    , "Do not use outcome=incomplete; this planning schema only accepts complete or blocked."
    ]

plannerStructuredTurnOutcomeInstructions :: Text
plannerStructuredTurnOutcomeInstructions =
  Text.unlines
    [ "Return only JSON matching the active output schema. Plain prose completion is not accepted."
    , "Include every schema field, using empty arrays, empty strings, or null parentIssueNumber when a field is not applicable."
    , "Use outcome=blocked with a reason when you cannot proceed safely."
    , "Use outcome=incomplete with a reason when follow-up investigation or issue creation re-entry is required."
    , "Use outcome=complete with a summary when the issue graph is stable enough for the watcher to continue."
    , "issues_to_create and subissues_to_create are watcher-applied requests; do not create issues directly."
    , "dependencies is the authoritative planning graph input. The watcher recomputes canonical ready_issues and blocked_issues from dependencies and current GitHub issue facts."
    , "ready_issues and blocked_issues must still be present for schema compatibility, but treat them as non-authoritative hints."
    ]

turnOutcomeSchema :: [Text] -> [(Text, Value)] -> Value
turnOutcomeSchema outcomes extraProperties =
  let properties =
        [ ( "outcome"
          , object
              [ "type" .= ("string" :: Text)
              , "enum" .= outcomes
              ]
          )
        , ("reason", stringField)
        , ("summary", stringField)
        ]
          <> extraProperties
   in strictObjectSchema (fmap fst properties) properties

plannerTurnInputForScope :: [IssueNumber] -> Text
plannerTurnInputForScope scopeIssues =
  renderTemplate
    plannerTemplate
    [ ("structuredInstructions", plannerStructuredTurnOutcomeInstructions)
    , ("scopeInstructions", plannerTurnScopeInstructions scopeIssues)
    ]

issuePlanTurnInput :: Text
issuePlanTurnInput =
  renderTemplate issuePlanTemplate [("structuredInstructions", issuePlanStructuredTurnOutcomeInstructions)]

issueImplementationTurnInput :: Text
issueImplementationTurnInput =
  renderTemplate issueImplementationTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewWorkerTurnInput :: Text
prReviewWorkerTurnInput =
  renderTemplate prReviewWorkerTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewWorkerTurnInputWithEvidence :: Text -> ReviewEvidence -> Text
prReviewWorkerTurnInputWithEvidence baseInput evidence =
  Text.unlines
    [ baseInput
    , ""
    , "Watcher-provided review feedback to address in this turn:"
    , reviewFeedbackBullets evidence
    , "Read the full GitHub thread/review context if needed, then fix these items, validate, commit, and push."
    ]

prReviewThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text -> Text
prReviewThreadDeveloperInstructions workdir stateDir config role
  | role == "reviewer" =
      renderPrReviewReviewerThreadDeveloperInstructions workdir config
  | otherwise =
      renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config

renderPrReviewWorkerThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text
renderPrReviewWorkerThreadDeveloperInstructions workdir _stateDir config =
  renderTemplate
    prReviewWorkerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("validationProtocol", validationProtocol)
    , ("publishProtocol", publishProtocol config.prBranch)
    ]

renderPrReviewReviewerThreadDeveloperInstructions :: FilePath -> PrConfig -> Text
renderPrReviewReviewerThreadDeveloperInstructions workdir config =
  renderTemplate
    prReviewReviewerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("reviewerModel", defaultModel)
    , ("reviewerEffort", defaultEffort)
    ]

issueImplementerThreadDeveloperInstructions :: FilePath -> FilePath -> IssueConfig -> Text
issueImplementerThreadDeveloperInstructions workdir stateDir config =
  renderTemplate
    issueImplementThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.issueRepo)
    , ("issueNumber", Text.pack (show (unIssueNumber config.issueNumber)))
    , ("issueUrl", issueUrl config.issueRepo config.issueNumber)
    , ("workdir", Text.pack workdir)
    , ("baseBranch", "origin/HEAD")
    , ("branch", unBranchName config.issueBranch)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.issueBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("issueStatePath", Text.pack (stateDir </> "issue-state.json"))
    , ("issuePlanPath", Text.pack (stateDir </> "issue-plan.md"))
    , ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    ]

issuePlanningThreadDeveloperInstructions :: FilePath -> RepoName -> [IssueNumber] -> Text
issuePlanningThreadDeveloperInstructions stateDir repo scopeIssues =
  renderTemplate
    issuePlanningThreadDeveloperTemplate
    [ ("repoFullName", unRepoName repo)
    , ("plannerModel", defaultModel)
    , ("plannerEffort", defaultEffort)
    , ("issueSnapshotPath", Text.pack (stateDir </> "issue-snapshot.json"))
    , ("scopeInstructions", issuePlanningScopeInstructions scopeIssues)
    ]

issuePlanModeDeveloperInstructions :: FilePath -> FilePath -> IssueConfig -> PrNumber -> Text
issuePlanModeDeveloperInstructions workdir stateDir config prNumber =
  renderTemplate
    issuePlanModeDeveloperTemplate
    [ ("repoFullName", unRepoName config.issueRepo)
    , ("issueNumber", Text.pack (show (unIssueNumber config.issueNumber)))
    , ("issueUrl", issueUrl config.issueRepo config.issueNumber)
    , ("prNumber", Text.pack (show (unPrNumber prNumber)))
    , ("prUrl", prUrl config.issueRepo prNumber)
    , ("workdir", Text.pack workdir)
    , ("baseBranch", "origin/HEAD")
    , ("branch", unBranchName config.issueBranch)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.issueBranch)
    , ("workerModel", defaultModel)
    , ("planEffort", defaultEffort)
    , ("issueStatePath", Text.pack (stateDir </> "issue-state.json"))
    , ("issuePlanPath", Text.pack (stateDir </> "issue-plan.md"))
    ]

reviewerTurnInput :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text
reviewerTurnInput workdir reviewerStatePath config reviewTargetSha =
  reviewerTurnInputWithVerification workdir reviewerStatePath config reviewTargetSha noVerificationInstructions

issueFinalReviewTurnInput :: FilePath -> FilePath -> IssueConfig -> PrNumber -> CommitSha -> Text
issueFinalReviewTurnInput workdir reviewerStatePath config prNumber reviewTargetSha =
  Text.unlines
    [ "Final-review the merged implementation for issue #" <> Text.pack (show (unIssueNumber config.issueNumber)) <> " and PR #" <> Text.pack (show (unPrNumber prNumber)) <> "."
    , ""
    , "Repository: " <> unRepoName config.issueRepo
    , "Issue: " <> issueUrl config.issueRepo config.issueNumber
    , "PR: " <> prUrl config.issueRepo prNumber
    , "Workdir: " <> Text.pack workdir
    , "Branch used for the implementation: " <> unBranchName config.issueBranch
    , "Review target commit: " <> unCommitSha reviewTargetSha
    , "Reviewer prompt version: " <> reviewerPromptVersion
    , "Reviewer state path: " <> Text.pack reviewerStatePath
    , ""
    , "Task:"
    , "- Inspect the issue body/comments, PR body, PR plan, merged implementation, tests, and relevant local code."
    , "- Decide whether the implementation truly solved the issue and whether the PR plan was actually implemented."
    , "- Do not treat an empty PR diff against the base branch as clean by itself; post-merge review must validate behavior against the issue and PR plan."
    , "- If the issue is not solved, the plan is not implemented, tests are insufficient, or follow-up work is needed, use completion_status=rework_required."
    , "- Put only actionable rework items in findings_summary. Do not put successful validation evidence there."
    , "- Put successful validation evidence, inspected files, and test results in verification_summary."
    , "- If everything is solved and no follow-up is needed, use completion_status=clean."
    , "- If you cannot complete the check, use completion_status=incomplete or blocked with a concrete blocked_reason."
    , ""
    , "Restrictions:"
    , "- Do not edit files, commit, push, approve, close the issue, create PRs, or resolve GitHub review threads."
    , "- Return only a value matching the provided output schema."
    ]

reviewerVerificationTurnInput :: FilePath -> FilePath -> PrConfig -> ReviewEvidence -> CommitSha -> Text
reviewerVerificationTurnInput workdir reviewerStatePath config evidence reviewTargetSha =
  reviewerTurnInputWithVerification
    workdir
    reviewerStatePath
    config
    reviewTargetSha
    (verificationInstructions evidence)

reviewerTurnInputWithVerification :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text -> Text
reviewerTurnInputWithVerification workdir _reviewerStatePath config reviewTargetSha verificationInstructionsText =
  renderTemplate
    reviewerTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("reviewTargetSha", unCommitSha reviewTargetSha)
    , ("reviewerPromptVersion", reviewerPromptVersion)
    , ("verificationInstructions", verificationInstructionsText)
    ]

noVerificationInstructions :: Text
noVerificationInstructions =
  Text.unlines
    [ "Review-thread resolution fields:"
    , "- This is a normal review pass with no watcher-owned prior thread verification."
    , "- Return empty arrays for solved_threads and remaining_review_threads."
    , "- If you find any new actionable finding, use review_status=new_findings and put a concrete summary in findings_summary; the watcher will publish it to the PR as a non-approval findings comment and route it to the worker."
    ]

verificationInstructions :: ReviewEvidence -> Text
verificationInstructions evidence =
  Text.unlines
    [ "Review-feedback verification:"
    , "- The previous worker turn claimed to fix this review feedback from commit " <> unCommitSha evidence.reviewedCommit <> ":"
    , reviewFeedbackBullets evidence
    , "- Re-read those GitHub review threads and watcher review-findings comments as applicable, then inspect the current local PR code."
    , "- Put fixed prior review threads in solved_threads as structured objects with thread_id and resolution_summary; the watcher will resolve only those solved threads."
    , "- Put prior review threads that still apply in remaining_review_threads as structured objects with thread_id and comment; the watcher will add those comments as replies under the remaining GitHub review threads."
    , "- If any prior thread still applies and you do not add a new non-duplicate inline comment, use review_status=remaining_findings and leave top-level findings_summary empty."
    , "- If prior summary-only watcher feedback still applies, or if prior threads are fixed but you find new actionable problems, use review_status=new_findings and put concrete summaries in findings_summary."
    , "- If all prior feedback is fixed and there are no new actionable findings, use review_status=clean."
    , "- Do not resolve GitHub review threads yourself; the watcher resolves only the threads you list in solved_threads."
    ]

reviewFeedbackBullets :: ReviewEvidence -> Text
reviewFeedbackBullets evidence =
  Text.unlines (threadCommentBullets <> threadBullets <> summaryBullets)
 where
  threadCommentPairs =
    reviewEvidenceThreadComments evidence
  threadCommentIds =
    fmap fst threadCommentPairs
  threadCommentBullets =
    [ "- review thread " <> unReviewThreadId threadId <> ": " <> Text.strip comment
    | (threadId, comment) <- threadCommentPairs
    ]
  threadBullets =
    [ "- review thread " <> unReviewThreadId threadId
    | threadId <- reviewEvidenceThreadIds evidence
    , threadId `notElem` threadCommentIds
    ]
  summaryBullets =
    ["- " <> summary | summary <- reviewEvidenceSummaries evidence]

validationProtocol :: Text
validationProtocol =
  renderTemplate
    validationProtocolTemplate
    []

publishProtocol :: BranchName -> Text
publishProtocol branch =
  renderTemplate
    publishProtocolTemplate
    [ ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    , ("prHeadBranch", unBranchName branch)
    ]

prUrl :: RepoName -> PrNumber -> Text
prUrl repo number =
  "https://github.com/" <> unRepoName repo <> "/pull/" <> Text.pack (show (unPrNumber number))

issueUrl :: RepoName -> IssueNumber -> Text
issueUrl repo number =
  "https://github.com/" <> unRepoName repo <> "/issues/" <> Text.pack (show (unIssueNumber number))

branchOrUnknownUseTools :: BranchName -> Text
branchOrUnknownUseTools branch =
  let value = Text.strip (unBranchName branch)
   in if Text.null value then "unknown; inspect repository remotes" else value

issuePlanningScopeInstructions :: [IssueNumber] -> Text
issuePlanningScopeInstructions [] =
  ""
issuePlanningScopeInstructions scopeIssues =
  Text.unlines
    [ ""
    , "Target scope:"
    , "- Only these root issues and their existing or newly created GitHub sub-issues are in scope: " <> issueNumbersText scopeIssues <> "."
    , "- Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees."
    , "- If a scoped root issue needs decomposition, propose concrete GitHub sub-issues under that root, then let the watcher re-enter planning."
    ]

plannerTurnScopeInstructions :: [IssueNumber] -> Text
plannerTurnScopeInstructions [] =
  ""
plannerTurnScopeInstructions scopeIssues =
  Text.unlines
    [ ""
    , "Target scope:"
    , "- Only these root issues and their existing or newly created GitHub sub-issues are in scope: " <> issueNumbersText scopeIssues <> "."
    , "- Do not create, classify, mark ready, mark blocked, or start work for issues outside these issue trees."
    , "- If a scoped root issue needs decomposition, propose concrete GitHub sub-issues under that root, then let the watcher re-enter planning."
    , "- When returning dependencies, include only scoped root issues and descendants that belong to these issue trees."
    ]

stringField :: Value
stringField =
  object ["type" .= ("string" :: Text)]

booleanField :: Value
booleanField =
  object ["type" .= ("boolean" :: Text)]

nullableStringField :: Value
nullableStringField =
  object ["type" .= (["string", "null"] :: [Text])]

stringArrayField :: Value
stringArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items" .= stringField
    ]

solvedReviewThreadsField :: Value
solvedReviewThreadsField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= strictObjectSchema
          ["thread_id", "resolution_summary"]
          [ ("thread_id", stringField)
          , ("resolution_summary", stringField)
          ]
    ]

remainingReviewThreadsField :: Value
remainingReviewThreadsField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= strictObjectSchema
          ["thread_id", "comment"]
          [ ("thread_id", stringField)
          , ("comment", stringField)
          ]
    ]

strictObjectSchema :: [Text] -> [(Text, Value)] -> Value
strictObjectSchema requiredFields properties =
  object
    [ "type" .= ("object" :: Text)
    , "additionalProperties" .= False
    , "required" .= requiredFields
    , "properties" .= object [Key.fromText key .= value | (key, value) <- properties]
    ]

issueNumberField :: Value
issueNumberField =
  object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]

nullableIssueNumberField :: Value
nullableIssueNumberField =
  object ["type" .= (["integer", "null"] :: [Text]), "minimum" .= (1 :: Int)]

issueArrayField :: Value -> Value
issueArrayField parentIssueNumberField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= strictObjectSchema
          ["title", "body", "parentIssueNumber"]
          [ ("title", stringField)
          , ("body", stringField)
          , ("parentIssueNumber", parentIssueNumberField)
          ]
    ]

issueNumberArrayField :: Value
issueNumberArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items" .= issueNumberField
    ]

blockedIssueArrayField :: Value
blockedIssueArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= strictObjectSchema
          ["issueNumber", "blockedBy", "reason"]
          [ ("issueNumber", issueNumberField)
          , ("blockedBy", issueNumberArrayField)
          , ("reason", stringField)
          ]
    ]

dependencyArrayField :: Value
dependencyArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= strictObjectSchema
          ["issueNumber", "dependsOn"]
          [ ("issueNumber", issueNumberField)
          , ("dependsOn", issueNumberArrayField)
          ]
    ]
