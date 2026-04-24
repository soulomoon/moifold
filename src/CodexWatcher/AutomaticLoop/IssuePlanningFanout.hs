{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoop.IssuePlanningFanout
  ( issuePlanningFanoutAfterTick
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..), ActionExecutor (..))
import CodexWatcher.AppServerClient (AppServerEndpoint)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.CompatibilityRuntime (writeCompatibility)
import CodexWatcher.CompatibilityState (compatibilityStateWrites)
import CodexWatcher.Daemon (DaemonObservedTickResult (..), appendWatcherEvent)
import CodexWatcher.DaemonLoop (DaemonLoopTickResult (..))
import CodexWatcher.EventLog (EventReplayResult (..), WatcherEvent (..), loadEventLogFile, replayEventLog)
import CodexWatcher.GhGit (remoteIssueIsClosed, runGhIssueView)
import CodexWatcher.IssueFanoutCli
  ( IssueImplementerChildStartResult (..)
  , issueImplementerChildLaunchMode
  , issueImplementerRuntimeStatus
  , readyIssueStatusFromRuntime
  , resolveFanoutActiveIssues
  , runIssueImplementerLaunchesDetailed
  , startIssueImplementerChildDetailed
  )
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher (IssuePlanningObservation (..), IssuePlanningTick (..), issuePlanningObserve)
import CodexWatcher.Logging qualified as Log
import CodexWatcher.ReplayCli (formatReplayFailure)
import CodexWatcher.Runtime (ioRuntimeInterpreter)
import CodexWatcher.Types
import CodexWatcher.WatcherRuntimeStatus
import Control.Applicative ((<|>))
import Control.Monad (when)
import Data.Aeson ((.=))
import Data.Maybe (mapMaybe)
import Data.Text qualified as Text
import System.Exit (die)

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
  activeIssues <- resolveFanoutActiveIssues cli.loopCliActiveIssues plannerConfig.plannerRepo implementersRoot
  let fanoutPlan =
        planReadyIssueFanout
          fanoutConfig
          plannerConfig
          activeIssues
          (zip readyIssues (fmap readyIssueStatusFromRuntime statuses))
      launches = fanoutPlan.readyIssueLaunches
      launchEndpoint =
        case executionMode of
          ExecuteActions -> Just endpoint
          DryRunActions -> Nothing
      stoppedActiveLaunches = fanoutPlan.readyIssueRestarts
      allReadyIssuesTerminal = fanoutPlan.readyIssuesAllTerminal
  validation <- validateReadyIssueFanout plannerConfig (zip readyIssues statuses) (launches <> stoppedActiveLaunches)
  case validation of
    Just reason -> do
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Warn
            "fanout_validation_failed"
            "ready issue fanout validation failed"
            ["reason" .= reason.unBlockedReason]
        )
      blockPlanningFanout executionMode cli planningState reason
      pure False
    Nothing -> do
      Log.logWatcher
        executor.actionLogger
        ( Log.watcherLog
            Log.Info
            "fanout_decision"
            "ready issue fanout decision computed"
            [ "readyIssues" .= fmap unIssueNumber readyIssues
            , "launches" .= length launches
            , "restarts" .= length stoppedActiveLaunches
            , "allReadyIssuesTerminal" .= allReadyIssuesTerminal
            ]
        )
      childLaunch <-
        issueImplementerChildLaunchMode
          cli.loopCliStartChildren
          (Just cli.loopCliPollSeconds)
          cli.loopCliChildPollSeconds
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
      putStrLn ("planner fanout launches: " <> show (length launches))
      putStrLn ("planner fanout restarts: " <> show (length stoppedActiveLaunches))
      case childStartProblems of
        problem : _ -> do
          blockPlanningFanout executionMode cli planningState (childStartBlockedReason problem)
          pure False
        [] -> do
          finalStatuses <- traverse (issueImplementerRuntimeStatus fanoutConfig plannerConfig) readyIssues
          let allReadyIssuesTerminalAfterLaunch =
                not (null readyIssues) && all (== WatcherTerminal TerminalComplete) finalStatuses
          when (allReadyIssuesTerminal || allReadyIssuesTerminalAfterLaunch) $
            markPlanningReadyIssuesFixed executionMode cli planningState
          pure False

issueImplementerChildStartProblem :: IssueImplementerChildStartResult -> Maybe (IssueNumber, Text.Text, WatcherRuntimeStatus)
issueImplementerChildStartProblem = \case
  IssueImplementerChildStartProblem issue detail status ->
    Just (issue, detail, status)
  _ ->
    Nothing

