{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.EventLogRepair
  ( EventLogRepairPlan (..)
  , repairIssueImplementEventLog
  ) where

import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Workflow.Agent.Ids (TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..), PrNumber (..))
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data EventLogRepairPlan = EventLogRepairPlan
  { repairFailure :: ReplayFailure
  , repairStrategy :: Text
  , repairOriginalEvents :: [WatcherEvent]
  , repairRepairedEvents :: [WatcherEvent]
  , repairInsertedEvents :: [WatcherEvent]
  , repairDroppedEvents :: [WatcherEvent]
  , repairReplayResult :: EventReplayResult
  }
  deriving stock (Show, Generic)

repairIssueImplementEventLog :: [WatcherEvent] -> Either Text EventLogRepairPlan
repairIssueImplementEventLog events =
  case replayEventLog events of
    Right _ ->
      Left "event log is already valid; no repair needed"
    Left failure ->
      repairFromFailure events failure

repairFromFailure :: [WatcherEvent] -> ReplayFailure -> Either Text EventLogRepairPlan
repairFromFailure events failure =
  case failure.event of
    IssuePlanningReadyIssuesFixed ->
      repairStalePlanningReadyIssuesFixed events failure
    IssuePullRequestCreatedEvent prNumber ->
      repairMissingPlanBeforePullRequest events failure (IssuePullRequestCreatedEvent prNumber) prNumber
    IssuePullRequestReusedEvent prNumber ->
      repairMissingPlanBeforePullRequest events failure (IssuePullRequestReusedEvent prNumber) prNumber
    IssueImplementationCompletedEvent prNumber _maybeReviewerThreadId ->
      repairCompletionWithoutImplementationTurn events failure prNumber
    _ ->
      Left ("no deterministic repair rule for event " <> eventName failure.event)

repairStalePlanningReadyIssuesFixed :: [WatcherEvent] -> ReplayFailure -> Either Text EventLogRepairPlan
repairStalePlanningReadyIssuesFixed events failure = do
  let (prefix, suffixAfterFailure) = splitAtFailure failure events
      candidate = prefix <> suffixAfterFailure
  finishPlan events failure "dropped stale planning ready-issues marker" [] [failure.event] candidate

