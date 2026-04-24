{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssuePlanning.TurnClassifier
  ( classifyIssuePlanningTurn
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.Core.Types
import Data.Aeson (FromJSON (..), Value (..), eitherDecodeStrict', withObject, (.:?), (.!=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

newtype StructuredPlanningIssueRequests = StructuredPlanningIssueRequests (NonEmpty IssueCreationRequest)
  deriving stock (Eq, Show)

newtype StructuredPlanningGraph = StructuredPlanningGraph PlanningGraph
  deriving stock (Eq, Show)

instance FromJSON StructuredPlanningIssueRequests where
  parseJSON = withObject "StructuredPlanningIssueRequests" \objectValue -> do
    issues <- objectValue .:? "issues_to_create" .!= []
    subissues <- objectValue .:? "subissues_to_create" .!= []
    case issues <> subissues of
      firstRequest : restRequests -> pure (StructuredPlanningIssueRequests (firstRequest :| restRequests))
      [] -> fail "issues_to_create and subissues_to_create must not both be empty"

instance FromJSON StructuredPlanningGraph where
  parseJSON = withObject "StructuredPlanningGraph" \objectValue ->
    if hasPlanningGraphFields objectValue
      then StructuredPlanningGraph <$> parseJSON (Object objectValue)
      else fail "missing planning graph fields"

classifyIssuePlanningTurn :: AppServerTurn -> Maybe IssuePlanningObservation
classifyIssuePlanningTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedPlanningBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "planning turn completed without output" ObservedPlanningBlocked output ->
          Just observation
      | Just requests <- output >>= parsePlanningIssueRequests ->
          Just (ObservedPlanningIssuesRequested requests)
      | Just outputText <- output
      , planningIssueRequestPayloadInvalid outputText ->
          Just (ObservedPlanningBlocked (BlockedReason "planning turn returned invalid issue creation payload"))
      | Just graph <- output >>= parsePlanningGraph ->
          Just (ObservedPlanningGraphUpdated graph)
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssuePlanning structured
      | otherwise ->
          Just (ObservedPlanningBlocked (BlockedReason "planning turn completed without structured outcome"))

parsePlanningIssueRequests :: Text -> Maybe (NonEmpty IssueCreationRequest)
parsePlanningIssueRequests output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right (StructuredPlanningIssueRequests requests) -> Just requests

parsePlanningGraph :: Text -> Maybe PlanningGraph
parsePlanningGraph output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right (StructuredPlanningGraph graph) -> Just graph

planningIssueRequestPayloadInvalid :: Text -> Bool
planningIssueRequestPayloadInvalid output =
  case eitherDecodeStrict' bytes :: Either String StructuredPlanningIssueRequests of
    Right _ -> False
    Left _ ->
      case eitherDecodeStrict' bytes :: Either String Value of
        Right (Object objectValue) ->
          any
            (`KeyMap.member` objectValue)
            [ Key.fromString "issues_to_create"
            , Key.fromString "subissues_to_create"
            ]
        _ -> False
 where
  bytes = Text.Encoding.encodeUtf8 (Text.strip output)

hasPlanningGraphFields :: KeyMap.KeyMap Value -> Bool
hasPlanningGraphFields objectValue =
  any
    (`KeyMap.member` objectValue)
    [ Key.fromString "ready_issues"
    , Key.fromString "blocked_issues"
    , Key.fromString "dependencies"
    ]

classifyStructuredIssuePlanning :: StructuredTurnOutcome -> Maybe IssuePlanningObservation
classifyStructuredIssuePlanning structured =
  maybe
    (Just ObservedPlanningTurnCompleted)
    Just
    (structuredBlockedLikeObservation ObservedPlanningBlocked structured)
