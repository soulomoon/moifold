{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Cli
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EffectInterpreter
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.GoldenReplay
import CodexWatcher.Healthcheck
import CodexWatcher.IssueImplementWatcher
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Migration
import CodexWatcher.MigrationRehearsal
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.Runtime
import CodexWatcher.RunnerGuard
import CodexWatcher.Snapshot
import CodexWatcher.Supervisor
import CodexWatcher.Types
import CodexWatcher.TurnOutput
import Control.Concurrent (threadDelay)
import Control.Exception (finally)
import Control.Monad (unless, when)
import Data.Aeson (Value (..), encode)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes)
import Data.Text qualified as Text
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, getCurrentDirectory, listDirectory, removeFile)
import System.Environment (getExecutablePath)
import System.Exit (die, exitFailure)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (IOMode (AppendMode), hFlush, withFile)
import System.Posix.Process (getProcessID)
import System.Process qualified as Process

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

renderService :: RenderServiceCli -> IO ()
renderService options = do
  service <- serviceConfigFromCli options
  putStrLn "# systemd service"
  putStr (Text.unpack (renderSystemdService service))
  putStrLn "# logrotate"
  putStr (Text.unpack (renderLogrotateConfig service))

serviceConfigFromCli :: RenderServiceCli -> IO WatcherServiceConfig
serviceConfigFromCli options = do
  executable <- maybe getExecutablePath pure options.renderServiceCliExecutable
  plannerArgs <-
    case (options.renderServiceCliDomain, options.renderServiceCliPlannerThread) of
      (CliIssuePlanning, Just threadId) -> pure ["--planner-thread-id", Text.unpack (unThreadId threadId)]
      (CliIssuePlanning, Nothing) -> die "render-service for issue-planning requires --planner-thread-id <thread-id>"
      _ -> pure []
  pure (serviceConfigFromCliWithExecutable options executable plannerArgs)

serviceConfigFromCliWithExecutable :: RenderServiceCli -> FilePath -> [String] -> WatcherServiceConfig
serviceConfigFromCliWithExecutable options executable plannerArgs =
  let domain = cliDomainName options.renderServiceCliDomain
      stateDir = options.renderServiceCliStateDir
      endpoint = options.renderServiceCliEndpoint
      pollSeconds = show options.renderServiceCliPollSeconds
      logDir = maybe (stateDir </> "logs") id options.renderServiceCliLogDir
      appServerPathArgs =
        if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]
      implementerArgs =
        maybe [] (\root -> ["--implementers-root", root]) options.renderServiceCliImplementersRoot
      childArgs =
        if options.renderServiceCliStartChildren then ["--start-children"] else []
      commandArgs =
        [ "run-" <> domain
        , "--events"
        , options.renderServiceCliEventsPath
        , "--state-dir"
        , stateDir
        , "--repo"
        , Text.unpack (unRepoName options.renderServiceCliRepo)
        , "--workdir"
        , options.renderServiceCliWorkdir
        , "--app-server-host"
        , endpoint.appServerHost
        , "--app-server-port"
        , show endpoint.appServerPort
        , "--poll-seconds"
        , pollSeconds
        , "--execute"
        , "--loop"
        ]
          <> appServerPathArgs
          <> plannerArgs
          <> implementerArgs
          <> childArgs
   in
    WatcherServiceConfig
      { serviceName = options.renderServiceCliName
      , serviceDescription = "Codex watcher " <> options.renderServiceCliName
      , serviceExecutable = executable
      , serviceArguments = commandArgs
      , serviceWorkingDirectory = options.renderServiceCliWorkdir
      , serviceLogDirectory = logDir
      , serviceRestartSeconds = options.renderServiceCliRestartSeconds
      , serviceLogRotateCount = options.renderServiceCliRotateCount
      }

rehearseMigration :: RehearsalCli -> IO ()
rehearseMigration options = do
  plan <- migrationRehearsalPlanFromCli options
  when options.rehearsalCliExecute $ do
    copyWatcherStateDir plan.rehearsalSourceStateDir plan.rehearsalTargetStateDir
    writeRuntimeOwner ioRuntimeInterpreter plan.rehearsalTargetStateDir HaskellRuntime
    bootstrapRehearsalEventsIfMissing plan
  putStrLn ("source: " <> plan.rehearsalSourceStateDir)
  putStrLn ("target: " <> plan.rehearsalTargetStateDir)
  putStrLn ("mode: " <> if options.rehearsalCliExecute then "copied" else "dry-run")
  replayRehearsalEvents plan.rehearsalEventsPath
  service <- rehearsalServiceConfig options plan
  putStrLn "# systemd service"
  putStr (Text.unpack (renderSystemdService service))
  putStrLn "# logrotate"
  putStr (Text.unpack (renderLogrotateConfig service))
  putStrLn "# backout"
  mapM_ (putStrLn . Text.unpack) (renderBackoutCommands plan.rehearsalTargetStateDir plan.rehearsalDomain)

