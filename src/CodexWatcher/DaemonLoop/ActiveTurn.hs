{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop.ActiveTurn
  ( clearStaleActiveTurnMarker
  , clearStaleActiveTurnMarkerWhenInactive
  , handleMissingActiveTurn
  , readActiveTurn
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog.Types
import CodexWatcher.Domain.IssueImplement.Watcher
import CodexWatcher.Domain.IssuePlanning.Watcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Domain.IssuePlanning.Loop qualified as PlanningLoop
import CodexWatcher.Domain.PrReview.Watcher
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Paths (runtimeStateDirFile)
import CodexWatcher.Core.Ids (ThreadId (..), TurnId (..))
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Core.Thread (ActiveTurn (..))
import Data.Aeson (FromJSON (..), Result (..), ToJSON (..), Value (..), fromJSON, object, withObject, (.:), (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data StaleActiveTurnMarker = StaleActiveTurnMarker
  { staleMarkerDomain :: Text
  , staleMarkerThreadId :: Text
  , staleMarkerTurnId :: Text
  , staleMarkerStateFingerprint :: Text
  , staleMarkerReason :: Text
  , staleMarkerFirstSeenAt :: Text
  , staleMarkerLastSeenAt :: Text
  , staleMarkerCount :: Int
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON StaleActiveTurnMarker where
  toJSON marker =
    object
      [ "domain" .= marker.staleMarkerDomain
      , "threadId" .= marker.staleMarkerThreadId
      , "turnId" .= marker.staleMarkerTurnId
      , "stateFingerprint" .= marker.staleMarkerStateFingerprint
      , "reason" .= marker.staleMarkerReason
      , "firstSeenAt" .= marker.staleMarkerFirstSeenAt
      , "lastSeenAt" .= marker.staleMarkerLastSeenAt
      , "count" .= marker.staleMarkerCount
      ]

instance FromJSON StaleActiveTurnMarker where
  parseJSON = withObject "StaleActiveTurnMarker" \objectValue ->
    StaleActiveTurnMarker
      <$> objectValue .: "domain"
      <*> objectValue .: "threadId"
      <*> objectValue .: "turnId"
      <*> objectValue .: "stateFingerprint"
      <*> objectValue .: "reason"
      <*> objectValue .: "firstSeenAt"
      <*> objectValue .: "lastSeenAt"
      <*> objectValue .: "count"

clearStaleActiveTurnMarkerWhenInactive :: Monad m => ActionExecutor m -> DaemonLoopConfig -> SomeWatcherState -> m ()
clearStaleActiveTurnMarkerWhenInactive executor config state =
  if watcherStateHasActiveTurn state
    then pure ()
    else clearStaleActiveTurnMarker executor config

watcherStateHasActiveTurn :: SomeWatcherState -> Bool
watcherStateHasActiveTurn = \case
  SomeWatcherState PlanningTurnActive {} -> True
  SomeWatcherState IssueInPlanMode {} -> True
  SomeWatcherState IssueImplementing {} -> True
  SomeWatcherState PrFixingReviews {} -> True
  SomeWatcherState PrReviewingClean {} -> True
  _ -> False

handleMissingActiveTurn
  :: Monad m
  => (ActionExecutor m -> DaemonLoopConfig -> EventReplayResult -> Text -> m (Either DaemonLoopFailure DaemonLoopTickResult))
  -> (ActionExecutor m -> DaemonLoopConfig -> [WatcherEvent] -> DaemonObservation -> m (Either DaemonLoopFailure DaemonLoopTickResult))
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
handleMissingActiveTurn idle observe executor config events replay activeTurn =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions ->
      idle executor config replay (missingActiveTurnReason activeTurn)
    ExecuteActions -> do
      marker <- updateStaleActiveTurnMarker executor config replay activeTurn
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Warn
            "stale_active_turn_seen"
            "active turn was not found"
            [ "turnId" .= unTurnId (activeTurn.activeTurnId)
            , "threadId" .= unThreadId (activeTurn.activeThreadId)
            , "count" .= marker.staleMarkerCount
            ]
        )
      if marker.staleMarkerCount >= staleActiveTurnThreshold
        then do
          clearStaleActiveTurnMarker executor config
          case activeTurnBlockedObservation events replay.replayState activeTurn of
            Just observation -> observe executor config events observation
            Nothing -> idle executor config replay (missingActiveTurnReason activeTurn)
        else idle executor config replay (missingActiveTurnReason activeTurn)

staleActiveTurnThreshold :: Int
staleActiveTurnThreshold = 3

updateStaleActiveTurnMarker
  :: Monad m
  => ActionExecutor m
  -> DaemonLoopConfig
  -> EventReplayResult
  -> ActiveTurn
  -> m StaleActiveTurnMarker
updateStaleActiveTurnMarker executor config replay activeTurn = do
  previous <- readStaleActiveTurnMarker executor config
  let fingerprint = activeTurnStateFingerprint replay.replayState activeTurn
      reason = missingActiveTurnReason activeTurn
      matchesActiveTurn = maybe False (`markerMatchesActiveTurn` (activeTurn, fingerprint)) previous
      count =
        if matchesActiveTurn
          then maybe 1 (\prior -> prior.staleMarkerCount + 1) previous
          else 1
      firstSeenAt =
        if matchesActiveTurn
          then maybe "unknown" (\prior -> prior.staleMarkerFirstSeenAt) previous
          else "unknown"
      marker =
        StaleActiveTurnMarker
          { staleMarkerDomain = Text.pack (show (someDomain replay.replayState))
          , staleMarkerThreadId = unThreadId (activeTurn.activeThreadId)
          , staleMarkerTurnId = unTurnId (activeTurn.activeTurnId)
          , staleMarkerStateFingerprint = fingerprint
          , staleMarkerReason = reason
          , staleMarkerFirstSeenAt = firstSeenAt
          , staleMarkerLastSeenAt = "unknown"
          , staleMarkerCount = count
          }
  runtimeWriteJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config) (toJSON marker)
  pure marker

missingActiveTurnReason :: ActiveTurn -> Text
missingActiveTurnReason activeTurn =
  "active turn not found: " <> unTurnId (activeTurn.activeTurnId)

markerMatchesActiveTurn :: StaleActiveTurnMarker -> (ActiveTurn, Text) -> Bool
markerMatchesActiveTurn marker (activeTurn, fingerprint) =
  marker.staleMarkerThreadId == unThreadId (activeTurn.activeThreadId)
    && marker.staleMarkerTurnId == unTurnId (activeTurn.activeTurnId)
    && marker.staleMarkerStateFingerprint == fingerprint

readStaleActiveTurnMarker :: Monad m => ActionExecutor m -> DaemonLoopConfig -> m (Maybe StaleActiveTurnMarker)
readStaleActiveTurnMarker executor config = do
  value <- runtimeReadJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config)
  pure case value of
    Right Null -> Nothing
    Right jsonValue ->
      case fromJSON jsonValue of
        Success marker -> Just marker
        Error _ -> Nothing
    Left _ -> Nothing

clearStaleActiveTurnMarker :: Monad m => ActionExecutor m -> DaemonLoopConfig -> m ()
clearStaleActiveTurnMarker executor config =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> pure ()
    ExecuteActions -> runtimeWriteJsonValue (actionRuntime executor) (staleActiveTurnMarkerPath config) Null

staleActiveTurnMarkerPath :: DaemonLoopConfig -> FilePath
staleActiveTurnMarkerPath config =
  runtimeStateDirFile config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir "stale-active-turn.json"

activeTurnStateFingerprint :: SomeWatcherState -> ActiveTurn -> Text
activeTurnStateFingerprint state activeTurn =
  Text.intercalate
    ":"
    [ Text.pack (show (someDomain state))
    , Text.pack (show (somePhase state))
    , unThreadId (activeTurn.activeThreadId)
    , unTurnId (activeTurn.activeTurnId)
    ]

activeTurnBlockedObservation :: [WatcherEvent] -> SomeWatcherState -> ActiveTurn -> Maybe DaemonObservation
activeTurnBlockedObservation events state activeTurn =
  let reason = BlockedReason ("active turn not found after 3 consecutive checks: " <> unTurnId (activeTurn.activeTurnId))
   in case state of
        SomeWatcherState PlanningTurnActive {} ->
          Just
            ( DaemonIssuePlanningObservation
                ( if PlanningLoop.planningRetryAvailable events
                    then ObservedPlanningTurnRetryRequested reason
                    else ObservedPlanningBlocked reason
                )
            )
        SomeWatcherState IssueInPlanMode {} ->
          Just (DaemonIssueImplementObservation (ObservedIssueImplementBlocked reason))
        SomeWatcherState IssueImplementing {} ->
          Just (DaemonIssueImplementObservation (ObservedIssueImplementBlocked reason))
        SomeWatcherState PrFixingReviews {} ->
          Just (DaemonPrReviewObservation (ObservedPrReviewBlocked reason))
        SomeWatcherState PrReviewingClean {} ->
          Just (DaemonPrReviewObservation (ObservedPrReviewBlocked reason))
        _ ->
          Nothing

readActiveTurn :: Monad m => ActionExecutor m -> DaemonLoopConfig -> ActiveTurn -> m (Either DaemonLoopFailure ActiveTurnReadResult)
readActiveTurn executor config activeTurn = do
  response <-
    executor.actionAppServer.appServerSendRequest
      (threadReadRequest config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeNextRequestId activeTurn.activeThreadId True)
  pure case parseThreadReadTurns response of
    Left failure -> Left (DaemonLoopAppServerFailure failure)
    Right turns ->
      Right
        ActiveTurnReadResult
          { activeTurnReadTurn = latestTurnById activeTurn.activeTurnId turns
          , activeTurnReadThreadSystemError = threadSystemError response
          }
