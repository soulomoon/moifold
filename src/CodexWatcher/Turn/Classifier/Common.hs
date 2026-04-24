{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Turn.Classifier.Common
  ( TurnCompletion (..)
  , StructuredTurnOutcome (..)
  , classifyTurnCompletion
  , parseStructuredTurnOutcome
  , missingOutputBlocked
  , structuredBlockedLikeObservation
  , nonEmptyOutput
  , normalize
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.Core.Types
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:?))
import Data.List (find)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data TurnCompletion
  = TurnStillRunning
  | TurnCompleted (Maybe Text)
  | TurnFailed Text
  deriving stock (Eq, Show)

data StructuredTurnOutcome
  = StructuredBlocked Text
  | StructuredIncomplete Text
  | StructuredComplete Text
  deriving stock (Eq, Show)

data StructuredOutcomeSpec = StructuredOutcomeSpec
  { structuredOutcomeAliases :: [Text]
  , structuredOutcomeConstructor :: Text -> StructuredTurnOutcome
  }

instance FromJSON StructuredTurnOutcome where
  parseJSON = withObject "StructuredTurnOutcome" \objectValue -> do
    maybeOutcome <- objectValue .:? "outcome"
    outcome <- maybe (fail "missing outcome") pure (firstNonEmpty [maybeOutcome])
    reason <- objectValue .:? "reason"
    summary <- objectValue .:? "summary"
    comment <- objectValue .:? "comment"
    evidence <- objectValue .:? "evidence"
    detail <- maybe (fail "missing structured outcome detail") pure (firstNonEmpty [reason, summary, comment, evidence])
    case find (matchesStructuredOutcome (normalize outcome)) structuredOutcomeSpecs of
      Just spec -> pure (spec.structuredOutcomeConstructor detail)
      Nothing -> fail ("unsupported structured turn outcome: " <> Text.unpack (normalize outcome))

classifyTurnCompletion :: AppServerTurn -> TurnCompletion
classifyTurnCompletion turn
  | normalizedStatus `elem` runningStatuses = TurnStillRunning
  | normalizedStatus `elem` completedStatuses = TurnCompleted turn.appServerTurnOutput
  | normalizedStatus `elem` failedStatuses = TurnFailed (reason "turn ended unsuccessfully")
  | otherwise = TurnStillRunning
 where
  normalizedStatus = normalize turn.appServerTurnStatus
  reason fallback = maybe fallback nonEmptyOutput turn.appServerTurnOutput

parseStructuredTurnOutcome :: Text -> Maybe StructuredTurnOutcome
parseStructuredTurnOutcome output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right structured -> Just structured

matchesStructuredOutcome :: Text -> StructuredOutcomeSpec -> Bool
matchesStructuredOutcome outcome spec =
  outcome `elem` spec.structuredOutcomeAliases

structuredOutcomeSpecs :: [StructuredOutcomeSpec]
structuredOutcomeSpecs =
  [ StructuredOutcomeSpec ["blocked"] StructuredBlocked
  , StructuredOutcomeSpec ["incomplete"] StructuredIncomplete
  , StructuredOutcomeSpec ["complete"] StructuredComplete
  ]

structuredBlockedLikeObservation :: (BlockedReason -> observation) -> StructuredTurnOutcome -> Maybe observation
structuredBlockedLikeObservation toObservation = \case
  StructuredBlocked reason -> Just (toObservation (BlockedReason reason))
  StructuredIncomplete reason -> Just (toObservation (BlockedReason reason))
  _ -> Nothing

runningStatuses :: [Text]
runningStatuses =
  ["", "unknown", "queued", "created", "starting", "running", "in_progress", "in-progress", "pending"]

completedStatuses :: [Text]
completedStatuses =
  ["complete", "completed", "done", "success", "succeeded", "finished"]

failedStatuses :: [Text]
failedStatuses =
  ["failed", "failure", "error", "errored", "cancelled", "canceled", "interrupted", "aborted"]

missingOutputBlocked :: Text -> (BlockedReason -> observation) -> Maybe Text -> Maybe observation
missingOutputBlocked fallback toObservation output
  | hasMeaningfulOutput output = Nothing
  | otherwise = Just (toObservation (BlockedReason fallback))

hasMeaningfulOutput :: Maybe Text -> Bool
hasMeaningfulOutput =
  maybe False (not . Text.null . Text.strip)

firstNonEmpty :: [Maybe Text] -> Maybe Text
firstNonEmpty [] = Nothing
firstNonEmpty (Nothing : rest) = firstNonEmpty rest
firstNonEmpty (Just text : rest)
  | Text.null (Text.strip text) = firstNonEmpty rest
  | otherwise = Just (Text.strip text)

nonEmptyOutput :: Text -> Text
nonEmptyOutput output
  | Text.null stripped = "empty app-server turn output"
  | otherwise = stripped
 where
  stripped = Text.strip output

normalize :: Text -> Text
normalize =
  Text.toLower . Text.strip