bootstrapRehearsalEventsIfMissing :: MigrationRehearsalPlan -> IO ()
bootstrapRehearsalEventsIfMissing plan = do
  exists <- doesFileExist plan.rehearsalEventsPath
  unless exists $ do
    loaded <- loadNodeSnapshot plan.rehearsalTargetStateDir
    snapshot <- either die pure loaded
    let events = bootstrapNodeSnapshotEvents snapshot
    createDirectoryIfMissing True (takeDirectory plan.rehearsalEventsPath)
    mapM_ (appendWatcherEvent ioRuntimeInterpreter plan.rehearsalEventsPath) events
    putStrLn ("bootstrapped event replay log: " <> plan.rehearsalEventsPath <> " (" <> show (length events) <> " events)")

migrationRehearsalPlanFromCli :: RehearsalCli -> IO MigrationRehearsalPlan
migrationRehearsalPlanFromCli options = do
  targetStateDir <-
    case options.rehearsalCliTargetStateDir of
      Just target -> pure target
      Nothing -> do
        root <- maybe (die "rehearse-migration requires --rehearsal-root <path> or --target-state-dir <path>") pure options.rehearsalCliRehearsalRoot
        pure (defaultRehearsalTarget root options.rehearsalCliSourceStateDir)
  let eventsPath = maybe (targetStateDir </> "events.jsonl") id options.rehearsalCliEventsPath
      serviceName = maybe (Text.pack (takeFileName targetStateDir)) id options.rehearsalCliName
  pure
    MigrationRehearsalPlan
      { rehearsalSourceStateDir = options.rehearsalCliSourceStateDir
      , rehearsalTargetStateDir = targetStateDir
      , rehearsalDomain = cliDomainName options.rehearsalCliDomain
      , rehearsalEventsPath = eventsPath
      , rehearsalServiceName = serviceName
      }

rehearsalServiceConfig :: RehearsalCli -> MigrationRehearsalPlan -> IO WatcherServiceConfig
rehearsalServiceConfig options plan =
  serviceConfigFromCli
    RenderServiceCli
      { renderServiceCliName = plan.rehearsalServiceName
      , renderServiceCliDomain = options.rehearsalCliDomain
      , renderServiceCliEventsPath = plan.rehearsalEventsPath
      , renderServiceCliStateDir = plan.rehearsalTargetStateDir
      , renderServiceCliRepo = options.rehearsalCliRepo
      , renderServiceCliWorkdir = options.rehearsalCliWorkdir
      , renderServiceCliEndpoint = options.rehearsalCliEndpoint
      , renderServiceCliExecutable = options.rehearsalCliExecutable
      , renderServiceCliPlannerThread = options.rehearsalCliPlannerThread
      , renderServiceCliPollSeconds = options.rehearsalCliPollSeconds
      , renderServiceCliLogDir = options.rehearsalCliLogDir
      , renderServiceCliRestartSeconds = options.rehearsalCliRestartSeconds
      , renderServiceCliRotateCount = options.rehearsalCliRotateCount
      , renderServiceCliImplementersRoot = options.rehearsalCliImplementersRoot
      , renderServiceCliStartChildren = options.rehearsalCliStartChildren
      }

copyWatcherStateDir :: FilePath -> FilePath -> IO ()
copyWatcherStateDir source target = do
  sourceExists <- doesDirectoryExist source
  unless sourceExists $
    die ("source watcher state directory does not exist: " <> source)
  targetDirectoryExists <- doesDirectoryExist target
  targetFileExists <- doesFileExist target
  when (targetDirectoryExists || targetFileExists) $
    die ("refusing to overwrite existing rehearsal target: " <> target)
  createDirectoryIfMissing True target
  copyStateContents source target

copyStateContents :: FilePath -> FilePath -> IO ()
copyStateContents source target = do
  entries <- listDirectory source
  mapM_ copyStateEntry entries
 where
  copyStateEntry entry =
    when (shouldCopyStateEntry entry) $ do
      let sourcePath = source </> entry
          targetPath = target </> entry
      isDirectory <- doesDirectoryExist sourcePath
      isFile <- doesFileExist sourcePath
      if isDirectory
        then createDirectoryIfMissing True targetPath >> copyStateContents sourcePath targetPath
        else when isFile (copyFile sourcePath targetPath)

replayRehearsalEvents :: FilePath -> IO ()
replayRehearsalEvents eventsPath = do
  exists <- doesFileExist eventsPath
  if not exists
    then putStrLn ("event replay: skipped, missing " <> eventsPath)
    else do
      loaded <- loadEventLogFile eventsPath
      events <- either die pure loaded
      replay <- either (die . formatReplayFailure) pure (replayEventLog events)
      putStrLn ("event replay domain: " <> show (someDomain replay.replayState))
      putStrLn ("event replay phase: " <> show (somePhase replay.replayState))
      putStrLn ("event replay events: " <> show (length events))

