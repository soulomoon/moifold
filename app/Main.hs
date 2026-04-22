{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import CodexWatcher.ActionExecutor
import CodexWatcher.App.Common
import CodexWatcher.App.Fanout
import CodexWatcher.App.Migration
import CodexWatcher.App.Observe
import CodexWatcher.AppServerClient
import CodexWatcher.Cli
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog
import CodexWatcher.EventLogRepair
import CodexWatcher.GoldenReplay
import CodexWatcher.Healthcheck
import CodexWatcher.Migration
import CodexWatcher.Runtime
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.Types
import Control.Concurrent (threadDelay)
import Control.Monad (unless, when)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text qualified as Text
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, getCurrentDirectory, removeFile)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))

main :: IO ()
main =
  execCliCommandParser >>= runCliCommand

runCliCommand :: CliCommand -> IO ()
runCliCommand = \case
  CliReplay dir -> replayAny dir
  CliReplayPrReview dir -> replayPrReview dir
  CliReplayIssueImplement dir -> replayIssueImplement dir
  CliReplayEvents path -> replayEvents path
  CliHealthcheck options -> runHealthcheck (healthcheckOptionsFromCli options)
  CliMarkRuntimeOwner stateDir owner -> markRuntimeOwner stateDir owner
  CliStopDaemon options -> stopDaemon options
  CliRenderService options -> renderService options
  CliRehearseMigration options -> rehearseMigration options
  CliValidateMigration options -> validateMigration options
  CliIssueFanout options -> issueFanout options
  CliObserveOnce options -> observeOnce options
  CliRunLoop options -> runAutomaticLoop options
  CliGuardIssuePlanning options -> runIssuePlanningRunnerGuard options
  CliRepairInvalidState options -> repairInvalidState options

healthcheckOptionsFromCli :: HealthcheckCli -> HealthcheckOptions
healthcheckOptionsFromCli options =
  HealthcheckOptions
    { stateRoot = options.healthcheckCliStateRoot
    , repoFilter = unRepoName <$> options.healthcheckCliRepo
    , appServerEndpoint = options.healthcheckCliEndpoint
    }

markRuntimeOwner :: FilePath -> RuntimeOwner -> IO ()
markRuntimeOwner stateDir owner = do
  writeRuntimeOwner ioRuntimeInterpreter stateDir owner
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText owner) <> " to " <> stateDir)

stopDaemon :: StopDaemonCli -> IO ()
stopDaemon options = do
  pidPath <- stopDaemonPidPath options
  exists <- doesFileExist pidPath
  if not exists
    then putStrLn ("daemon pid file does not exist: " <> pidPath)
    else do
      pidText <- Text.strip . Text.pack <$> readFile pidPath
      when (Text.null pidText) $
        die ("daemon pid file is empty: " <> pidPath)
      running <- isPidRunning pidText
      if not running
        then putStrLn ("daemon is not running for pid file: " <> pidPath)
        else do
          report <- runRuntimeCommand (KillTerm pidText)
          if report.ok
            then putStrLn ("sent TERM to daemon pid " <> Text.unpack pidText)
            else die ("failed to stop daemon: " <> Text.unpack (commandText report))

stopDaemonPidPath :: StopDaemonCli -> IO FilePath
stopDaemonPidPath options =
  case options.stopDaemonCliPidFile of
    Just pidPath -> pure pidPath
    Nothing -> do
      stateDir <- maybe (die "stop-daemon requires --pid-file <path> or --state-dir <path> --domain <domain>") pure options.stopDaemonCliStateDir
      domain <- maybe (die "stop-daemon requires --pid-file <path> or --state-dir <path> --domain <domain>") pure options.stopDaemonCliDomain
      pure (stateDir </> pidFileNameForDomain domain)

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
            | shouldLoop -> Just (cli.loopCliStateDir </> pidFileNameForDomain cli.loopCliDomain)
            | otherwise -> Nothing
      postTick = automaticLoopAfterTick cli endpoint executionMode
  validateLoopDomain cli.loopCliDomain cli.loopCliPlannerThread
  validateRuntimeOwnerForExecution cli.loopCliStateDir executionMode
  runWithOptionalPidFile maybePidFile (runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations 1)

automaticLoopAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
automaticLoopAfterTick cli endpoint executionMode tick = do
  issueImplementReviewHandoffAfterTick cli endpoint executionMode tick
  issuePlanningFanoutAfterTick cli endpoint executionMode tick

