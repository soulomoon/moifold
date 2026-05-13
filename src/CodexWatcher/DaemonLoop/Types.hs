{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.DaemonLoop.Types
  ( ActiveTurnReadResult (..)
  , CommandActionReport (..)
  , DaemonLoopConfig (..)
  , DaemonLoopFailure (..)
  , DaemonLoopTickResult (..)
  , DomainLoopOps (..)
  , StartTurnKind (..)
  , SuccessfulCommandActionReport (..)
  , actionOnlyTickResult
  , finalCommandReport
  , firstCommandFailure
  , idleTickResult
  , observeClassifiedActiveTurn
  , successfulCommandActionReport
  , systemErrorTurn
  , withPrependedActionReport
  , withPrependedActionReports
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionReport (..), ActionExecutionResult (..), ActionExecutor, ActionOutcome (..))
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerClientFailure, AppServerTurn (..))
import CodexWatcher.Daemon (DaemonFailure (..), DaemonObservation, DaemonObservedTickResult, DaemonOptions)
import CodexWatcher.EventLog.Types (EventReplayResult, WatcherEvent)
import CodexWatcher.Runtime.Command.Types (CommandReport (..))
import CodexWatcher.Core.Thread (ActiveTurn (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig)
import CodexWatcher.Domain.PrReview.Types (PrConfig, ReviewEvidence)
import CodexWatcher.Workflow.Agent.Ids (ThreadId, TurnId (..))
import CodexWatcher.Workflow.GitHub.Ids (CommitSha, PrNumber)
import Data.Text (Text)
import GHC.Generics (Generic)

data DaemonLoopConfig = DaemonLoopConfig
  { loopDaemonOptions :: DaemonOptions
  , loopPlannerThreadId :: Maybe ThreadId
  }
  deriving stock (Eq, Show, Generic)

data DaemonLoopFailure
  = DaemonLoopDaemonFailure DaemonFailure
  | DaemonLoopExternalFailure Text
  | DaemonLoopAppServerFailure AppServerClientFailure
  | DaemonLoopUnexpectedStartPlan Text
  deriving stock (Eq, Show, Generic)

data DaemonLoopTickResult = DaemonLoopTickResult
  { loopReplayResult :: EventReplayResult
  , loopObservation :: Maybe DaemonObservation
  , loopObservedTick :: Maybe DaemonObservedTickResult
  , loopIdleReason :: Maybe Text
  , loopActionReports :: [ActionExecutionReport]
  }
  deriving stock (Show, Generic)

data StartTurnKind
  = StartPlannerTurnKind
  | StartWorkerTurnKind ReviewEvidence
  | StartIssuePlanWorkerTurnKind IssueConfig PrNumber
  | StartIssueImplementationWorkerTurnKind
  | StartReviewerTurnKind PrConfig CommitSha
  | StartReviewerVerificationTurnKind PrConfig ReviewEvidence CommitSha
  | StartIssueFinalReviewTurnKind IssueConfig PrNumber CommitSha
  deriving stock (Eq, Show)

data ActiveTurnReadResult = ActiveTurnReadResult
  { activeTurnReadTurn :: Maybe AppServerTurn
  , activeTurnReadThreadSystemError :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

data CommandActionReport = CommandActionReport
  { commandActionExecutionReport :: ActionExecutionReport
  , commandActionCommandReport :: CommandReport
  }
  deriving stock (Show, Generic)

data SuccessfulCommandActionReport = SuccessfulCommandActionReport
  { successfulCommandActionExecutionReport :: ActionExecutionReport
  , successfulCommandActionCommandReport :: CommandReport
  }
  deriving stock (Show, Generic)

actionOnlyTickResult :: EventReplayResult -> Maybe Text -> [ActionExecutionReport] -> DaemonLoopTickResult
actionOnlyTickResult replay idleReason reports =
  DaemonLoopTickResult
    { loopReplayResult = replay
    , loopObservation = Nothing
    , loopObservedTick = Nothing
    , loopIdleReason = idleReason
    , loopActionReports = reports
    }

idleTickResult :: EventReplayResult -> Text -> [ActionExecutionReport] -> DaemonLoopTickResult
idleTickResult replay reason =
  actionOnlyTickResult replay (Just reason)

withPrependedActionReport :: ActionExecutionReport -> Either DaemonLoopFailure DaemonLoopTickResult -> Either DaemonLoopFailure DaemonLoopTickResult
withPrependedActionReport report =
  fmap \tick -> tick {loopActionReports = report : tick.loopActionReports}

withPrependedActionReports :: [ActionExecutionReport] -> Either DaemonLoopFailure DaemonLoopTickResult -> Either DaemonLoopFailure DaemonLoopTickResult
withPrependedActionReports reports =
  fmap \tick -> tick {loopActionReports = reports <> tick.loopActionReports}

finalCommandReport :: [ActionExecutionReport] -> Maybe CommandActionReport
finalCommandReport reports =
  case reverse reports of
    [] -> Nothing
    report : _ ->
      case report.actionExecutionResult of
        CommandActionResult commandReport -> Just (CommandActionReport report commandReport)
        _ -> Nothing

successfulCommandActionReport :: CommandActionReport -> Either DaemonLoopFailure SuccessfulCommandActionReport
successfulCommandActionReport report
  | report.commandActionExecutionReport.actionExecutionOutcome == ActionSucceeded =
      Right (SuccessfulCommandActionReport report.commandActionExecutionReport report.commandActionCommandReport)
  | ActionSoftFailed {} <- report.commandActionExecutionReport.actionExecutionOutcome =
      Right (SuccessfulCommandActionReport report.commandActionExecutionReport report.commandActionCommandReport)
  | otherwise =
      Left
        ( DaemonLoopDaemonFailure
            (DaemonActionFailed report.commandActionExecutionReport.actionExecutionAction report.commandActionCommandReport)
        )

firstCommandFailure :: [ActionExecutionReport] -> Maybe DaemonFailure
firstCommandFailure [] =
  Nothing
firstCommandFailure (report : rest) =
  case report.actionExecutionResult of
    CommandActionResult commandReport
      | ActionHardFailed {} <- report.actionExecutionOutcome ->
          Just (DaemonActionFailed report.actionExecutionAction commandReport)
    _ ->
      firstCommandFailure rest

data DomainLoopOps m = DomainLoopOps
  { loopPrestartAndObserve
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> [WatcherEvent]
      -> StartTurnKind
      -> ThreadId
      -> (TurnId -> DaemonObservation)
      -> m (Either DaemonLoopFailure DaemonLoopTickResult)
  , loopObserveWithExecutor
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> [WatcherEvent]
      -> DaemonObservation
      -> m (Either DaemonLoopFailure DaemonLoopTickResult)
  , loopIdle
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> EventReplayResult
      -> Text
      -> m (Either DaemonLoopFailure DaemonLoopTickResult)
  , loopReadActiveTurn
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> ActiveTurn
      -> m (Either DaemonLoopFailure ActiveTurnReadResult)
  , loopHandleMissingActiveTurn
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> [WatcherEvent]
      -> EventReplayResult
      -> ActiveTurn
      -> m (Either DaemonLoopFailure DaemonLoopTickResult)
  , loopClearActiveTurnMarker
      :: ActionExecutor m
      -> DaemonLoopConfig
      -> m ()
  }

systemErrorTurn :: ActiveTurn -> Text -> AppServerTurn
systemErrorTurn activeTurn status =
  AppServerTurn
    activeTurn.activeTurnId
    "failed"
    (Just ("app-server thread entered systemError: " <> status))

observeClassifiedActiveTurn
  :: Monad m
  => DomainLoopOps m
  -> ActionExecutor m
  -> DaemonLoopConfig
  -> [WatcherEvent]
  -> EventReplayResult
  -> ActiveTurn
  -> (AppServerTurn -> Maybe DaemonObservation)
  -> m (Either DaemonLoopFailure DaemonLoopTickResult)
observeClassifiedActiveTurn ops executor config events replay activeTurn classify = do
  turnResult <- ops.loopReadActiveTurn executor config activeTurn
  case turnResult of
    Left failure -> pure (Left failure)
    Right readResult ->
      case readResult.activeTurnReadThreadSystemError of
        Just status -> do
          ops.loopClearActiveTurnMarker executor config
          observeClassifiedTurn (systemErrorTurn activeTurn status)
        Nothing ->
          case readResult.activeTurnReadTurn of
            Nothing ->
              ops.loopHandleMissingActiveTurn executor config events replay activeTurn
            Just turn -> do
              ops.loopClearActiveTurnMarker executor config
              observeClassifiedTurn turn
 where
  observeClassifiedTurn turn =
    case classify turn of
      Nothing -> ops.loopIdle executor config replay ("active turn is not finished: " <> unTurnId activeTurn.activeTurnId)
      Just observation -> ops.loopObserveWithExecutor executor config events observation