validateMigration :: ValidateMigrationCli -> IO ()
validateMigration options = do
  sourceOwner <- loadOwnerForReadiness "source" options.validateMigrationCliSourceStateDir
  targetOwner <- loadOwnerForReadiness "target" options.validateMigrationCliTargetStateDir
  (replayProblem, replayDomain) <- loadReplayForReadiness eventsPath
  targetPidExists <- doesFileExist (options.validateMigrationCliTargetStateDir </> pidFileNameForDomain options.validateMigrationCliDomain)
  let ownerProblems = sourceOwner.ownerProblem <> targetOwner.ownerProblem
      report =
        migrationReadinessReport
          options.validateMigrationCliTargetStateDir
          (cliDomainName options.validateMigrationCliDomain)
          MigrationReadinessInput
            { readinessSourceOwner = sourceOwner.ownerValue
            , readinessTargetOwner = targetOwner.ownerValue
            , readinessOwnerProblems = ownerProblems
            , readinessReplayDomain = replayDomain
            , readinessExpectedDomain = cliDomainToDomain options.validateMigrationCliDomain
            , readinessReplayProblem = replayProblem
            , readinessTargetPidExists = targetPidExists
            }
  printMigrationReadinessReport report
  unless report.migrationReady exitFailure
 where
  eventsPath =
    maybe (options.validateMigrationCliTargetStateDir </> "events.jsonl") id options.validateMigrationCliEventsPath

data OwnerReadiness = OwnerReadiness
  { ownerValue :: Maybe RuntimeOwner
  , ownerProblem :: [Text.Text]
  }

loadOwnerForReadiness :: Text.Text -> FilePath -> IO OwnerReadiness
loadOwnerForReadiness label stateDir = do
  ownerResult <- readRuntimeOwner stateDir
  pure case ownerResult of
    Right owner ->
      OwnerReadiness owner []
    Left problem ->
      OwnerReadiness Nothing [label <> " runtime-owner.json is invalid: " <> problem]

loadReplayForReadiness :: FilePath -> IO (Maybe Text.Text, Maybe Domain)
loadReplayForReadiness eventsPath = do
  exists <- doesFileExist eventsPath
  if not exists
    then pure (Just ("missing " <> Text.pack eventsPath), Nothing)
    else do
      loaded <- loadEventLogFile eventsPath
      case loaded of
        Left problem ->
          pure (Just (Text.pack problem), Nothing)
        Right events ->
          case replayEventLog events of
            Left failure ->
              pure (Just (Text.pack (formatReplayFailure failure)), Nothing)
            Right replay ->
              pure (Nothing, Just (someDomain replay.replayState))

printMigrationReadinessReport :: MigrationReadinessReport -> IO ()
printMigrationReadinessReport report = do
  putStrLn ("ready: " <> if report.migrationReady then "true" else "false")
  putStrLn "problems:"
  if null report.migrationProblems
    then putStrLn "- none"
    else mapM_ (putStrLn . ("- " <>) . Text.unpack) report.migrationProblems
  putStrLn "backout:"
  mapM_ (putStrLn . Text.unpack) report.migrationBackout

issueFanout :: IssueFanoutCli -> IO ()
issueFanout options = do
  openIssues <- resolveFanoutOpenIssues options.issueFanoutCliOpenIssues options.issueFanoutCliRepo
  activeIssues <- resolveFanoutActiveIssues options.issueFanoutCliActiveIssues options.issueFanoutCliRepo options.issueFanoutCliImplementersRoot
  let executionMode = if options.issueFanoutCliExecute then ExecuteActions else DryRunActions
      maybeEndpoint = options.issueFanoutCliEndpoint
  childLaunch <-
    issueImplementerChildLaunchMode
      options.issueFanoutCliStartChildren
      options.issueFanoutCliPollSeconds
      options.issueFanoutCliChildPollSeconds
      executionMode
      maybeEndpoint
  let fanoutConfig =
        (defaultIssuePlanningFanoutConfig options.issueFanoutCliImplementersRoot)
          { fanoutWorkdirRoot = options.issueFanoutCliWorkdirRoot
          , fanoutBranchPrefix = options.issueFanoutCliBranchPrefix
          , fanoutThreadPrefix = options.issueFanoutCliThreadPrefix
          }
      plannerConfig = PlannerConfig options.issueFanoutCliRepo options.issueFanoutCliMaxParallel
      launches = planIssueImplementerLaunches fanoutConfig plannerConfig activeIssues openIssues
      launchEndpoint =
        case executionMode of
          ExecuteActions -> maybeEndpoint
          DryRunActions -> Nothing
  runIssueImplementerLaunches executionMode launchEndpoint childLaunch launches
  putStrLn ("launches: " <> show (length launches))

