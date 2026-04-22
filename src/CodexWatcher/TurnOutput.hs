{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.TurnOutput
  ( issueImplementationTurnInput
  , issuePlanTurnInput
  , issueTriageTurnInput
  , prReviewWorkerTurnInput
  , prReviewThreadDeveloperInstructions
  , plannerTurnInput
  , reviewerPromptVersion
  , reviewerTurnInput
  , reviewerTurnOutputSchema
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  ) where

import CodexWatcher.PromptTemplates
  ( issueImplementationTemplate
  , issuePlanTemplate
  , issueTriageTemplate
  , plannerTemplate
  , prReviewWorkerTemplate
  , prReviewThreadDeveloperTemplate
  , renderTemplate
  , reviewerPromptVersion
  , reviewerTemplate
  )
import CodexWatcher.Types
import Data.Aeson (Value, object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text

structuredTurnOutputSchema :: Value
structuredTurnOutputSchema =
  object
    [ "type" .= ("object" :: Text)
    , "additionalProperties" .= False
    , "required" .= (["outcome"] :: [Text])
    , "properties"
        .= object
          [ "outcome"
              .= object
                [ "type" .= ("string" :: Text)
                , "enum"
                    .= ( [ "complete"
                         , "incomplete"
                         , "blocked"
                         , "already_fixed"
                         , "needs_implementation"
                         , "clean"
                         , "problems"
                         ] ::
                          [Text]
                       )
                ]
          , "reason" .= stringField
          , "summary" .= stringField
          , "comment" .= stringField
          , "evidence" .= stringField
          , "issues_to_create" .= issueArrayField ["title"]
          , "subissues_to_create" .= issueArrayField ["title", "body", "parentIssueNumber"]
          , "ready_issues" .= issueNumberArrayField
          , "blocked_issues" .= blockedIssueArrayField
          , "dependencies" .= dependencyArrayField
          ]
    ]

reviewerTurnOutputSchema :: Value
reviewerTurnOutputSchema =
  object
    [ "type" .= ("object" :: Text)
    , "additionalProperties" .= False
    , "required"
        .= ( [ "review_status"
             , "reviewed_commit_sha"
             , "reviewer_prompt_version"
             , "added_review_comment_count"
             , "lgtm_comment"
             , "findings_summary"
             , "blocked_reason"
             ] ::
              [Text]
           )
    , "properties"
        .= object
          [ "review_status"
              .= object
                [ "type" .= ("string" :: Text)
                , "enum" .= (["clean", "comments_added", "incomplete", "blocked"] :: [Text])
                ]
          , "reviewed_commit_sha" .= stringField
          , "reviewer_prompt_version" .= stringField
          , "added_review_comment_count" .= object ["type" .= ("integer" :: Text), "minimum" .= (0 :: Int)]
          , "lgtm_comment" .= nullableStringField
          , "findings_summary" .= object ["type" .= ("array" :: Text), "items" .= stringField]
          , "blocked_reason" .= nullableStringField
          ]
    ]

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  "Return only JSON with an outcome field. Use outcome=blocked with reason when you cannot proceed, outcome=incomplete with reason when follow-up is required, and outcome=complete with summary when the turn is done."

plannerTurnInput :: Text
plannerTurnInput =
  renderTemplate
    plannerTemplate
    [ ("structuredInstructions", structuredTurnOutcomeInstructions)
    , ("scopeInstructions", "")
    ]

issueTriageTurnInput :: Text
issueTriageTurnInput =
  renderTemplate issueTriageTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

issuePlanTurnInput :: Text
issuePlanTurnInput =
  renderTemplate issuePlanTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

issueImplementationTurnInput :: Text
issueImplementationTurnInput =
  renderTemplate issueImplementationTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewWorkerTurnInput :: Text
prReviewWorkerTurnInput =
  renderTemplate prReviewWorkerTemplate [("structuredInstructions", structuredTurnOutcomeInstructions)]

prReviewThreadDeveloperInstructions :: FilePath -> PrConfig -> Text -> Text
prReviewThreadDeveloperInstructions workdir config role =
  renderTemplate
    prReviewThreadDeveloperTemplate
    [ ("role", role)
    , ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("model", "gpt-5.4")
    , ("effort", "xhigh")
    ]

reviewerTurnInput :: FilePath -> FilePath -> PrConfig -> CommitSha -> Text
reviewerTurnInput workdir reviewerStatePath config reviewTargetSha =
  renderTemplate
    reviewerTemplate
    [ ("repoFullName", unRepoName config.prRepo)
    , ("prNumber", Text.pack (show (unPrNumber config.prNumber)))
    , ("workdir", Text.pack workdir)
    , ("branch", unBranchName config.prBranch)
    , ("reviewTargetSha", unCommitSha reviewTargetSha)
    , ("reviewerPromptVersion", reviewerPromptVersion)
    , ("reviewerStatePath", Text.pack reviewerStatePath)
    ]

stringField :: Value
stringField =
  object ["type" .= ("string" :: Text)]

nullableStringField :: Value
nullableStringField =
  object ["type" .= (["string", "null"] :: [Text])]

issueArrayField :: [Text] -> Value
issueArrayField requiredFields =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= requiredFields
          , "properties"
              .= object
                [ "title" .= stringField
                , "body" .= stringField
                , "parentIssueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                ]
          ]
    ]

issueNumberArrayField :: Value
issueNumberArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
    ]

blockedIssueArrayField :: Value
blockedIssueArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= (["issueNumber", "blockedBy"] :: [Text])
          , "properties"
              .= object
                [ "issueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                , "blockedBy" .= issueNumberArrayField
                , "reason" .= stringField
                ]
          ]
    ]

dependencyArrayField :: Value
dependencyArrayField =
  object
    [ "type" .= ("array" :: Text)
    , "items"
        .= object
          [ "type" .= ("object" :: Text)
          , "additionalProperties" .= False
          , "required" .= (["issueNumber", "dependsOn"] :: [Text])
          , "properties"
              .= object
                [ "issueNumber" .= object ["type" .= ("integer" :: Text), "minimum" .= (1 :: Int)]
                , "dependsOn" .= issueNumberArrayField
                ]
          ]
    ]