childStartBlockedReason :: (IssueNumber, Text.Text, WatcherRuntimeStatus) -> BlockedReason
childStartBlockedReason (issue, detail, status) =
  BlockedReason
    ( "issue implementer #"
        <> issueText issue
        <> " exited before daemon readiness and is not fixed on GitHub: "
        <> detail
        <> "; status="
        <> Text.pack (show status)
    )

validateReadyIssueFanout :: PlannerConfig -> [(IssueNumber, WatcherRuntimeStatus)] -> [IssueImplementerLaunchPlan] -> IO (Maybe BlockedReason)
validateReadyIssueFanout plannerConfig readyStatuses launchPlans =
  firstInvalid <$> traverse validateIssue (fmap (\launch -> launch.launchIssueConfig.issueNumber) launchPlans)
 where
  firstInvalid = foldr (<|>) Nothing
  validateIssue issue
    | not (null plannerConfig.plannerScopeIssues)
    , issue `notElem` plannerConfig.plannerScopeIssues =
        pure (Just (BlockedReason ("ready issue #" <> issueText issue <> " is outside planner scope")))
    | otherwise =
        case lookup issue readyStatuses of
          Just WatcherActiveRunning ->
            pure (Just (BlockedReason ("ready issue #" <> issueText issue <> " is already active")))
          Just (WatcherTerminal TerminalComplete) ->
            pure (Just (BlockedReason ("ready issue #" <> issueText issue <> " is already terminal complete")))
          _ -> do
            remote <- runGhIssueView ioRuntimeInterpreter plannerConfig.plannerRepo issue
            pure case remote of
              Left reason ->
                Just (BlockedReason ("ready issue #" <> issueText issue <> " could not be read from GitHub: " <> reason))
              Right remoteIssue
                | remoteIssueIsClosed remoteIssue ->
                    Just (BlockedReason ("ready issue #" <> issueText issue <> " is already closed on GitHub"))
                | otherwise ->
                    Nothing

issueText :: IssueNumber -> Text.Text
issueText issue =
  Text.pack (show (unIssueNumber issue))

blockPlanningFanout :: ActionExecutionMode -> LoopCli -> SomeWatcherState -> BlockedReason -> IO ()
blockPlanningFanout executionMode cli planningState reason =
  case executionMode of
    DryRunActions ->
      putStrLn ("would block planner fanout: " <> Text.unpack reason.unBlockedReason)
    ExecuteActions ->
      case issuePlanningObserve planningState (ObservedPlanningBlocked reason) of
        Left failure ->
          die ("failed to block planner fanout: " <> Text.unpack failure)
        Right blockedTick -> do
          appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath blockedTick.issuePlanningTickEvent
          mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir blockedTick.issuePlanningTickState)
          putStrLn ("blocked planner fanout: " <> Text.unpack reason.unBlockedReason)

markPlanningReadyIssuesFixed :: ActionExecutionMode -> LoopCli -> SomeWatcherState -> IO ()
markPlanningReadyIssuesFixed executionMode cli planningState =
  case executionMode of
    DryRunActions ->
      applyReadyIssuesFixed planningState \_fixedTick ->
        putStrLn "planner ready issues fixed; would re-enter planning"
    ExecuteActions -> do
      currentState <- loadCurrentPlanningState
      case currentState of
        SomeWatcherState PlanningReady {} ->
          putStrLn "planner ready issues already fixed; skipping stale marker"
        SomeWatcherState PlanningTurnActive {} ->
          putStrLn "planner already re-entered planning; skipping stale ready-issues marker"
        SomeWatcherState PlanningWaitingForReadyIssues {} ->
          applyReadyIssuesFixed currentState \fixedTick -> do
            appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath fixedTick.issuePlanningTickEvent
            mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir fixedTick.issuePlanningTickState)
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
    case issuePlanningObserve state ObservedPlanningReadyIssuesFixed of
      Left reason ->
        die ("failed to mark planning ready issues fixed: " <> Text.unpack reason)
      Right fixedTick ->
        onFixed fixedTick

resolveFanoutReadyIssues :: WatcherEvent -> IO [IssueNumber]
resolveFanoutReadyIssues = \case
  IssuePlanningGraphUpdated graph -> pure graph.planningReadyIssues
  IssuePlanningTurnRetryRequested {} -> pure []
  IssuePlanningTurnCompleted -> pure []
  _ -> pure []