resolveFanoutOpenIssues :: Maybe [IssueNumber] -> RepoName -> IO [IssueNumber]
resolveFanoutOpenIssues maybeIssues repo =
  case maybeIssues of
    Just issues -> pure issues
    Nothing -> do
      issueResult <- runGhIssueListOpen ioRuntimeInterpreter repo
      case issueResult of
        Left errorMessage -> die ("failed to discover open issues: " <> Text.unpack errorMessage)
        Right issues -> pure (fmap ghIssueNumber issues)

resolveFanoutActiveIssues :: Maybe [IssueNumber] -> RepoName -> FilePath -> IO [IssueNumber]
resolveFanoutActiveIssues maybeIssues repo implementersRoot =
  case maybeIssues of
    Just issues -> pure issues
    Nothing -> discoverActiveIssueImplementers repo implementersRoot

discoverActiveIssueImplementers :: RepoName -> FilePath -> IO [IssueNumber]
discoverActiveIssueImplementers repo implementersRoot = do
  exists <- doesDirectoryExist implementersRoot
  if not exists
    then pure []
    else do
      children <- listDirectory implementersRoot
      issues <- traverse (loadIssueImplementerConfigIssue repo . (implementersRoot </>)) children
      pure (nub (sortOn unIssueNumber (catMaybes issues)))

loadIssueImplementerConfigIssue :: RepoName -> FilePath -> IO (Maybe IssueNumber)
loadIssueImplementerConfigIssue repo stateDir = do
  let configPath = stateDir </> "config.json"
  exists <- doesFileExist configPath
  if not exists
    then pure Nothing
    else do
      loaded <- readJsonValue configPath
      case loaded >>= parseIssueImplementerConfigIssue of
        Left errorMessage -> die ("failed to read issue implementer config " <> configPath <> ": " <> Text.unpack errorMessage)
        Right (configRepo, issue)
          | configRepo == repo -> pure (Just issue)
          | otherwise -> pure Nothing

data IssueImplementerChildLaunch
  = DoNotLaunchChildren
  | PrintChildLaunchCommands AppServerEndpoint Int
  | StartChildLaunches AppServerEndpoint Int

issueImplementerChildLaunchMode :: Bool -> Maybe Int -> Maybe Int -> ActionExecutionMode -> Maybe AppServerEndpoint -> IO IssueImplementerChildLaunch
issueImplementerChildLaunchMode startChildren maybePollSeconds maybeChildPollSeconds executionMode maybeEndpoint
  | not startChildren = pure DoNotLaunchChildren
  | otherwise = do
      endpoint <- maybe (die "--start-children requires --app-server-host and --app-server-port") pure maybeEndpoint
      let pollSeconds = maybe 30 id (firstJust maybeChildPollSeconds maybePollSeconds)
      pure case executionMode of
        DryRunActions -> PrintChildLaunchCommands endpoint pollSeconds
        ExecuteActions -> StartChildLaunches endpoint pollSeconds

runIssueImplementerLaunches :: ActionExecutionMode -> Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> [IssueImplementerLaunchPlan] -> IO ()
runIssueImplementerLaunches DryRunActions _endpoint childLaunch launches = do
  mapM_ printIssueImplementerLaunch launches
  mapM_ (printIssueImplementerChildLaunch childLaunch) launches
runIssueImplementerLaunches ExecuteActions maybeEndpoint childLaunch launches = do
  mapM_ ensureIssueImplementerLaunchWritable launches
  preparedLaunches <- traverse (uncurry (prepareIssueImplementerLaunch maybeEndpoint)) (zip [8000 ..] launches)
  mapM_ writeIssueImplementerLaunch preparedLaunches
  mapM_ (startIssueImplementerChild childLaunch) preparedLaunches

ensureIssueImplementerLaunchWritable :: IssueImplementerLaunchPlan -> IO ()
ensureIssueImplementerLaunchWritable launch = do
  configExists <- doesFileExist launch.launchConfigPath
  eventsExists <- doesFileExist launch.launchEventsPath
  when (configExists || eventsExists) $
    die ("refusing to overwrite existing issue implementer state: " <> launch.launchStateDir)

prepareIssueImplementerLaunch :: Maybe AppServerEndpoint -> Int -> IssueImplementerLaunchPlan -> IO IssueImplementerLaunchPlan
prepareIssueImplementerLaunch Nothing _requestId launch =
  pure launch
prepareIssueImplementerLaunch (Just endpoint) requestId launch = do
  response <-
    sendOneAppServerRequest
      endpoint
      defaultAppServerClientOptions
      (threadStartRequest requestId (issueImplementerThreadStartOptions launch))
  case response >>= parseThreadStartThreadId of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right threadId -> pure (withLaunchThreadId threadId launch)

