{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.AutomaticLoopCli
  ( runAutomaticLoop
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.ChildDaemon (runWithOptionalPidFile)
import CodexWatcher.Cli
import CodexWatcher.CliPaths (defaultCliPidPath)
import CodexWatcher.CompatibilityRuntime
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.EffectRuntimeCli
import CodexWatcher.EventLog
import CodexWatcher.EventLogRepair (repairFailureBlockStateJson)
import CodexWatcher.IssueFanoutCli
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.PrReviewLaunchCli
import CodexWatcher.ReplayCli (formatReplayFailure)
import CodexWatcher.Runtime (ioRuntimeInterpreter, writeJsonValue)
import CodexWatcher.RuntimeOwnerCli (validateRuntimeOwnerForExecution)
import CodexWatcher.Types
import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Exit (die)
import System.FilePath ((</>))

runAutomaticLoop :: LoopCli -> IO ()
runAutomaticLoop cli = do
  stopRequested <- newIORef False
  let domain = cliDomainName cli.loopCliDomain
      endpoint = cli.loopCliEndpoint
      executionMode = if cli.loopCliExecute then ExecuteActions else DryRunActions
      options =
        DaemonOptions
          { daemonEventLogPath = cli.loopCliEventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfigWithPlannerScope cli.loopCliScopeIssues cli.loopCliRepo cli.loopCliWorkdir cli.loopCliStateDir
          , daemonExecutionMode = executionMode
          }
      loopConfig =
        DaemonLoopConfig
          { loopDaemonOptions = options
          , loopPlannerThreadId = cli.loopCliPlannerThread
          }
      executor =
        ioActionExecutor
          (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions)
          (threadDelay (cli.loopCliPollSeconds * 1000000))
          (writeIORef stopRequested True)
      shouldLoop = cli.loopCliLoop
      maxIterations =
        if shouldLoop
          then maybe maxBound id cli.loopCliIterations
          else 1
      maybePidFile =
        case cli.loopCliPidFile of
          Just pidFile -> Just pidFile
          Nothing
            | shouldLoop -> Just (defaultCliPidPath cli.loopCliDomain cli.loopCliStateDir)
            | otherwise -> Nothing
      postTick = automaticLoopAfterTick cli endpoint executionMode
  validateLoopDomain cli.loopCliDomain cli.loopCliPlannerThread
  validateRuntimeOwnerForExecution cli.loopCliStateDir executionMode
  runWithOptionalPidFile maybePidFile (runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations 1)

automaticLoopAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
automaticLoopAfterTick cli endpoint executionMode tick = do
  issueImplementReviewHandoffAfterTick cli endpoint executionMode tick
  issuePlanningFanoutAfterTick cli endpoint executionMode tick

runLoopIterations :: IORef Bool -> ActionExecutor IO -> DaemonLoopConfig -> String -> (DaemonLoopTickResult -> IO Bool) -> Bool -> Int -> Int -> IO ()
runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations iteration = do
  result <- runAutomaticDaemonLoopOnceFromFile executor loopConfig
  case result of
    Left failure -> do
      recordInvalidReplayBlockState loopConfig failure
      die (Text.unpack (formatDaemonLoopFailure failure))
    Right tick -> do
      validateLoopResultDomain domain tick
      printLoopTick domain iteration tick
      shouldStopAfterTick <- postTick tick
      when shouldStopAfterTick (writeIORef stopRequested True)
  shouldStop <- readIORef stopRequested
  when (shouldLoop && not shouldStop && iteration < maxIterations) $
    runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations (iteration + 1)

recordInvalidReplayBlockState :: DaemonLoopConfig -> DaemonLoopFailure -> IO ()
recordInvalidReplayBlockState loopConfig = \case
  DaemonLoopDaemonFailure (DaemonReplayFailed replayFailure) -> do
    let stateDir = loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir
    createDirectoryIfMissing True stateDir
    writeJsonValue (stateDir </> "block-state.json") (repairFailureBlockStateJson replayFailure)
  _ -> pure ()

issueImplementReviewHandoffAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO ()
issueImplementReviewHandoffAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, tick.loopObservedTick) of
    (CliIssueImplement, Just observedTick)
      | IssueReviewHandoffStartedEvent prNumber <- observedTick.daemonObservedEvent
      , Just (issueConfig, handoffPr) <- issueWaitingForPrMerge observedTick.daemonObservedState
      , handoffPr == prNumber ->
          ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber
    (CliIssueImplement, _) ->
      case issueWaitingForPrMerge tick.loopReplayResult.replayState of
        Just (issueConfig, prNumber) ->
          ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber
        Nothing ->
          pure ()
    _ ->
      pure ()

issueWaitingForPrMerge :: SomeWatcherState -> Maybe (IssueConfig, PrNumber)
issueWaitingForPrMerge (SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber)) =
  Just (issueConfig, prNumber)