runIssuePlanningRunnerGuard :: GuardIssuePlanningCli -> IO ()
runIssuePlanningRunnerGuard cli = do
  executable <- stableExecutablePath
  defaultRepairCwd <- getCurrentDirectory
  let loopCli = cli.guardCliLoop
      guardPidFile = maybe (loopCli.loopCliStateDir </> "runner-guard.pid") id cli.guardCliPidFile
      watcherPidFile = maybe (loopCli.loopCliStateDir </> pidFileNameForDomain CliIssuePlanning) id loopCli.loopCliPidFile
      repairCwd = maybe defaultRepairCwd id cli.guardCliRepairCwd
      guardConfig =
        RunnerGuardConfig
          { guardRepo = loopCli.loopCliRepo
          , guardEventsPath = loopCli.loopCliEventsPath
          , guardStateDir = loopCli.loopCliStateDir
          , guardWatcherPidFile = watcherPidFile
          , guardAppServerEndpoint = loopCli.loopCliEndpoint
          , guardStaleSeconds = cli.guardCliStaleSeconds
          , guardRepairCwd = repairCwd
          , guardRestartWatcherCommand = issuePlanningWatcherStartCommand executable watcherPidFile loopCli
          , guardRestartGuardCommand = issuePlanningGuardStartCommand executable guardPidFile cli
          }
  runWithOptionalPidFile (Just guardPidFile) (runnerGuardLoop guardConfig cli.guardCliPollSeconds)

runnerGuardLoop :: RunnerGuardConfig -> Int -> IO ()
runnerGuardLoop config pollSeconds = do
  checkRunnerGuard config >>= \case
    Nothing -> do
      threadDelay (pollSeconds * 1000000)
      runnerGuardLoop config pollSeconds
    Just guardProblem -> do
      createDirectoryIfMissing True config.guardStateDir
      LazyByteString.writeFile (config.guardStateDir </> "runner-guard-problem.json") (encode guardProblem)
      handleRunnerGuardProblem config pollSeconds guardProblem

handleRunnerGuardProblem :: RunnerGuardConfig -> Int -> RunnerGuardProblem -> IO ()
handleRunnerGuardProblem config pollSeconds guardProblem =
  case guardProblem.runnerGuardProblemAction of
    RestartWatcher -> do
      report <- commandSummary "bash" ["-lc", Text.unpack config.guardRestartWatcherCommand] Nothing
      LazyByteString.writeFile
        (config.guardStateDir </> "runner-guard-restart.json")
        ( encode
            ( object
                [ "problem" .= guardProblem
                , "command" .= config.guardRestartWatcherCommand
                , "report" .= report
                ]
            )
        )
      if report.ok
        then do
          putStrLn "runner guard restarted issue planning watcher"
          threadDelay (pollSeconds * 1000000)
          runnerGuardLoop config pollSeconds
        else do
          let repairProblem =
                RunnerGuardProblem
                  { runnerGuardProblemAction = LaunchRepairThread
                  , runnerGuardProblemSummary = "runner guard failed to restart issue planning watcher"
                  , runnerGuardProblemDetails =
                      guardProblem.runnerGuardProblemSummary
                        : guardProblem.runnerGuardProblemDetails
                          <> [ "restart command: " <> config.guardRestartWatcherCommand
                             , "restart output: " <> commandText report
                             ]
                  }
          launchRunnerGuardRepair config repairProblem
    LaunchRepairThread ->
      launchRunnerGuardRepair config guardProblem

launchRunnerGuardRepair :: RunnerGuardConfig -> RunnerGuardProblem -> IO ()
launchRunnerGuardRepair config guardProblem = do
  repair <- startRunnerGuardRepairThread config guardProblem
  LazyByteString.writeFile (config.guardStateDir </> "runner-guard-repair.json") (encode repair)
  putStrLn ("runner guard launched repair thread " <> Text.unpack (unThreadId repair.runnerGuardRepairThreadId) <> " turn " <> Text.unpack (unTurnId repair.runnerGuardRepairTurnId))

issuePlanningWatcherStartCommand :: FilePath -> FilePath -> LoopCli -> Text.Text
issuePlanningWatcherStartCommand executable watcherPidFile cli =
  "setsid -f "
    <> shellWords (Text.pack executable : "run-issue-planning" : loopCliCommandArgs watcherPidFile cli)
    <> " >> "
    <> shellQuoteText (Text.pack (cli.loopCliStateDir </> "watcher.log"))
    <> " 2>> "
    <> shellQuoteText (Text.pack (cli.loopCliStateDir </> "watcher.err.log"))