repairMissingPlanBeforePullRequest :: [WatcherEvent] -> ReplayFailure -> WatcherEvent -> PrNumber -> Either Text EventLogRepairPlan
repairMissingPlanBeforePullRequest events failure prEvent prNumber = do
  let (prefix, suffixAfterFailure) = splitAtFailure failure events
  replayPrefix <- replayPrefixState prefix
  case replayPrefix.replayState of
    SomeWatcherState IssuePlanReady {} -> pure ()
    other ->
      Left
        ( "missing-plan repair expected IssuePlanReady before PR event, got "
            <> Text.pack (show (someDomain other))
            <> "/"
            <> Text.pack (show (somePhase other))
        )
  issueNumber' <- issueNumberFromEvents events
  let reason = recoveryReason failure "insert missing issue plan events before existing PR"
      inserted =
        [ WatcherRecoveredInvalidState reason
        , IssuePlanTurnStartedEvent (syntheticRecoveryPlanTurn issueNumber' prNumber)
        , IssuePlanCompletedEvent syntheticRecoveryPlanMarkdown Nothing
        ]
      candidate = prefix <> inserted <> [prEvent] <> dropUnsafeImplementationCompletions (prefix <> inserted <> [prEvent]) suffixAfterFailure
      dropped = droppedEvents events candidate
  finishPlan events failure "inserted missing issue plan events and re-entered implementation before marking complete" inserted dropped candidate

repairCompletionWithoutImplementationTurn :: [WatcherEvent] -> ReplayFailure -> PrNumber -> Either Text EventLogRepairPlan
repairCompletionWithoutImplementationTurn events failure prNumber = do
  let (prefix, suffixAfterFailure) = splitAtFailure failure events
  replayPrefix <- replayPrefixState prefix
  issueNumber' <- issueNumberFromEvents events
  let reason = recoveryReason failure "drop unsafe completion and re-enter implementation"
      recoveryMarker = WatcherRecoveredInvalidState reason
      missingPlanEvents =
        [ IssuePlanTurnStartedEvent (syntheticRecoveryPlanTurn issueNumber' prNumber)
        , IssuePlanCompletedEvent syntheticRecoveryPlanMarkdown Nothing
        ]
  inserted <-
    case replayPrefix.replayState of
      SomeWatcherState IssueReadyToPlan {} -> Right (recoveryMarker : missingPlanEvents)
      SomeWatcherState IssueImplementationReady {} -> Right [recoveryMarker]
      SomeWatcherState IssuePlanReady {} -> Right [recoveryMarker]
      other ->
        Left
          ( "completion-without-implementation repair expected IssueReadyToPlan, IssuePlanReady, or IssueImplementationReady before completion, got "
              <> Text.pack (show (someDomain other))
              <> "/"
              <> Text.pack (show (somePhase other))
          )
  let
      candidate = prefix <> inserted <> dropUnsafeImplementationCompletions (prefix <> inserted) suffixAfterFailure
      dropped = droppedEvents events candidate
  finishPlan events failure "dropped unsafe completion and re-entered implementation" inserted dropped candidate

finishPlan :: [WatcherEvent] -> ReplayFailure -> Text -> [WatcherEvent] -> [WatcherEvent] -> [WatcherEvent] -> Either Text EventLogRepairPlan
finishPlan original failure strategy inserted dropped candidate =
  case replayEventLog candidate of
    Left secondFailure ->
      Left
        ( "repair candidate still failed replay at event "
            <> Text.pack (show secondFailure.eventIndex)
            <> " ("
            <> eventName secondFailure.event
            <> "): "
            <> secondFailure.reason
        )
    Right replay ->
      Right
        EventLogRepairPlan
          { repairFailure = failure
          , repairStrategy = strategy
          , repairOriginalEvents = original
          , repairRepairedEvents = candidate
          , repairInsertedEvents = inserted
          , repairDroppedEvents = dropped
          , repairReplayResult = replay
          }

splitAtFailure :: ReplayFailure -> [WatcherEvent] -> ([WatcherEvent], [WatcherEvent])
splitAtFailure failure events =
  let failureOffset = max 0 (failure.eventIndex - 1)
      prefix = take failureOffset events
      suffixIncludingFailure = drop failureOffset events
   in (prefix, drop 1 suffixIncludingFailure)

replayPrefixState :: [WatcherEvent] -> Either Text EventReplayResult
replayPrefixState prefix =
  case replayEventLog prefix of
    Left failure ->
      Left
        ( "prefix replay unexpectedly failed at event "
            <> Text.pack (show failure.eventIndex)
            <> " ("
            <> eventName failure.event
            <> "): "
            <> failure.reason
        )
    Right replay -> Right replay

dropUnsafeImplementationCompletions :: [WatcherEvent] -> [WatcherEvent] -> [WatcherEvent]
dropUnsafeImplementationCompletions base =
  reverse . snd . foldl go (hasImplementationTurn base, [])
 where
  go (hasTurn, kept) event =
    case event of
      IssueImplementationTurnStartedEvent {} -> (True, event : kept)
      IssueImplementationCompletedEvent {}
        | hasTurn -> (hasTurn, event : kept)
        | otherwise -> (hasTurn, kept)
      _ -> (hasTurn, event : kept)

hasImplementationTurn :: [WatcherEvent] -> Bool
hasImplementationTurn =
  any \case
    IssueImplementationTurnStartedEvent {} -> True
    _ -> False

droppedEvents :: [WatcherEvent] -> [WatcherEvent] -> [WatcherEvent]
droppedEvents original repaired =
  dropByShow (fmap show repaired) original
 where
  dropByShow [] remaining = remaining
  dropByShow _ [] = []
  dropByShow repairedShows (event : rest)
    | show event `elem` repairedShows = dropByShow (removeFirst (show event) repairedShows) rest
    | otherwise = event : dropByShow repairedShows rest

removeFirst :: Eq a => a -> [a] -> [a]
removeFirst _ [] = []
removeFirst target (item : rest)
  | target == item = rest
  | otherwise = item : removeFirst target rest

issueNumberFromEvents :: [WatcherEvent] -> Either Text IssueNumber
issueNumberFromEvents =
  firstIssueImplement
 where
  firstIssueImplement [] = Left "issue implement repair requires an issue_implement_initialized event"
  firstIssueImplement (IssueImplementInitialized config _threadId : _) = Right config.issueNumber
  firstIssueImplement (_ : rest) = firstIssueImplement rest

syntheticRecoveryPlanTurn :: IssueNumber -> PrNumber -> TurnId
syntheticRecoveryPlanTurn issueNumber' prNumber =
  TurnId
    ( "recovery-plan-issue-"
        <> Text.pack (show (unIssueNumber issueNumber'))
        <> "-pr-"
        <> Text.pack (show (unPrNumber prNumber))
    )

syntheticRecoveryPlanMarkdown :: Text
syntheticRecoveryPlanMarkdown =
  "Recovered after event-log repair. Continue from the existing PR and verify the issue scope before implementation."

recoveryReason :: ReplayFailure -> Text -> Text
recoveryReason failure action =
  Text.intercalate
    "; "
    [ "recoveredFromInvalidState=true"
    , "action=" <> action
    , "failedEventIndex=" <> Text.pack (show failure.eventIndex)
    , "failedEvent=" <> eventName failure.event
    , "reason=" <> failure.reason
    ]
