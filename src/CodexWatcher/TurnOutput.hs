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
          ]
    ]

structuredTurnOutcomeInstructions :: Text
structuredTurnOutcomeInstructions =
  "Return only JSON matching the configured output schema. Use outcome=blocked with reason when you cannot proceed, outcome=incomplete with reason when follow-up is required, and outcome=complete with summary when the turn is done."

plannerTurnInput :: Text
plannerTurnInput =
  structuredTurnOutcomeInstructions
    <> " For issue planning, use outcome=complete after selecting or confirming implementable issues."

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