issueWaitingForPrMerge _ =
  Nothing

issuePlanningFanoutAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
issuePlanningFanoutAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, cli.loopCliImplementersRoot) of
    (CliIssuePlanning, Just implementersRoot) -> do
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
            maintainReadyIssueImplementers cli endpoint executionMode implementersRoot observedTick.daemonObservedState plannerConfig readyIssues
      _ -> pure False
  maintainReplayPlanningState implementersRoot =
    case tick.loopReplayResult.replayState of
      SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig graph) ->
        maintainReadyIssueImplementers cli endpoint executionMode implementersRoot tick.loopReplayResult.replayState plannerConfig graph.planningReadyIssues
      _ -> pure False

maintainReadyIssueImplementers :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> FilePath -> SomeWatcherState -> PlannerConfig -> [IssueNumber] -> IO Bool
maintainReadyIssueImplementers cli endpoint executionMode implementersRoot planningState plannerConfig readyIssues = do
  let fanoutConfig =
        (defaultIssuePlanningFanoutConfig implementersRoot)
          { fanoutWorkdirRoot = firstJust cli.loopCliImplementerWorkdirRoot cli.loopCliWorkdirRoot
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
  childLaunch <-
    issueImplementerChildLaunchMode
      cli.loopCliStartChildren
      (Just cli.loopCliPollSeconds)
      cli.loopCliChildPollSeconds
      executionMode
      (Just endpoint)
  runIssueImplementerLaunches executionMode launchEndpoint childLaunch launches
  mapM_ (startIssueImplementerChild childLaunch) stoppedActiveLaunches
  putStrLn ("planner ready issues: " <> show (fmap unIssueNumber readyIssues))
  putStrLn ("planner fanout launches: " <> show (length launches))
  putStrLn ("planner fanout restarts: " <> show (length stoppedActiveLaunches))
  if allReadyIssuesTerminal
    then do
      markPlanningReadyIssuesFixed executionMode cli planningState
      pure False
    else pure False

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
  IssuePlanningTurnCompleted -> pure []
  _ -> pure []

printLoopTick :: String -> Int -> DaemonLoopTickResult -> IO ()
printLoopTick domain iteration tick = do
  putStrLn ("domain: " <> domain)
  putStrLn ("iteration: " <> show iteration)
  putStrLn ("phase: " <> show (somePhase tick.loopReplayResult.replayState))
  case tick.loopObservation of
    Nothing ->
      putStrLn ("idle: " <> Text.unpack (maybe "no observation" id tick.loopIdleReason))
    Just observation ->
      putStrLn ("observation: " <> show observation)
  case tick.loopObservedTick of
    Nothing -> pure ()
    Just observed -> do
      putStrLn ("event: " <> show observed.daemonObservedEvent)
      putStrLn ("next phase: " <> show (somePhase observed.daemonObservedState))
      putStrLn ("compatibility writes: " <> show (length observed.daemonObservedCompatibilityWrites))
  putStrLn ("actions: " <> show (length tick.loopActionReports))

validateLoopDomain :: CliDomain -> Maybe ThreadId -> IO ()
validateLoopDomain domain plannerThread = do
  when (domain == CliIssuePlanning && plannerThread == Nothing) $
    die "run-issue-planning requires --planner-thread-id <thread-id>"

validateLoopResultDomain :: String -> DaemonLoopTickResult -> IO ()
validateLoopResultDomain domain tick =
  unless (someDomain tick.loopReplayResult.replayState == expectedLoopDomain domain) $
    die
      ( "event log domain "
          <> show (someDomain tick.loopReplayResult.replayState)
          <> " does not match command domain "
          <> domain
      )

expectedLoopDomain :: String -> Domain
expectedLoopDomain "pr-review" = PrReview
expectedLoopDomain "issue-implement" = IssueImplement
expectedLoopDomain _ = IssuePlanning

firstJust :: Maybe a -> Maybe a -> Maybe a
firstJust (Just value) _ = Just value
firstJust Nothing fallback = fallback
