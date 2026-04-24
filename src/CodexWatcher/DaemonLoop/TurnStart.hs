{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop.TurnStart
  ( prestartAndObserve
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop.Types
import CodexWatcher.EffectInterpreter
import CodexWatcher.Effects
import CodexWatcher.EventLog.Types
import CodexWatcher.Core.Ids (RequestId (..), ThreadId, TurnId (..))
import Data.Aeson (Value)
import Data.Text (Text)
import Data.Text qualified as Text

prestartAndObserve
  :: Monad m
  => (ActionExecutor m -> DaemonLoopConfig -> [WatcherEvent] -> DaemonObservation -> m (Either DaemonLoopFailure DaemonLoopTickResult))
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> StartTurnKind
  -> ThreadId
  -> (TurnId -> DaemonObservation)
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
prestartAndObserve observe executor config events kind threadId toObservation =
  case config.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> do
      let turnId = syntheticTurnId kind config.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeNextRequestId
      observe executor config events (toObservation turnId)
    ExecuteActions -> do
      started <- prestartTurn executor config.loopDaemonOptions.daemonRuntimeConfig kind threadId
      case started of
        Left failure -> pure (Left failure)
        Right (turnId, cachedExecutor) ->
          observe cachedExecutor config events (toObservation turnId)

prestartTurn
  :: Monad m
  => ActionExecutor m
  -> EffectRuntimeConfig
  -> StartTurnKind
  -> ThreadId
  -> m (Either DaemonLoopFailure (TurnId, ActionExecutor m))
prestartTurn executor runtimeConfig kind threadId =
  case compileEffect runtimeConfig runtimeConfig.effectRuntimeNextRequestId (startTurnEffect kind threadId) of
    ([PlannedAppServerRequest request], _nextRequestId) -> do
      response <- executor.actionAppServer.appServerSendRequest request
      case parseTurnStartTurnId response of
        Left failure -> pure (Left (DaemonLoopAppServerFailure failure))
        Right turnId -> pure (Right (turnId, cachedAppServerExecutor executor request response))
    (actions, _nextRequestId) ->
      pure (Left (DaemonLoopUnexpectedStartPlan ("expected one app-server start action, got " <> Text.pack (show actions))))

cachedAppServerExecutor :: Monad m => ActionExecutor m -> AppServerRequest -> Value -> ActionExecutor m
cachedAppServerExecutor executor expectedRequest response =
  executor
    { actionAppServer =
        AppServerInterpreter \request ->
          if request == expectedRequest
            then pure response
            else executor.actionAppServer.appServerSendRequest request
    }

startTurnEffect :: StartTurnKind -> ThreadId -> SomeEffect
startTurnEffect kind threadId =
  case kind of
    StartPlannerTurnKind -> SomeEffect (StartPlannerTurn threadId)
    StartWorkerTurnKind -> SomeEffect (StartWorkerTurn threadId)
    StartIssuePlanWorkerTurnKind issueConfig prNumber -> SomeEffect (StartIssuePlanWorkerTurn issueConfig prNumber threadId)
    StartIssueImplementationWorkerTurnKind -> SomeEffect (StartIssueImplementationWorkerTurn threadId)
    StartReviewerTurnKind prConfig reviewTargetSha -> SomeEffect (StartReviewerTurn prConfig reviewTargetSha threadId)

syntheticTurnId :: StartTurnKind -> RequestId -> TurnId
syntheticTurnId kind requestId =
  TurnId ("dry-run-" <> kindText kind <> "-" <> Text.pack (show (unRequestId requestId)))

kindText :: StartTurnKind -> Text
kindText = \case
  StartPlannerTurnKind -> "planner-turn"
  StartWorkerTurnKind -> "worker-turn"
  StartIssuePlanWorkerTurnKind {} -> "issue-plan-turn"
  StartIssueImplementationWorkerTurnKind -> "issue-implementation-turn"
  StartReviewerTurnKind {} -> "reviewer-turn"