issueImplementerThreadStartOptions :: IssueImplementerLaunchPlan -> ThreadStartOptions
issueImplementerThreadStartOptions launch =
  ThreadStartOptions
    { threadCwd = maybe "." id launch.launchWorkdir
    , threadApprovalPolicy = "never"
    , threadSandbox = "danger-full-access"
    , threadModel = "gpt-5.4"
    , threadDeveloperInstructions =
        "Issue implementation watcher for "
          <> unRepoName launch.launchIssueConfig.issueRepo
          <> "#"
          <> Text.pack (show (unIssueNumber (launchIssueNumber launch)))
    }

writeIssueImplementerLaunch :: IssueImplementerLaunchPlan -> IO ()
writeIssueImplementerLaunch launch = do
  ensureIssueImplementerLaunchWritable launch
  createDirectoryIfMissing True launch.launchStateDir
  writeJsonValue launch.launchConfigPath launch.launchConfigJson
  appendWatcherEvent ioRuntimeInterpreter launch.launchEventsPath launch.launchInitialEvent
  mapM_ (writeCompatibilityLaunch ioRuntimeInterpreter) launch.launchCompatibilityWrites
  writeRuntimeOwner ioRuntimeInterpreter launch.launchStateDir HaskellRuntime
  putStrLn ("wrote issue implementer " <> show (unIssueNumber (launchIssueNumber launch)) <> " to " <> launch.launchStateDir)

printIssueImplementerLaunch :: IssueImplementerLaunchPlan -> IO ()
printIssueImplementerLaunch launch =
  putStrLn
    ( "issue "
        <> show (unIssueNumber (launchIssueNumber launch))
        <> " -> "
        <> launch.launchStateDir
        <> " thread "
        <> Text.unpack (unThreadId launch.launchThreadId)
    )

writeCompatibilityLaunch :: RuntimeInterpreter IO -> CompatibilityWrite -> IO ()
writeCompatibilityLaunch interpreter write =
  interpreter.runtimeWriteJsonValue write.compatibilityWritePath write.compatibilityWriteValue

printIssueImplementerChildLaunch :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
printIssueImplementerChildLaunch DoNotLaunchChildren _launch =
  pure ()
printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch = do
  executable <- getExecutablePath
  putStrLn ("child command: " <> unwords (executable : issueImplementerChildArgs endpoint pollSeconds launch))
printIssueImplementerChildLaunch StartChildLaunches {} _launch =
  pure ()

startIssueImplementerChild :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
startIssueImplementerChild DoNotLaunchChildren _launch =
  pure ()
startIssueImplementerChild (PrintChildLaunchCommands endpoint pollSeconds) launch =
  printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch
startIssueImplementerChild (StartChildLaunches endpoint pollSeconds) launch = do
  executable <- getExecutablePath
  let stdoutPath = launch.launchStateDir </> "daemon.log"
      stderrPath = launch.launchStateDir </> "daemon.err.log"
      childArgs = issueImplementerChildArgs endpoint pollSeconds launch
  withFile stdoutPath AppendMode \stdoutHandle ->
    withFile stderrPath AppendMode \stderrHandle -> do
      hFlush stdoutHandle
      hFlush stderrHandle
      (_, _, _, processHandle) <-
        Process.createProcess
          (Process.proc executable childArgs)
            { Process.std_out = Process.UseHandle stdoutHandle
            , Process.std_err = Process.UseHandle stderrHandle
            , Process.close_fds = True
            }
      pid <- Process.getPid processHandle
      putStrLn
        ( "started issue implementer "
            <> show (unIssueNumber (launchIssueNumber launch))
            <> " pid "
            <> maybe "unknown" show pid
        )

issueImplementerChildArgs :: AppServerEndpoint -> Int -> IssueImplementerLaunchPlan -> [String]
issueImplementerChildArgs endpoint pollSeconds launch =
  [ "run-issue-implement"
  , "--events"
  , launch.launchEventsPath
  , "--state-dir"
  , launch.launchStateDir
  , "--repo"
  , Text.unpack (unRepoName launch.launchIssueConfig.issueRepo)
  , "--workdir"
  , maybe "." id launch.launchWorkdir
  , "--app-server-host"
  , endpoint.appServerHost
  , "--app-server-port"
  , show endpoint.appServerPort
  , "--poll-seconds"
  , show pollSeconds
  , "--execute"
  , "--loop"
  ]
    <> if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]

launchIssueNumber :: IssueImplementerLaunchPlan -> IssueNumber
launchIssueNumber launch =
  case launch.launchIssueConfig of
    IssueConfig _ issue _ -> issue

