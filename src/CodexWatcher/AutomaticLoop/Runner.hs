{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.AutomaticLoop.Runner
  ( runAutomaticLoop
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AutomaticLoop.IssuePlanningFanout (issuePlanningFanoutAfterTick)
import CodexWatcher.AutomaticLoop.Output (printLoopTick)
import CodexWatcher.AutomaticLoop.PrReviewHandoff (issueImplementReviewHandoffAfterTick)
import CodexWatcher.AutomaticLoop.StartupThreads (refreshStartupThreads)
import CodexWatcher.ChildDaemon (runWithOptionalPidFile)
import CodexWatcher.Cli.Types (LoopCli (..), cliDomainName)
import CodexWatcher.CliPaths (defaultCliPidPath)
import CodexWatcher.CompatibilityRuntime (writeCompatibility)
import CodexWatcher.CompatibilityState (compatibilityStateWrites)
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter (EffectRuntimeConfig (..))
import CodexWatcher.EffectRuntimeCli (defaultEffectRuntimeConfigWithPlannerScope)
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..))
import CodexWatcher.EventLogRepair (repairFailureBlockStateJson)
import CodexWatcher.Logging qualified as Log
import CodexWatcher.Runtime.File (writeJsonValue)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Owner.Cli (renewRuntimeOwnerForExecution, validateRuntimeOwnerForExecution)
import CodexWatcher.Core.Types
import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import Data.Aeson ((.=))
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Proxy (Proxy (..))
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Exit (die)
import System.FilePath ((</>))

runAutomaticLoop :: LoopCli -> IO ()
runAutomaticLoop cli = do
  stopRequested <- newIORef False
  let endpoint = cli.loopCliEndpoint
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
          (threadDelay (pollSecondsMicros cli.loopCliPollSeconds))
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
    runLoopIterations stopRequested executor loopConfig cli.loopCliDomain postTick shouldLoop maxIterations 1

automaticLoopLogger :: ActionExecutionMode -> FilePath -> IO (Log.WatcherLogger IO)
automaticLoopLogger DryRunActions _stateDir =
  pure Log.noopWatcherLogger
automaticLoopLogger ExecuteActions stateDir =
  pure (Log.jsonLineWatcherLogger (stateDir </> "watcher.log.jsonl"))

automaticLoopAfterTick :: ActionExecutor IO -> LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
automaticLoopAfterTick executor cli endpoint executionMode tick = do
  issueImplementReviewHandoffAfterTick cli endpoint executionMode tick
  issuePlanningFanoutAfterTick executor cli endpoint executionMode tick

runLoopIterations :: IORef Bool -> ActionExecutor IO -> DaemonLoopConfig -> Domain -> (DaemonLoopTickResult -> IO Bool) -> Bool -> Int -> Int -> IO ()
runLoopIterations stopRequested executor loopConfig cliDomain postTick shouldLoop maxIterations iteration = do
  renewRuntimeOwnerForExecution
    (runtimeStateDirPath loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir)
    loopConfig.loopDaemonOptions.daemonExecutionMode
  Log.logWatcher
    executor.actionLogger
    ( Log.watcherLog
        Log.Debug
        "runtime_lease_renewed"
        "runtime owner lease renewed"
        ["stateDir" .= runtimeStateDirPath loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir]
    )
  reconcileLoopCompatibility executor loopConfig
  result <- runAutomaticDaemonLoopOnceFromFile executor loopConfig
  case result of
    Left failure -> do
      recordInvalidReplayBlockState loopConfig failure
      die (Text.unpack (formatDaemonLoopFailure failure))
    Right tick -> do
      validateLoopResultDomain cliDomain tick
      printLoopTick (cliDomainName cliDomain) iteration tick
      shouldStopAfterTick <- postTick tick
      when shouldStopAfterTick (writeIORef stopRequested True)
  shouldStop <- readIORef stopRequested
  when (shouldLoop && not shouldStop && iteration < maxIterations) $
    runLoopIterations stopRequested executor loopConfig cliDomain postTick shouldLoop maxIterations (iteration + 1)

recordInvalidReplayBlockState :: DaemonLoopConfig -> DaemonLoopFailure -> IO ()
recordInvalidReplayBlockState loopConfig = \case
  DaemonLoopDaemonFailure (DaemonReplayFailed replayFailure) -> do
    let stateDir = runtimeStateDirPath loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir
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
              let writes = compatibilityStateWrites (runtimeStateDirPath loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir) replay.replayState
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
                          [ "stateDir" .= runtimeStateDirPath loopConfig.loopDaemonOptions.daemonRuntimeConfig.effectRuntimeStateDir
                          , "writes" .= length writes
                          ]
                      )

validateLoopDomain :: Domain -> Maybe ThreadId -> IO ()
validateLoopDomain _domain _plannerThread =
  pure ()

validateLoopResultDomain :: Domain -> DaemonLoopTickResult -> IO ()
validateLoopResultDomain cliDomain tick =
  withDomain cliDomain \(_ :: Proxy domain) ->
    unless (someDomainIs @domain tick.loopReplayResult.replayState) $
      die
        ( "event log domain "
            <> show (someDomain tick.loopReplayResult.replayState)
            <> " does not match command domain "
            <> cliDomainName cliDomain
        )
