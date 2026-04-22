{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.App.Migration
  ( rehearseMigration
  , renderService
  , validateMigration
  ) where

import CodexWatcher.App.Common
import CodexWatcher.AppServerClient
import CodexWatcher.Cli
import CodexWatcher.Daemon
import CodexWatcher.EventLog
import CodexWatcher.GoldenReplay
import CodexWatcher.Migration
import CodexWatcher.MigrationRehearsal
import CodexWatcher.Runtime
import CodexWatcher.Snapshot
import CodexWatcher.Supervisor
import CodexWatcher.Types
import Control.Monad (unless, when)
import Data.Text qualified as Text
import System.Directory (copyFile, createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit (die, exitFailure)
import System.FilePath (takeDirectory, takeFileName, (</>))

renderService :: RenderServiceCli -> IO ()
renderService options = do
  service <- serviceConfigFromCli options
  putStrLn "# systemd service"
  putStr (Text.unpack (renderSystemdService service))
  putStrLn "# logrotate"
  putStr (Text.unpack (renderLogrotateConfig service))

serviceConfigFromCli :: RenderServiceCli -> IO WatcherServiceConfig
serviceConfigFromCli options = do
  executable <- maybe stableExecutablePath pure options.renderServiceCliExecutable
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