observeOnce :: ObserveOnceCli -> IO ()
observeOnce cli = do
  observation <- parseDaemonObservation cli
  executor <- observeOnceExecutor cli
  let executionMode = if cli.observeCliExecute then ExecuteActions else DryRunActions
      options =
        DaemonOptions
          { daemonEventLogPath = cli.observeCliEventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig cli.observeCliRepo cli.observeCliWorkdir cli.observeCliStateDir
          , daemonExecutionMode = executionMode
          }
  validateRuntimeOwnerForExecution cli.observeCliStateDir options.daemonExecutionMode
  result <- runObservedDaemonTickFromFile executor options observation
  case result of
    Left failure -> die (Text.unpack (formatDaemonFailure failure))
    Right tick -> do
      putStrLn ("event: " <> show tick.daemonObservedEvent)
      putStrLn ("phase: " <> show (somePhase tick.daemonObservedState))
      putStrLn ("compatibility writes: " <> show (length tick.daemonObservedCompatibilityWrites))
      putStrLn ("actions: " <> show (length tick.daemonObservedActionReports))
      putStrLn ("mode: " <> show options.daemonExecutionMode)

observeOnceExecutor :: ObserveOnceCli -> IO (ActionExecutor IO)
observeOnceExecutor cli
  | cli.observeCliExecute = do
      endpoint <- maybe (die "--execute requires --app-server-host and --app-server-port") pure cli.observeCliEndpoint
      pure (ioActionExecutor (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions) (pure ()) (pure ()))
  | otherwise =
      pure (ioActionExecutor (AppServerInterpreter (\_ -> pure Null)) (pure ()) (pure ()))

runAutomaticLoop :: LoopCli -> IO ()
runAutomaticLoop cli = do
  stopRequested <- newIORef False
  let domain = cliDomainName cli.loopCliDomain
      endpoint = cli.loopCliEndpoint
      executionMode = if cli.loopCliExecute then ExecuteActions else DryRunActions
      options =
        DaemonOptions
          { daemonEventLogPath = cli.loopCliEventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig cli.loopCliRepo cli.loopCliWorkdir cli.loopCliStateDir
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
      postTick = issuePlanningFanoutAfterTick cli endpoint executionMode
  validateLoopDomain cli.loopCliDomain cli.loopCliPlannerThread
  validateRuntimeOwnerForExecution cli.loopCliStateDir executionMode
  runWithOptionalPidFile maybePidFile (runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations 1)

runIssuePlanningRunnerGuard :: GuardIssuePlanningCli -> IO ()
runIssuePlanningRunnerGuard cli = do
  executable <- getExecutablePath
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
    <> maybe [] (\root -> ["--implementers-root", Text.pack root]) cli.loopCliImplementersRoot
    <> maybe [] (\issues -> ["--open-issues", issueNumbersText issues]) cli.loopCliOpenIssues
    <> maybe [] (\issues -> ["--active-issues", issueNumbersText issues]) cli.loopCliActiveIssues
    <> maybe [] (\root -> ["--implementer-workdir-root", Text.pack root]) cli.loopCliImplementerWorkdirRoot
    <> maybe [] (\root -> ["--workdir-root", Text.pack root]) cli.loopCliWorkdirRoot
    <> ["--branch-prefix", cli.loopCliBranchPrefix, "--thread-prefix", cli.loopCliThreadPrefix]
    <> boolSwitch cli.loopCliStartChildren "--start-children"
    <> maybe [] (\seconds -> ["--child-poll-seconds", Text.pack (show seconds)]) cli.loopCliChildPollSeconds

issueNumbersText :: [IssueNumber] -> Text.Text
issueNumbersText =
  Text.intercalate "," . fmap (Text.pack . show . unIssueNumber)

boolSwitch :: Bool -> Text.Text -> [Text.Text]
boolSwitch enabled switchText =
  [switchText | enabled]

shellWords :: [Text.Text] -> Text.Text
shellWords =
  Text.unwords . fmap shellQuoteText

shellQuoteText :: Text.Text -> Text.Text
shellQuoteText text =
  "'" <> Text.replace "'" "'\"'\"'" text <> "'"

runLoopIterations :: IORef Bool -> ActionExecutor IO -> DaemonLoopConfig -> String -> (DaemonLoopTickResult -> IO ()) -> Bool -> Int -> Int -> IO ()
runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations iteration = do
  result <- runAutomaticDaemonLoopOnceFromFile executor loopConfig
  case result of
    Left failure -> die (Text.unpack (formatDaemonLoopFailure failure))
    Right tick -> do
      validateLoopResultDomain domain tick
      printLoopTick domain iteration tick
      postTick tick
  shouldStop <- readIORef stopRequested
  when (shouldLoop && not shouldStop && iteration < maxIterations) $
    runLoopIterations stopRequested executor loopConfig domain postTick shouldLoop maxIterations (iteration + 1)

issuePlanningFanoutAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO ()
issuePlanningFanoutAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, cli.loopCliImplementersRoot, tick.loopObservedTick) of
    (CliIssuePlanning, Just implementersRoot, Just observedTick)
      | issuePlanningCompletionEvent observedTick.daemonObservedEvent -> do
          plannerConfig <- maybe (die "issue planning fanout requires a planner config in the replay state") pure (plannerConfigFromState tick.loopReplayResult.replayState)
          readyIssues <- resolveFanoutReadyIssues observedTick.daemonObservedEvent
          activeIssues <- resolveFanoutActiveIssues cli.loopCliActiveIssues plannerConfig.plannerRepo implementersRoot
          let fanoutConfig =
                (defaultIssuePlanningFanoutConfig implementersRoot)
                  { fanoutWorkdirRoot = firstJust cli.loopCliImplementerWorkdirRoot cli.loopCliWorkdirRoot
                  , fanoutBranchPrefix = cli.loopCliBranchPrefix
                  , fanoutThreadPrefix = cli.loopCliThreadPrefix
                  }
              launches = planIssueImplementerLaunches fanoutConfig plannerConfig activeIssues readyIssues
              launchEndpoint =
                case executionMode of
                  ExecuteActions -> Just endpoint
                  DryRunActions -> Nothing
          childLaunch <-
            issueImplementerChildLaunchMode
              cli.loopCliStartChildren
              (Just cli.loopCliPollSeconds)
              cli.loopCliChildPollSeconds
              executionMode
              (Just endpoint)
          runIssueImplementerLaunches executionMode launchEndpoint childLaunch launches
          putStrLn ("planner fanout launches: " <> show (length launches))
    _ -> pure ()

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

