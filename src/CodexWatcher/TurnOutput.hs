{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.TurnOutput
  ( issueImplementerThreadDeveloperInstructions
  , issueImplementationTurnOutputSchema
  , issueImplementationTurnInput
  , issuePlanTurnOutputSchema
  , issuePlanModeDeveloperInstructions
  , issuePlanTurnInput
  , issuePlanningThreadDeveloperInstructions
  , plannerTurnOutputSchema
  , prReviewWorkerTurnInput
  , prReviewWorkerTurnOutputSchema
  , prReviewThreadDeveloperInstructions
  , plannerTurnInput
  , reviewerPromptVersion
  , reviewerTurnInput
  , reviewerTurnOutputSchema
  , reviewerVerificationTurnInput
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  ) where

import CodexWatcher.PromptTemplates
  ( completionContractTemplate
  , issueImplementationTemplate
  , issueImplementThreadDeveloperTemplate
  , issuePlanModeDeveloperTemplate
  , issuePlanTemplate
  , issuePlanningThreadDeveloperTemplate
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
import CodexWatcher.Domain.PrReview.Types (PrConfig (..), ReviewEvidence (..))
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
    , "resolved_review_thread_ids"
    , "remaining_review_thread_ids"
    ]
    [ ( "review_status"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= (["clean", "comments_added", "remaining_findings", "incomplete", "blocked"] :: [Text])
          ]
      )
    , ("reviewed_commit_sha", stringField)
    , ("reviewer_prompt_version", stringField)
    , ("added_review_comment_count", object ["type" .= ("integer" :: Text), "minimum" .= (0 :: Int)])
    , ("lgtm_comment", nullableStringField)
    , ("findings_summary", object ["type" .= ("array" :: Text), "items" .= stringField])
    , ("blocked_reason", nullableStringField)
    , ("resolved_review_thread_ids", stringArrayField)
    , ("remaining_review_thread_ids", stringArrayField)
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

plannerTurnInput :: Text
plannerTurnInput =
  Text.unlines
    [ "Read the current issue snapshot and return the issue-planning decision JSON for the current scope."
    , "Inspect existing GitHub issues and sub-issues when needed before deciding."
    ]

issuePlanTurnInput :: Text
issuePlanTurnInput =
  renderTemplate issuePlanTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

issueImplementationTurnInput :: Text
issueImplementationTurnInput =
  renderTemplate issueImplementationTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewWorkerTurnInput :: Text
prReviewWorkerTurnInput =
  renderTemplate prReviewWorkerTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text -> Text
prReviewThreadDeveloperInstructions workdir stateDir config role
  | role == "reviewer" =
      renderPrReviewReviewerThreadDeveloperInstructions workdir config
  | otherwise =
      renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config

renderPrReviewWorkerThreadDeveloperInstructions :: FilePath -> FilePath -> PrConfig -> Text
renderPrReviewWorkerThreadDeveloperInstructions workdir stateDir config =
  renderTemplate
    prReviewWorkerThreadDeveloperTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("prUrl", prUrl config.prRepo config.prNumber)
    , ("workdir", Text.pack workdir)
    , ("branchOrUnknownUseTools", branchOrUnknownUseTools config.prBranch)
    , ("workerModel", defaultModel)
    , ("workerEffort", defaultEffort)
    , ("validationProtocol", validationProtocol (stateDir </> "agent-state.json"))
    , ("publishProtocol", publishProtocol (stateDir </> "agent-state.json") config.prBranch)
    , ("completionContract", completionContract (stateDir </> "agent-state.json"))
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

reviewerVerificationTurnInput :: FilePath -> FilePath -> PrConfig -> ReviewEvidence -> CommitSha -> Text
reviewerVerificationTurnInput workdir reviewerStatePath config evidence reviewTargetSha =
  reviewerTurnInputWithVerification
    workdir
    reviewerStatePath
    config
    reviewTargetSha
    (verificationInstructions evidence)

reviewerTurnInputWithVerification :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text -> Text
reviewerTurnInputWithVerification workdir reviewerStatePath config reviewTargetSha verificationInstructionsText =
  renderTemplate
    reviewerTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("reviewTargetSha", unCommitSha reviewTargetSha)
    , ("reviewerPromptVersion", reviewerPromptVersion)
    , ("reviewerStatePath", Text.pack reviewerStatePath)
    , ("verificationInstructions", verificationInstructionsText)
    ]

noVerificationInstructions :: Text
noVerificationInstructions =
  Text.unlines
    [ "Review-thread resolution fields:"
    , "- This is a normal review pass with no watcher-owned prior thread verification."
    , "- Return empty arrays for resolved_review_thread_ids and remaining_review_thread_ids."
    ]

verificationInstructions :: ReviewEvidence -> Text
verificationInstructions evidence =
  Text.unlines
    [ "Review-thread verification:"
    , "- The previous worker turn claimed to fix these unresolved GitHub review threads from commit " <> unCommitSha evidence.reviewedCommit <> ":"
    , reviewThreadBullets evidence.unresolvedThreads
    , "- Re-read those GitHub review threads and inspect the current local PR code."
    , "- Put fixed prior thread IDs in resolved_review_thread_ids."
    , "- Put prior thread IDs that still apply in remaining_review_thread_ids."
    , "- If any prior thread still applies and you do not add a new non-duplicate inline comment, use review_status=remaining_findings."
    , "- If prior threads are fixed but you add new review comments, use review_status=comments_added."
    , "- If all prior threads are fixed and there are no new actionable findings, use review_status=clean."
    , "- Do not resolve GitHub review threads yourself; the watcher resolves only the IDs you list as resolved."
    ]

reviewThreadBullets :: Foldable f => f ReviewThreadId -> Text
reviewThreadBullets =
  Text.unlines . fmap (("- " <>) . unReviewThreadId) . foldMap (: [])

validationProtocol :: FilePath -> Text
validationProtocol agentStatePath =
  renderTemplate
    validationProtocolTemplate
    [("agentStatePath", Text.pack agentStatePath)]

publishProtocol :: FilePath -> BranchName -> Text
publishProtocol agentStatePath branch =
  renderTemplate
    publishProtocolTemplate
    [ ("agentStatePath", Text.pack agentStatePath)
    , ("gitUserName", "codex-watcher")
    , ("gitUserEmail", "codex-watcher@users.noreply.github.com")
    , ("prHeadBranch", unBranchName branch)
    ]

completionContract :: FilePath -> Text
completionContract agentStatePath =
  renderTemplate
    completionContractTemplate
    [("agentStatePath", Text.pack agentStatePath)]

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

stringField :: Value
stringField =
  object ["type" .= ("string" :: Text)]

nullableStringField :: Value
nullableStringField =
  object ["type" .= (["string", "null"] :: [Text])]

stringArrayField :: Value
stringArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items" .= stringField
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
