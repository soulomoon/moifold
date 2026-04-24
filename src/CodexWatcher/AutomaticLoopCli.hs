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
import CodexWatcher.GhGit
import CodexWatcher.IssueFanoutCli
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Logging qualified as Log
import CodexWatcher.PrReviewLaunchCli
import CodexWatcher.ReplayCli (formatReplayFailure)
import CodexWatcher.Runtime (ioRuntimeInterpreter, writeJsonValue)
import CodexWatcher.RuntimeDefaults (defaultThreadStartOptions)
import CodexWatcher.RuntimeOwnerCli (renewRuntimeOwnerForExecution, validateRuntimeOwnerForExecution)
import CodexWatcher.TurnOutput (issueImplementerThreadDeveloperInstructions, prReviewThreadDeveloperInstructions)
import CodexWatcher.Types
import CodexWatcher.WatcherRuntimeStatus
import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import Data.Aeson ((.=))
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Maybe (mapMaybe)
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
      baseLoopConfig =
        DaemonLoopConfig
          { loopDaemonOptions = options
          , loopPlannerThreadId = cli.loopCliPlannerThread
          }
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
  validateLoopDomain cli.loopCliDomain cli.loopCliPlannerThread
  validateRuntimeOwnerForExecution cli.loopCliStateDir executionMode
  logger <- automaticLoopLogger executionMode cli.loopCliStateDir
  let executor =
        ioActionExecutorWithLogger
          logger
          (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions)
          (threadDelay (cli.loopCliPollSeconds * 1000000))
          (writeIORef stopRequested True)
      postTick = automaticLoopAfterTick executor cli endpoint executionMode
  Log.logWatcher
    logger
    ( Log.watcherLog
        Log.Info
        "runtime_lease_validated"
        "runtime owner lease validation succeeded"
        ["stateDir" .= cli.loopCliStateDir]
    )
  runWithOptionalPidFile maybePidFile do
    loopConfig <- refreshStartupThreads executor cli executionMode baseLoopConfig
    runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations 1

automaticLoopLogger :: ActionExecutionMode -> FilePath -> IO (Log.WatcherLogger IO)
automaticLoopLogger DryRunActions _stateDir =
  pure Log.noopWatcherLogger
automaticLoopLogger ExecuteActions stateDir =
  pure (Log.jsonLineWatcherLogger (stateDir </> "watcher.log.jsonl"))

automaticLoopAfterTick :: ActionExecutor IO -> LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
automaticLoopAfterTick executor cli endpoint executionMode tick = do
  issueImplementReviewHandoffAfterTick cli endpoint executionMode tick
  issuePlanningFanoutAfterTick executor cli endpoint executionMode tick

runLoopIterations :: IORef Bool -> ActionExecutor IO -> DaemonLoopConfig -> String -> (DaemonLoopTickResult -> IO Bool) -> Bool -> Int -> Int -> IO ()
runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations iteration = do
  renewRuntimeOwnerForExecution
    loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir
    loopConfig.loopDaemonOptions.daemonExecutionMode
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Debug
        "runtime_lease_renewed"
        "runtime owner lease renewed"
        ["stateDir" .= loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir]
    )
  reconcileLoopCompatibility executor loopConfig
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

reconcileLoopCompatibility :: ActionExecutor IO -> DaemonLoopConfig -> IO ()
reconcileLoopCompatibility executor loopConfig =
  case loopConfig.loopDaemonOptions.daemonExecutionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      loaded <- loadEventLogFile loopConfig.loopDaemonOptions.daemonEventLogPath
      case loaded of
        Left _ -> pure ()
        Right events ->
          case replayEventLog events of
            Left _ -> pure ()
            Right replay ->
              let writes = compatibilityStateWrites loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir replay.replayState
               in do
                    mapM_
                      (writeCompatibility ioRuntimeInterpreter)
                      writes
                    Log.logWatcher
                      executor.actionLogger
                      ( Log.watcherLog
                          Log.Debug
                          "compatibility_reconciled"
                          "compatibility state reconciled from event log"
                          [ "stateDir" .= loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir
                          , "writes" .= length writes
                          ]
                      )

refreshStartupThreads :: ActionExecutor IO -> LoopCli -> ActionExecutionMode -> DaemonLoopConfig -> IO DaemonLoopConfig
refreshStartupThreads _executor cli _executionMode loopConfig
  | cli.loopCliDomain == CliIssuePlanning =
      pure loopConfig
refreshStartupThreads _executor _cli DryRunActions loopConfig =
  pure loopConfig
refreshStartupThreads executor cli ExecuteActions loopConfig = do
  loaded <- loadEventLogFile cli.loopCliEventsPath
  case loaded of
    Left _failure ->
      pure loopConfig
    Right events ->
      case replayEventLog events of
        Left _failure ->
          pure loopConfig
        Right replay ->
          case cli.loopCliDomain of
            CliIssueImplement ->
              refreshIssueImplementThread replay
            CliPrReview ->
              refreshPrReviewThreads replay
            CliIssuePlanning ->
              pure loopConfig
 where
  runtimeConfig = loopConfig.loopDaemonOptions.daemonRuntimeConfig

  refreshIssueImplementThread replay =
    case idleIssueConfig replay.replayState of
      Nothing ->
        pure loopConfig
      Just issueConfig -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
            instructions = issueImplementerThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir issueConfig
        threadId <- startFreshThread executor requestId cli.loopCliWorkdir instructions
        appendStartupThreadRefresh (IssueWorkerThreadRefreshed threadId)
        pure (withNextRequestId (nextRequestId requestId) loopConfig)

  refreshPrReviewThreads replay =
    case idlePrReviewConfig replay.replayState of
      Nothing ->
        pure loopConfig
      Just prConfig -> do
        let requestId = runtimeConfig.effectRuntimeNextRequestId
        workerThread <- startFreshThread executor requestId cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "worker")
        reviewerThread <- startFreshThread executor (nextRequestId requestId) cli.loopCliWorkdir (prReviewThreadDeveloperInstructions cli.loopCliWorkdir cli.loopCliStateDir prConfig "reviewer")
        appendStartupThreadRefresh (PrReviewThreadsRefreshed workerThread reviewerThread)
        pure (withNextRequestId (nextRequestId (nextRequestId requestId)) loopConfig)

  appendStartupThreadRefresh event = do
    events <- either die pure =<< loadEventLogFile cli.loopCliEventsPath
    appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath event
    replay <- either (die . formatReplayFailure) pure (replayEventLog (events <> [event]))
    mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir replay.replayState)

