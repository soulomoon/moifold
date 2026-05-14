{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.TurnOutput.Schema
  ( issueFinalReviewTurnOutputSchema
  , issueImplementationTurnOutputSchema
  , issuePlanTurnOutputSchema
  , plannerTurnOutputSchema
  , prReviewWorkerTurnOutputSchema
  , reviewerTurnOutputSchema
  , structuredTurnOutputSchema
  ) where

import CodexWatcher.Domain.PrReview.Types
  ( allNewFindingsStatuses
  , allPriorFindingsStatuses
  , newFindingsStatusText
  , priorFindingsStatusText
  )
import Data.Aeson (Value, object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Text (Text)

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
    [ "reviewed_commit_sha"
    , "reviewer_prompt_version"
    , "added_review_comment_count"
    , "prior_findings_status"
    , "new_findings_status"
    , "lgtm_comment"
    , "prior_findings_summary"
    , "new_findings_summary"
    , "blocked_reason"
    , "solved_threads"
    , "remaining_review_threads"
    ]
    [ ("reviewed_commit_sha", stringField)
    , ("reviewer_prompt_version", stringField)
    , ("added_review_comment_count", object ["type" .= ("integer" :: Text), "minimum" .= (0 :: Int)])
    , ( "prior_findings_status"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= fmap priorFindingsStatusText allPriorFindingsStatuses
          ]
      )
    , ( "new_findings_status"
      , object
          [ "type" .= ("string" :: Text)
          , "enum" .= fmap newFindingsStatusText allNewFindingsStatuses
          ]
      )
    , ("lgtm_comment", nullableStringField)
    , ("prior_findings_summary", object ["type" .= ("array" :: Text), "items" .= stringField])
    , ("new_findings_summary", object ["type" .= ("array" :: Text), "items" .= stringField])
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
