{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoop.IssuePlanningFanout
  ( issuePlanningFanoutAfterTick
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..), ActionExecutor (..))
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.Daemon (DaemonObservedTickResult (..), appendWatcherEvent)
import CodexWatcher.DaemonLoop (DaemonLoopTickResult (..))
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), WatcherEvent (..))
import CodexWatcher.Failure (FailureClass (..), FailureClassification (..), classifyExternalFailureText, failureClassText)
import CodexWatcher.GhGit (remoteIssueIsClosed, runGhIssueView)
import CodexWatcher.Cli.Command.IssueFanout
  ( IssueImplementerChildStartResult (..)
  , issueImplementerChildLaunchMode
  , issueImplementerRuntimeStatus
  , readyIssueStatusFromRuntime
  , resolveFanoutActiveIssues
  , runIssueImplementerLaunchesDetailed
  , startIssueImplementerChildDetailed
  )
import CodexWatcher.Domain.IssuePlanning.Fanout
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Cli.Command.Replay (formatReplayFailure)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Workflow.GitHub.Ids (IssueNumber (..))
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), someDomain, somePhase)
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..), PlanningGraph (..))
import CodexWatcher.Workflow.Moifold.IssuePlanning.Indexed qualified as WorkflowIssuePlanningIndexed
import CodexWatcher.Workflow.Spec (PlannedTransition (plannedEvent))
import CodexWatcher.WatcherRuntimeStatus
import Control.Applicative ((<|>))
import Control.Monad (when)
import Data.Aeson (Value, object, (.=))
import Data.Maybe (mapMaybe)
import Data.Text qualified as Text
import System.Exit (die)

data FanoutValidationResult
  = FanoutValidationPassed
  | FanoutValidationRetry FailureClassification
  | FanoutValidationBlocked BlockedReason FailureClassification
  deriving stock (Eq, Show)

data ReadyIssueReconciliation = ReadyIssueReconciliation
  { reconciledReadyStatuses :: [(IssueNumber, WatcherRuntimeStatus)]
  , reconciledClosedIssues :: [IssueNumber]
  }
  deriving stock (Eq, Show)

issuePlanningFanoutAfterTick :: ActionExecutor IO -> LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
issuePlanningFanoutAfterTick executor cli endpoint executionMode tick =
  case (cli.loopCliDomain, cli.loopCliImplementersRoot) of
    (IssuePlanning, Just implementersRoot) -> do
      completedFromObserved <- maintainObservedPlanningState implementersRoot
      completedFromReplay <- maintainReplayPlanningState implementersRoot
      pure (completedFromObserved || completedFromReplay)
    _ -> pure False
 where
  maintainObservedPlanningState implementersRoot =
    case tick.loopObservedTick of
      Just observedTick
        | issuePlanningCompletionEvent observedTick.daemonObservedEvent -> do
            plannerConfig <- maybe (die "issue planning fanout requires a planner config in the observed state") pure (plannerConfigFromState observedTick.daemonObservedState)
            readyIssues <- resolveFanoutReadyIssues observedTick.daemonObservedEvent
            maintainReadyIssueImplementers executor cli endpoint executionMode implementersRoot observedTick.daemonObservedState plannerConfig readyIssues
      _ -> pure False
  maintainReplayPlanningState implementersRoot =
    case tick.loopReplayResult.replayState of
      SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig graph) ->
        maintainReadyIssueImplementers executor cli endpoint executionMode implementersRoot tick.loopReplayResult.replayState plannerConfig graph.planningReadyIssues
      _ -> pure False