startFreshThread :: ActionExecutor IO -> RequestId -> FilePath -> Text.Text -> IO ThreadId
startFreshThread executor requestId cwd developerInstructions = do
  result <-
    startThreadWithInterpreter
      executor.actionAppServer
      requestId
      (defaultThreadStartOptions cwd developerInstructions)
  case result of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right threadId -> pure threadId

withNextRequestId :: RequestId -> DaemonLoopConfig -> DaemonLoopConfig
withNextRequestId requestId loopConfig =
  loopConfig
    { loopDaemonOptions =
        loopConfig.loopDaemonOptions
          { daemonRuntimeConfig =
              loopConfig.loopDaemonOptions.daemonRuntimeConfig
                { effectRuntimeNextRequestId = requestId
                }
          }
    }

idleIssueConfig :: SomeWatcherState -> Maybe IssueConfig
idleIssueConfig = \case
  SomeWatcherState (IssueReadyToPlan config _prNumber (WorkerIdle _threadId)) -> Just config
  SomeWatcherState (IssuePlanReady config _prNumber (WorkerIdle _threadId)) -> Just config
  SomeWatcherState (IssueImplementationReady config _maybePr (WorkerIdle _threadId)) -> Just config
  _ -> Nothing

idlePrReviewConfig :: SomeWatcherState -> Maybe PrConfig
idlePrReviewConfig = \case
  SomeWatcherState (PrCheckingReviews config (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just config
  SomeWatcherState (PrWaitingForMergeability config _evidence (WorkerIdle _workerThread) (ReviewerIdle _reviewerThread)) -> Just config
  _ -> Nothing

issueImplementReviewHandoffAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO ()
issueImplementReviewHandoffAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, tick.loopObservedTick) of
    (CliIssueImplement, Just observedTick)
      | IssueReviewHandoffStartedEvent prNumber <- observedTick.daemonObservedEvent
      , Just (issueConfig, handoffPr) <- issueWaitingForPrMerge observedTick.daemonObservedState
      , handoffPr == prNumber ->
          ensurePrReviewWatcherOrBlock observedTick.daemonObservedState issueConfig prNumber
      | IssueReviewHandoffStartedEvent prNumber <- observedTick.daemonObservedEvent
      , Just (_issueConfig, handoffPr) <- issueWaitingForPrMerge observedTick.daemonObservedState
      , handoffPr /= prNumber ->
          blockIssueImplementerHandoff
            cli
            observedTick.daemonObservedState
            ( BlockedReason
                ( "PR review handoff PR number mismatch: expected #"
                    <> Text.pack (show (unPrNumber handoffPr))
                    <> ", actual #"
                    <> Text.pack (show (unPrNumber prNumber))
                )
            )
    (CliIssueImplement, _) ->
      case issueWaitingForPrMerge tick.loopReplayResult.replayState of
        Just (issueConfig, prNumber) ->
          ensurePrReviewWatcherOrBlock tick.loopReplayResult.replayState issueConfig prNumber
        Nothing ->
          pure ()
    _ ->
      pure ()
 where
  ensurePrReviewWatcherOrBlock state issueConfig prNumber =
    ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber
      >>= mapM_ (blockIssueImplementerHandoff cli state)

blockIssueImplementerHandoff :: LoopCli -> SomeWatcherState -> BlockedReason -> IO ()
blockIssueImplementerHandoff cli state reason =
  case cli.loopCliExecute of
    False ->
      putStrLn ("would block issue implementer: " <> Text.unpack reason.unBlockedReason)
    True ->
      case issueImplementObserve state (ObservedIssueImplementBlocked reason) of
        Left failure ->
          die ("failed to block issue implementer after PR review handoff: " <> Text.unpack failure)
        Right blockedTick -> do
          appendWatcherEvent ioRuntimeInterpreter cli.loopCliEventsPath blockedTick.issueImplementTickEvent
          mapM_ (writeCompatibility ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir blockedTick.issueImplementTickState)
          putStrLn ("blocked issue implementer: " <> Text.unpack reason.unBlockedReason)

issueWaitingForPrMerge :: SomeWatcherState -> Maybe (IssueConfig, PrNumber)
issueWaitingForPrMerge (SomeWatcherState (IssueWaitingForPrMerge issueConfig prNumber)) =
  Just (issueConfig, prNumber)
issueWaitingForPrMerge _ =
  Nothing

issuePlanningFanoutAfterTick :: ActionExecutor IO -> LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
issuePlanningFanoutAfterTick executor cli endpoint executionMode tick =
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
validateLoopDomain _domain _plannerThread =
  pure ()

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