pidFileNameForDomain :: CliDomain -> FilePath
pidFileNameForDomain CliPrReview = "watcher.pid"
pidFileNameForDomain CliIssueImplement = "issue-watcher.pid"
pidFileNameForDomain CliIssuePlanning = "issue-planning-watcher.pid"

runWithOptionalPidFile :: Maybe FilePath -> IO () -> IO ()
runWithOptionalPidFile Nothing action = action
runWithOptionalPidFile (Just pidPath) action = do
  ensurePidFileAvailable pidPath
  pidText <- Text.pack . show <$> getProcessID
  createDirectoryIfMissing True (takeDirectory pidPath)
  writeFile pidPath (Text.unpack pidText <> "\n")
  action `finally` removeOwnedPidFile pidPath pidText

ensurePidFileAvailable :: FilePath -> IO ()
ensurePidFileAvailable pidPath = do
  exists <- doesFileExist pidPath
  when exists $ do
    pidText <- Text.strip . Text.pack <$> readFile pidPath
    when (not (Text.null pidText)) $ do
      running <- isPidRunning pidText
      when running $
        die ("refusing to start because pid file is already running: " <> pidPath)

removeOwnedPidFile :: FilePath -> Text.Text -> IO ()
removeOwnedPidFile pidPath expectedPid = do
  exists <- doesFileExist pidPath
  when exists $ do
    currentPid <- Text.strip . Text.pack <$> readFile pidPath
    when (currentPid == expectedPid) $
      removeFile pidPath

isPidRunning :: Text.Text -> IO Bool
isPidRunning pidText = do
  report <- runRuntimeCommand (KillZero pidText)
  pure report.ok

validateRuntimeOwnerForExecution :: FilePath -> ActionExecutionMode -> IO ()
validateRuntimeOwnerForExecution stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      ownerResult <- readRuntimeOwner stateDir
      case ownerResult of
        Left errorMessage ->
          die ("runtime owner marker is invalid: " <> Text.unpack errorMessage)
        Right (Just HaskellRuntime) ->
          pure ()
        Right (Just NodeRuntime) ->
          die "refusing to execute because runtime-owner.json is node; mark owner haskell before migration"
        Right Nothing ->
          die "refusing to execute because runtime-owner.json is missing; mark owner haskell before migration"