issuePlanningGuardStartCommand :: FilePath -> FilePath -> GuardIssuePlanningCli -> Text.Text
issuePlanningGuardStartCommand executable guardPidFile cli =
  "setsid -f "
    <> shellWords (Text.pack executable : "guard-issue-planning" : guardCliCommandArgs guardPidFile cli)
    <> " >> "
    <> shellQuoteText (Text.pack (cli.guardCliLoop.loopCliStateDir </> "runner-guard.log"))
    <> " 2>> "
    <> shellQuoteText (Text.pack (cli.guardCliLoop.loopCliStateDir </> "runner-guard.err.log"))

guardCliCommandArgs :: FilePath -> GuardIssuePlanningCli -> [Text.Text]
guardCliCommandArgs guardPidFile cli =
  loopCliCommandArgs watcherPidFile cli.guardCliLoop
    <> ["--guard-pid-file", Text.pack guardPidFile, "--guard-poll-seconds", Text.pack (show cli.guardCliPollSeconds), "--stale-seconds", Text.pack (show cli.guardCliStaleSeconds)]
    <> maybe [] (\repairCwd -> ["--repair-cwd", Text.pack repairCwd]) cli.guardCliRepairCwd
 where
  watcherPidFile = maybe (cli.guardCliLoop.loopCliStateDir </> pidFileNameForDomain CliIssuePlanning) id cli.guardCliLoop.loopCliPidFile

loopCliCommandArgs :: FilePath -> LoopCli -> [Text.Text]
loopCliCommandArgs watcherPidFile cli =
  [ "--events"
  , Text.pack cli.loopCliEventsPath
  , "--state-dir"
  , Text.pack cli.loopCliStateDir
  , "--repo"
  , unRepoName cli.loopCliRepo
  , "--workdir"
  , Text.pack cli.loopCliWorkdir
  , "--app-server-host"
  , Text.pack cli.loopCliEndpoint.appServerHost
  , "--app-server-port"
  , Text.pack (show cli.loopCliEndpoint.appServerPort)
  , "--app-server-path"
  , Text.pack cli.loopCliEndpoint.appServerPath
  , "--poll-seconds"
  , Text.pack (show cli.loopCliPollSeconds)
  , "--pid-file"
  , Text.pack watcherPidFile
  ]
    <> boolSwitch cli.loopCliExecute "--execute"
    <> boolSwitch cli.loopCliLoop "--loop"
    <> maybe [] (\iterations -> ["--iterations", Text.pack (show iterations)]) cli.loopCliIterations
    <> maybe [] (\threadId -> ["--thread-id", unThreadId threadId]) cli.loopCliPlannerThread
    <> ( case cli.loopCliScopeIssues of
           [] -> []
           issueNumbers -> ["--scope-issues", issueNumbersText issueNumbers]
       )
    <> maybe [] (\root -> ["--implementers-root", Text.pack root]) cli.loopCliImplementersRoot
    <> maybe [] (\issues -> ["--open-issues", issueNumbersText issues]) cli.loopCliOpenIssues
    <> maybe [] (\issues -> ["--active-issues", issueNumbersText issues]) cli.loopCliActiveIssues
    <> maybe [] (\root -> ["--implementer-workdir-root", Text.pack root]) cli.loopCliImplementerWorkdirRoot
    <> maybe [] (\root -> ["--workdir-root", Text.pack root]) cli.loopCliWorkdirRoot
    <> ["--branch-prefix", cli.loopCliBranchPrefix, "--thread-prefix", cli.loopCliThreadPrefix]
    <> boolSwitch cli.loopCliStartChildren "--start-children"
    <> maybe [] (\seconds -> ["--child-poll-seconds", Text.pack (show seconds)]) cli.loopCliChildPollSeconds

boolSwitch :: Bool -> Text.Text -> [Text.Text]
boolSwitch enabled switchText =
  [switchText | enabled]

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
    LazyByteString.writeFile (stateDir </> "block-state.json") (encode (repairFailureBlockStateJson replayFailure))
  _ -> pure ()

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

replayAny :: FilePath -> IO ()
replayAny dir = do
  loaded <- loadNodeSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeSnapshot snapshot)
  printReplay replay

replayPrReview :: FilePath -> IO ()
replayPrReview dir = do
  loaded <- loadNodePrReviewSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodePrReviewSnapshot snapshot)
  printReplay replay