maintainReadyIssueImplementers :: ActionExecutor IO -> LoopCli -> AppServerEndpoint -> ActionExecutionMode -> FilePath -> SomeWatcherState -> PlannerConfig -> [IssueNumber] -> IO Bool
maintainReadyIssueImplementers executor cli endpoint executionMode implementersRoot planningState plannerConfig readyIssues = do
  let fanoutConfig =
        (defaultIssuePlanningFanoutConfig implementersRoot)
          { fanoutWorkdirRoot = cli.loopCliImplementerWorkdirRoot <|> cli.loopCliWorkdirRoot
          , fanoutBranchPrefix = cli.loopCliBranchPrefix
          , fanoutThreadPrefix = cli.loopCliThreadPrefix
          }
  statuses <- traverse (issueImplementerRuntimeStatus fanoutConfig plannerConfig) readyIssues
  reconciliation <- reconcileReadyIssueStatuses plannerConfig (zip readyIssues statuses)
  case reconciliation of
    Left classification -> do
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Warn
            "fanout_reconcile_retry"
            "ready issue fanout reconciliation hit a retryable external failure"
            [ "failureClass" .= failureClassText classification.failureClass
            , "failureReason" .= classification.failureReason
            ]
        )
      putStrLn ("planner fanout will retry: " <> Text.unpack classification.failureReason)
      pure False
    Right reconciled -> maintainReconciledReadyIssues fanoutConfig reconciled
 where
  maintainReconciledReadyIssues fanoutConfig reconciled = do
    activeIssues <- resolveFanoutActiveIssues cli.loopCliActiveIssues plannerConfig.plannerRepo implementersRoot
    let readyStatuses = reconciled.reconciledReadyStatuses
        fanoutPlan =
          planReadyIssueFanout
            fanoutConfig
            plannerConfig
            activeIssues
            (fmap (fmap readyIssueStatusFromRuntime) readyStatuses)
        launches = fanoutPlan.readyIssueLaunches
        launchEndpoint =
          case executionMode of
            ExecuteActions -> Just endpoint
            DryRunActions -> Nothing
        stoppedActiveLaunches = fanoutPlan.readyIssueRestarts
        allReadyIssuesTerminal = fanoutPlan.readyIssuesAllTerminal
        readyIssuesNeedReplanning = readyIssueStatusesNeedReplanning readyStatuses
    validation <- validateReadyIssueFanout plannerConfig (planningGraphFromState planningState) readyStatuses (launches <> stoppedActiveLaunches)
    case validation of
      FanoutValidationBlocked reason classification -> do
        Log.logWatcher
          executor.actionLogger
          ( Log.watcherLog
              Log.Warn
              "fanout_validation_failed"
              "ready issue fanout validation failed"
              [ "reason" .= reason.unBlockedReason
              , "failureClass" .= failureClassText classification.failureClass
              , "failureReason" .= classification.failureReason
              ]
          )
        blockPlanningFanout executionMode cli planningState reason
        pure False
      FanoutValidationRetry classification -> do
        Log.logWatcher
          executor.actionLogger
          ( Log.watcherLog
              Log.Warn
              "fanout_validation_retry"
              "ready issue fanout validation hit a retryable external failure"
              [ "failureClass" .= failureClassText classification.failureClass
              , "failureReason" .= classification.failureReason
              ]
          )
        putStrLn ("planner fanout will retry: " <> Text.unpack classification.failureReason)
        pure False
      FanoutValidationPassed -> do
        Log.logWatcher
          executor.actionLogger
          ( Log.watcherLog
              Log.Info
              "fanout_decision"
              "ready issue fanout decision computed"
              [ "readyIssues" .= fmap unIssueNumber readyIssues
              , "closedReadyIssues" .= fmap unIssueNumber reconciled.reconciledClosedIssues
              , "launches" .= length launches
              , "restarts" .= length stoppedActiveLaunches
              , "allReadyIssuesTerminal" .= allReadyIssuesTerminal
              , "readyIssuesNeedReplanning" .= readyIssuesNeedReplanning
              ]
          )
        childLaunch <-
          issueImplementerChildLaunchMode
            (Just cli.loopCliPollSeconds)
            executionMode
            (Just endpoint)
        launchResults <- runIssueImplementerLaunchesDetailed executionMode launchEndpoint childLaunch launches
        restartResults <- traverse (startIssueImplementerChildDetailed childLaunch) stoppedActiveLaunches
        let childStartProblems = mapMaybe issueImplementerChildStartProblem (launchResults <> restartResults)
        Log.logWatcher
          executor.actionLogger
          ( Log.watcherLog
              Log.Info
              "child_launch_decision"
              "issue implementer child launch decision applied"
              [ "launches" .= length launches
              , "restarts" .= length stoppedActiveLaunches
              , "startProblems" .= length childStartProblems
              ]
          )
        putStrLn ("planner ready issues: " <> show (fmap unIssueNumber readyIssues))
        putStrLn ("planner fanout closed ready issues: " <> show (fmap unIssueNumber reconciled.reconciledClosedIssues))
        putStrLn ("planner fanout launches: " <> show (length launches))
        putStrLn ("planner fanout restarts: " <> show (length stoppedActiveLaunches))
        when (not (null childStartProblems)) do
          Log.logWatcher
            executor.actionLogger
            ( Log.watcherLog
                Log.Warn
                "child_launch_not_ready"
                "issue implementer child did not become ready; planner will keep waiting"
                ["problems" .= fmap childStartProblemJson childStartProblems]
            )
          putStrLn ("planner fanout child start problems: " <> show (length childStartProblems))
        finalStatuses <- traverse (issueImplementerRuntimeStatus fanoutConfig plannerConfig) readyIssues
        finalReconciliation <- reconcileReadyIssueStatuses plannerConfig (zip readyIssues finalStatuses)
        let readyIssuesNeedReplanningAfterLaunch =
              case finalReconciliation of
                Left _classification -> False
                Right finalReconciled ->
                  readyIssueStatusesNeedReplanning finalReconciled.reconciledReadyStatuses
        when (readyIssuesNeedReplanning || readyIssuesNeedReplanningAfterLaunch) $
          markPlanningReadyIssuesFixed executionMode cli planningState
        pure False