parseDaemonObservation :: ObserveOnceCli -> IO DaemonObservation
parseDaemonObservation cli =
  case (cli.observeCliDomain, cli.observeCliObservation) of
    (CliIssuePlanning, "turn-started") ->
      DaemonIssuePlanningObservation
        <$> (ObservedPlanningTurnStarted <$> requiredValue "--thread-id" cli.observeCliThreadId <*> requiredValue "--turn-id" cli.observeCliTurnId)
    (CliIssuePlanning, "turn-completed") ->
      pure (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
    (CliIssueImplement, "triage-turn-started") ->
      DaemonIssueImplementObservation . ObservedTriageTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "triage-already-fixed") ->
      pure (DaemonIssueImplementObservation ObservedTriageAlreadyFixed)
    (CliIssueImplement, "triage-needs-implementation") ->
      pure (DaemonIssueImplementObservation ObservedTriageNeedsImplementation)
    (CliIssueImplement, "triage-blocked") ->
      DaemonIssueImplementObservation . ObservedTriageBlocked <$> requiredBlockedReason cli
    (CliIssueImplement, "plan-turn-started") ->
      DaemonIssueImplementObservation . ObservedPlanTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "plan-completed") ->
      pure (DaemonIssueImplementObservation (ObservedPlanCompleted cli.observeCliImplementationTurnId))
    (CliIssueImplement, "pr-created") ->
      DaemonIssueImplementObservation . ObservedPullRequestCreated <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "pr-reused") ->
      DaemonIssueImplementObservation . ObservedPullRequestReused <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "implementation-turn-started") ->
      DaemonIssueImplementObservation . ObservedImplementationTurnStarted <$> requiredValue "--turn-id" cli.observeCliTurnId
    (CliIssueImplement, "implementation-incomplete") ->
      pure (DaemonIssueImplementObservation (ObservedImplementationIncomplete (maybe "incomplete" id cli.observeCliReason)))
    (CliIssueImplement, "implementation-blocked") ->
      DaemonIssueImplementObservation . ObservedImplementationBlocked <$> requiredBlockedReason cli
    (CliIssueImplement, "review-handoff-initialized") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffInitialized <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "review-handoff-started") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffStarted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliIssueImplement, "implementation-completed") ->
      DaemonIssueImplementObservation . ObservedImplementationCompleted <$> requiredValue "--pr-number" cli.observeCliPrNumber
    (CliPrReview, "review-threads") ->
      DaemonPrReviewObservation
        <$> (ObservedReviewThreads <$> reviewThreadsReportFromCli cli <*> requiredValue "--commit-sha" cli.observeCliCommitSha <*> requiredValue "--turn-id" cli.observeCliTurnId)
    (CliPrReview, "worker-completed") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
    (CliPrReview, "worker-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete (maybe "incomplete" id cli.observeCliReason))))
    (CliPrReview, "worker-blocked") ->
      DaemonPrReviewObservation . ObservedWorkerOutcome . WorkerBlocked <$> requiredBlockedReason cli
    (CliPrReview, "reviewer-clean") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerClean <$> requiredCleanReviewEvidence cli
    (CliPrReview, "reviewer-problems") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerProblemsAdded <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    (CliPrReview, "reviewer-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete (maybe "incomplete" id cli.observeCliReason))))
    (CliPrReview, "reviewer-blocked") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerBlocked <$> requiredBlockedReason cli
    (CliPrReview, "merge-completed") ->
      DaemonPrReviewObservation . ObservedMergeCompleted . MergeCommit <$> requiredValue "--merge-commit-sha" cli.observeCliMergeCommitSha
    (CliPrReview, "blocked") ->
      DaemonPrReviewObservation . ObservedPrReviewBlocked <$> requiredBlockedReason cli
    _ ->
      die ("unsupported observe-once domain/observation: " <> cliDomainName cli.observeCliDomain <> "/" <> cli.observeCliObservation)

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig repo workdir stateDir =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = stateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = 1
    , effectRuntimePlannerTurn =
        (turnConfig plannerTurnInput)
          { turnRuntimeCollaborationMode =
              Just
                ( planCollaborationMode
                    "Plan issue decomposition, dependencies, subissue creation, and implementer fanout. Do not edit files in this turn."
                    "gpt-5.4"
                    "xhigh"
                )
          }
    , effectRuntimeWorkerTurn = turnConfig issueWorkerTurnInput
    , effectRuntimeReviewerTurn = turnConfig reviewerTurnInput
    }
 where
  turnConfig input =
    TurnRuntimeConfig
      { turnRuntimeCwd = workdir
      , turnRuntimeModel = "gpt-5.4"
      , turnRuntimeEffort = "xhigh"
      , turnRuntimeApprovalPolicy = "never"
      , turnRuntimeSandboxPolicy = "danger-full-access"
      , turnRuntimeInput = input
      , turnRuntimeOutputSchema = Nothing
      , turnRuntimeCollaborationMode = Nothing
      }

reviewThreadsReportFromCli :: ObserveOnceCli -> IO ReviewThreadsReport
reviewThreadsReportFromCli cli =
  pure
    ReviewThreadsReport
      { reviewThreads = unresolvedThreads
      , unresolvedReviewThreads = unresolvedThreads
      }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False Nothing Nothing Nothing [])
      cli.observeCliReviewThreadIds

requiredCleanReviewEvidence :: ObserveOnceCli -> IO CleanReviewEvidence
requiredCleanReviewEvidence cli =
  CleanReviewEvidence
    <$> requiredValue "--commit-sha" cli.observeCliCommitSha
    <*> pure (maybe "LGTM" id cli.observeCliComment)

requiredBlockedReason :: ObserveOnceCli -> IO BlockedReason
requiredBlockedReason cli =
  BlockedReason <$> requiredValue "--reason" cli.observeCliReason

requiredValue :: String -> Maybe a -> IO a
requiredValue flag =
  maybe (die ("missing required flag " <> flag)) pure

firstJust :: Maybe a -> Maybe a -> Maybe a
firstJust (Just value) _ = Just value
firstJust Nothing fallback = fallback

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

formatReplayFailure :: ReplayFailure -> String
formatReplayFailure failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
