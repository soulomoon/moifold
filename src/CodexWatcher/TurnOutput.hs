{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.TurnOutput
  ( issueWorkerTurnInput
  , plannerTurnInput
  , reviewerTurnInput
  , structuredTurnOutcomeInstructions
  , structuredTurnOutputSchema
  ) where

import Data.Aeson (Value, object, (.=))
import Data.Text (Text)

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

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  "Return only JSON with an outcome field. Use outcome=blocked with reason when you cannot proceed, outcome=incomplete with reason when follow-up is required, and outcome=complete with summary when the turn is done."

plannerTurnInput :: Text
plannerTurnInput =
  structuredTurnOutcomeInstructions
    <> " For issue planning, inspect existing GitHub issues and existing sub-issues before splitting work. Use issues_to_create only for independent top-level issues. Use subissues_to_create for GitHub sub-issues, and every subissues_to_create item must include title, a concrete body, and parentIssueNumber. A sub-issue body must describe scope, acceptance criteria, dependencies/blockers, and how it stays compatible with sibling sub-issues. When a parent issue already has sub-issues, new sub-issues must be compatible with the existing set: do not duplicate titles/scopes, do not create overlapping work, and preserve dependency boundaries between siblings. After issue creation the watcher will re-enter planning. When no more issues need to be created, return ready_issues for issues safe to implement now, blocked_issues for issues that must wait, and dependencies for issue ordering. ready_issues must be an array of issue numbers, not objects. blocked_issues must use objects shaped as {\"issueNumber\": 27, \"blockedBy\": [26], \"reason\": \"...\"}. dependencies must use objects shaped as {\"issueNumber\": 27, \"dependsOn\": [26]}. Only issues listed in ready_issues can be started by fanout; do not list an issue as ready if another open issue must be completed first. Use outcome=complete only when the issue graph is stable and ready for dependency-aware implementer fanout."

issueWorkerTurnInput :: Text
issueWorkerTurnInput =
  structuredTurnOutcomeInstructions
    <> " For issue implementation triage use already_fixed or needs_implementation when appropriate; for implementation use complete when the PR is ready for review."

reviewerTurnInput :: Text
reviewerTurnInput =
  structuredTurnOutcomeInstructions
    <> " For PR review use clean with comment when the PR is acceptable, or problems when review comments were added."

stringField :: Value
stringField =
  object ["type" .= ("string" :: Text)]

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