reconcileReadyIssueStatuses :: PlannerConfig -> [(IssueNumber, WatcherRuntimeStatus)] -> IO (Either FailureClassification ReadyIssueReconciliation)
reconcileReadyIssueStatuses plannerConfig readyStatuses = do
  remoteResults <- traverse reconcileIssue readyStatuses
  pure case firstRetry remoteResults of
    Just retry -> Left retry
    Nothing ->
      let closedIssues = [issue | Right (issue, _status, True) <- remoteResults]
          observedReadyStatuses = [(issue, status) | Right (issue, status, _closed) <- remoteResults]
       in
      Right
        ReadyIssueReconciliation
          { reconciledReadyStatuses = completeClosedReadyIssueStatuses closedIssues observedReadyStatuses
          , reconciledClosedIssues = closedIssues
          }
 where
  firstRetry [] = Nothing
  firstRetry (Left retry : _rest) = Just retry
  firstRetry (Right _ : rest) = firstRetry rest
  reconcileIssue (issue, status)
    | status == WatcherTerminal TerminalComplete =
        pure (Right (issue, status, False))
    | otherwise = do
        remote <- runGhIssueView ioRuntimeInterpreter plannerConfig.plannerRepo issue
        case remote of
          Left reason -> do
            putStrLn ("planner fanout warning: ready issue #" <> show (unIssueNumber issue) <> " could not be read from GitHub; will retry next tick: " <> Text.unpack reason)
            pure (Left (classifyExternalFailureText reason))
          Right remoteIssue
            | remoteIssueIsClosed remoteIssue ->
                pure (Right (issue, status, True))
            | otherwise ->
                pure (Right (issue, status, False))

issueImplementerChildStartProblem :: IssueImplementerChildStartResult -> Maybe (IssueNumber, Text.Text, WatcherRuntimeStatus)
issueImplementerChildStartProblem = \case
  IssueImplementerChildStartProblem issue detail status ->
    Just (issue, detail, status)
  _ ->
    Nothing

childStartProblemJson :: (IssueNumber, Text.Text, WatcherRuntimeStatus) -> Value
childStartProblemJson (issue, detail, status) =
  object
    [ "issue" .= unIssueNumber issue
    , "detail" .= detail
    , "status" .= show status
    ]