replayIssueImplement :: FilePath -> IO ()
replayIssueImplement dir = do
  loaded <- loadNodeIssueImplementSnapshot dir
  snapshot <- either die pure loaded
  replay <- either (die . Text.unpack) pure (replayNodeIssueImplementSnapshot snapshot)
  printReplay replay

printReplay :: ReplayResult -> IO ()
printReplay replay = do
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  mapM_ (putStrLn . ("warning: " <>) . Text.unpack) replay.replayWarnings

replayEvents :: FilePath -> IO ()
replayEvents path = do
  loaded <- loadEventLogFile path
  events <- either die pure loaded
  replay <- either (die . formatReplayFailure) pure (replayEventLog events)
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  putStrLn ("events: " <> show (length events))
  putStrLn ("effect batches: " <> show (length replay.replayEffects))

repairInvalidState :: RepairInvalidStateCli -> IO ()
repairInvalidState options = do
  loaded <- loadEventLogFile options.repairCliEventsPath
  events <- either die pure loaded
  case replayEventLog events of
    Right replay -> do
      putStrLn "event log is valid; no repair needed"
      putStrLn ("domain: " <> show (someDomain replay.replayState))
      putStrLn ("phase: " <> show (somePhase replay.replayState))
    Left _initialFailure -> do
      plan <- either (die . Text.unpack) pure (repairIssueImplementEventLog events)
      putStrLn ("repair strategy: " <> Text.unpack plan.repairStrategy)
      putStrLn ("failed event index: " <> show plan.repairFailure.eventIndex)
      putStrLn ("inserted events: " <> show (length plan.repairInsertedEvents))
      putStrLn ("dropped events: " <> show (length plan.repairDroppedEvents))
      putStrLn ("repaired phase: " <> show (somePhase plan.repairReplayResult.replayState))
      if options.repairCliExecute
        then do
          archivePath <- archiveEventLog options.repairCliEventsPath
          writeWatcherEventsFile options.repairCliEventsPath plan.repairRepairedEvents
          writeRepairSummary options.repairCliStateDir archivePath plan
          writeCompatibilityFiles options.repairCliStateDir plan.repairReplayResult.replayState
          removeFileIfExists (options.repairCliStateDir </> "block-state.json")
          putStrLn ("archived invalid event log: " <> archivePath)
          putStrLn ("wrote repaired event log: " <> options.repairCliEventsPath)
        else
          putStrLn "dry-run: pass --execute to archive and rewrite events.jsonl"

archiveEventLog :: FilePath -> IO FilePath
archiveEventLog eventsPath = do
  timestamp <- formatTime defaultTimeLocale "%Y%m%dT%H%M%SZ" <$> getCurrentTime
  let archivePath = eventsPath <> ".invalid-" <> timestamp
  copyFile eventsPath archivePath
  pure archivePath

writeWatcherEventsFile :: FilePath -> [WatcherEvent] -> IO ()
writeWatcherEventsFile eventsPath events = do
  createDirectoryIfMissing True (takeDirectory eventsPath)
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

writeRepairSummary :: FilePath -> FilePath -> EventLogRepairPlan -> IO ()
writeRepairSummary stateDir archivePath plan = do
  LazyByteString.writeFile
    (stateDir </> "repair-state.json")
    ( encode
        ( object
            [ "repaired" .= True
            , "strategy" .= plan.repairStrategy
            , "archivePath" .= archivePath
            , "failedEventIndex" .= plan.repairFailure.eventIndex
            , "failedEventType" .= eventName plan.repairFailure.event
            , "failedReason" .= plan.repairFailure.reason
            , "insertedEvents" .= fmap eventName plan.repairInsertedEvents
            , "droppedEvents" .= fmap eventName plan.repairDroppedEvents
            , "finalDomain" .= show (someDomain plan.repairReplayResult.replayState)
            , "finalPhase" .= show (somePhase plan.repairReplayResult.replayState)
            ]
        )
    )

writeCompatibilityFiles :: FilePath -> SomeWatcherState -> IO ()
writeCompatibilityFiles stateDir state =
  mapM_ writeOne (compatibilityStateWrites stateDir state)
 where
  writeOne compatibilityWrite = do
    createDirectoryIfMissing True (takeDirectory compatibilityWrite.compatibilityWritePath)
    LazyByteString.writeFile compatibilityWrite.compatibilityWritePath (encode compatibilityWrite.compatibilityWriteValue)

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = do
  exists <- doesFileExist path
  when exists (removeFile path)
