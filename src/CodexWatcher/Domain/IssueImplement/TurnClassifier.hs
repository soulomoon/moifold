{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Domain.IssueImplement.TurnClassifier
  ( classifyIssueImplementationTurn
  , classifyIssuePlanTurn
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Turn.Classifier.Common
import CodexWatcher.Core.Ids (PrNumber)
import CodexWatcher.Core.Reason (BlockedReason (..))
import Data.Aeson (FromJSON (..), eitherDecodeStrict', withObject, (.:))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

data IssuePlanTurnReport = IssuePlanTurnReport
  { issuePlanReportOutcome :: Text
  , issuePlanReportReason :: Text
  , issuePlanReportSummary :: Text
  , issuePlanReportMarkdown :: Text
  }
  deriving stock (Eq, Show)

instance FromJSON IssuePlanTurnReport where
  parseJSON = withObject "IssuePlanTurnReport" \objectValue ->
    IssuePlanTurnReport
      <$> objectValue .: "outcome"
      <*> objectValue .: "reason"
      <*> objectValue .: "summary"
      <*> objectValue .: "plan_markdown"

classifyIssuePlanTurn :: AppServerTurn -> Maybe IssueImplementObservation
classifyIssuePlanTurn turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedIssueImplementBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "plan turn completed without output" ObservedIssueImplementBlocked output ->
          Just observation
      | Just report <- output >>= parseIssuePlanTurnReport ->
          classifyIssuePlanReport report
      | otherwise ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed without structured plan output"))

classifyIssueImplementationTurn :: Maybe PrNumber -> AppServerTurn -> Maybe IssueImplementObservation
classifyIssueImplementationTurn maybePr turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      Nothing
    TurnFailed reason ->
      Just (ObservedImplementationBlocked (BlockedReason reason))
    TurnCompleted output
      | Just observation <- missingOutputBlocked "implementation turn completed without output" ObservedImplementationBlocked output ->
          Just observation
      | Just structured <- output >>= parseStructuredTurnOutcome ->
          classifyStructuredIssueImplementation maybePr structured
      | otherwise ->
          Just (ObservedImplementationIncomplete "implementation turn completed without structured outcome")

parseIssuePlanTurnReport :: Text -> Maybe IssuePlanTurnReport
parseIssuePlanTurnReport output =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 (Text.strip output)) of
    Left _ -> Nothing
    Right report -> Just report

classifyIssuePlanReport :: IssuePlanTurnReport -> Maybe IssueImplementObservation
classifyIssuePlanReport report =
  case normalize report.issuePlanReportOutcome of
    "complete"
      | Text.null planMarkdown ->
          Just (ObservedIssueImplementBlocked (BlockedReason "plan turn completed with empty plan_markdown"))
      | otherwise ->
          Just (ObservedPlanCompleted planMarkdown Nothing)
    "blocked" ->
      Just (ObservedIssueImplementBlocked (BlockedReason (nonEmptyDetail "plan turn blocked without reason" report.issuePlanReportReason)))
    _ ->
      Just (ObservedIssueImplementBlocked (BlockedReason ("unsupported issue plan outcome: " <> report.issuePlanReportOutcome)))
 where
  planMarkdown = Text.strip report.issuePlanReportMarkdown
  nonEmptyDetail fallback detail =
    case Text.strip detail of
      "" -> fallback
      stripped -> stripped

classifyStructuredIssueImplementation :: Maybe PrNumber -> StructuredTurnOutcome -> Maybe IssueImplementObservation
classifyStructuredIssueImplementation maybePr = \case
  StructuredBlocked reason -> Just (ObservedImplementationBlocked (BlockedReason reason))
  StructuredIncomplete reason -> Just (ObservedImplementationIncomplete reason)
  StructuredComplete _reason ->
    Just (completedImplementationObservation maybePr)

completedImplementationObservation :: Maybe PrNumber -> IssueImplementObservation
completedImplementationObservation = \case
  Just prNumber -> ObservedImplementationCompleted prNumber
  Nothing -> ObservedImplementationIncomplete "implementation completed before a pull request was known"