validateReadyIssueFanout :: PlannerConfig -> Maybe PlanningGraph -> [(IssueNumber, WatcherRuntimeStatus)] -> [IssueImplementerLaunchPlan] -> IO FanoutValidationResult
validateReadyIssueFanout plannerConfig maybeGraph readyStatuses launchPlans =
  firstInvalid <$> traverse validateIssue (fmap (\launch -> launch.launchIssueConfig.issueNumber) launchPlans)
 where
  firstInvalid [] = FanoutValidationPassed
  firstInvalid (FanoutValidationPassed : rest) = firstInvalid rest
  firstInvalid (result : _rest) = result
  validateIssue issue
    | not (readyIssueAllowedByPlannerScope plannerConfig maybeGraph issue) =
        pure (blocked ExternalStateMismatch ("ready issue #" <> issueText issue <> " is outside planner scope"))
    | otherwise =
        case lookup issue readyStatuses of
          Just WatcherActiveRunning ->
            pure (blocked ExternalStateMismatch ("ready issue #" <> issueText issue <> " is already active"))
          Just (WatcherTerminal TerminalComplete) ->
            pure (blocked ExternalStateMismatch ("ready issue #" <> issueText issue <> " is already terminal complete"))
          _ ->
            pure FanoutValidationPassed
  blocked failureClass reason =
    FanoutValidationBlocked (BlockedReason reason) (FailureClassification failureClass reason)

planningGraphFromState :: SomeWatcherState -> Maybe PlanningGraph
planningGraphFromState (SomeWatcherState (PlanningWaitingForReadyIssues _config graph)) = Just graph
planningGraphFromState _ = Nothing

issueText :: IssueNumber -> Text.Text
issueText issue =
  Text.pack (show (unIssueNumber issue))

blockPlanningFanout :: ActionExecutionMode -> LoopCli -> SomeWatcherState -> BlockedReason -> IO ()
blockPlanningFanout executionMode cli planningState reason =
  case executionMode of
    DryRunActions -> do
      _projection <- applyBlocked planningState
      putStrLn ("would block planner fanout: " <> Text.unpack reason.unBlockedReason)
    ExecuteActions -> do
      projection <- applyBlocked planningState
      appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath projection.issuePlanningIndexedProjectionPlanned.plannedEvent
      putStrLn ("blocked planner fanout: " <> Text.unpack reason.unBlockedReason)
 where
  applyBlocked state =
    either
      (\failure -> die ("failed to block planner fanout: " <> Text.unpack failure))
      pure
      (WorkflowIssuePlanningIndexed.projectIssuePlanningBlockedWaitingReadyIssuesObservation state reason)

markPlanningReadyIssuesFixed :: ActionExecutionMode -> LoopCli -> SomeWatcherState -> IO ()
markPlanningReadyIssuesFixed executionMode cli planningState =
  case executionMode of
    DryRunActions ->
      applyReadyIssuesFixed planningState \_projection ->
        putStrLn "planner ready issues fixed; would re-enter planning"
    ExecuteActions -> do
      currentState <- loadCurrentPlanningState
      case currentState of
        SomeWatcherState PlanningReady {} ->
          putStrLn "planner ready issues already fixed; skipping stale marker"
        SomeWatcherState PlanningTurnActive {} ->
          putStrLn "planner already re-entered planning; skipping stale ready-issues marker"
        SomeWatcherState PlanningWaitingForReadyIssues {} ->
          applyReadyIssuesFixed currentState \projection -> do
            appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath projection.issuePlanningIndexedProjectionPlanned.plannedEvent
            putStrLn "planner ready issues fixed; re-entering planning"
        other ->
          die
            ( "failed to mark planning ready issues fixed from current state "
                <> show (someDomain other)
                <> "/"
                <> show (somePhase other)
            )
 where
  loadCurrentPlanningState = do
    loaded <- loadEventLogFile cli.loopCliEventsPath
    events <- either die pure loaded
    replay <- either (die . formatReplayFailure) pure (replayEventLog events)
    pure replay.replayState
  applyReadyIssuesFixed state onFixed =
    case WorkflowIssuePlanningIndexed.projectIssuePlanningReadyIssuesFixedObservation state of
      Left reason ->
        die ("failed to mark planning ready issues fixed: " <> Text.unpack reason)
      Right projection ->
        onFixed projection

resolveFanoutReadyIssues :: WatcherEvent -> IO [IssueNumber]
resolveFanoutReadyIssues = \case
  IssuePlanningGraphUpdated graph -> pure graph.planningReadyIssues
  IssuePlanningTurnRetryRequested {} -> pure []
  IssuePlanningTurnCompleted -> pure []
  _ -> pure []
