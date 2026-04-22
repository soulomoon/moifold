{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main (main) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
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
import CodexWatcher.PrReviewWatcher
import CodexWatcher.Protocol
import CodexWatcher.Runtime
import CodexWatcher.Snapshot
import CodexWatcher.Supervisor
import CodexWatcher.Types
import CodexWatcher.TurnOutput
import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Exception (finally)
import Control.Monad (unless, when)
import Data.Aeson (Value (..))
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, removeFile)
import System.Environment (getArgs, getExecutablePath)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))
import System.IO (IOMode (AppendMode), hFlush, withFile)
import System.Posix.Process (getProcessID)
import System.Process qualified as Process
import Text.Read (readMaybe)

main :: IO ()
main =
  getArgs >>= \case
    ["replay", dir] -> replayAny dir
    ["replay-pr-review", dir] -> replayPrReview dir
    ["replay-issue-implement", dir] -> replayIssueImplement dir
    ["replay-events", path] -> replayEvents path
    "healthcheck" : rest -> runHealthcheck (parseHealthcheckOptions rest)
    "mark-runtime-owner" : rest -> markRuntimeOwner rest
    "stop-daemon" : rest -> stopDaemon rest
    "render-service" : rest -> renderService rest
    "issue-fanout" : rest -> issueFanout rest
    "observe-once" : rest -> observeOnce rest
    "run-pr-review" : rest -> runAutomaticLoop "pr-review" rest
    "run-issue-implement" : rest -> runAutomaticLoop "issue-implement" rest
    "run-issue-planning" : rest -> runAutomaticLoop "issue-planning" rest
    [] -> do
      putStrLn "codex-watcher-hs"
      putStrLn "usage: codex-watcher-hs replay <node-watcher-state-dir>"
      putStrLn "       codex-watcher-hs replay-pr-review <node-pr-review-state-dir>"
      putStrLn "       codex-watcher-hs replay-issue-implement <node-issue-implement-state-dir>"
      putStrLn "       codex-watcher-hs replay-events <events.jsonl>"
      putStrLn "       codex-watcher-hs healthcheck [--state-root <path>] [--repo owner/name] [--app-server-host host --app-server-port port]"
      putStrLn "       codex-watcher-hs mark-runtime-owner --state-dir <path> --owner node|haskell"
      putStrLn "       codex-watcher-hs stop-daemon --pid-file <path> | --state-dir <path> --domain pr-review|issue-implement|issue-planning"
      putStrLn "       codex-watcher-hs render-service --name <name> --domain pr-review|issue-implement|issue-planning --events <events.jsonl> --state-dir <path> --repo owner/name --workdir <path> --app-server-host host --app-server-port port"
      putStrLn "       codex-watcher-hs issue-fanout --repo owner/name --implementers-root <path> --max-parallel N [--open-issues 1,2] [--active-issues 3] [--execute] [--start-children]"
      putStrLn "       codex-watcher-hs observe-once --events <events.jsonl> --state-dir <path> --repo owner/name --domain <domain> --observation <name> [--execute --app-server-host host --app-server-port port]"
      putStrLn "       codex-watcher-hs run-pr-review|run-issue-implement|run-issue-planning --events <events.jsonl> --state-dir <path> --repo owner/name --workdir <path> --app-server-host host --app-server-port port [--execute] [--loop] [--implementers-root <path> --start-children]"
      putStrLn "type-level domains:"
      print [IssuePlanning, IssueImplement, PrReview]
      putStrLn ("example repo newtype is available: " <> Text.unpack (unRepoName (RepoName "soulomoon/mlf2")))
    _ -> die "usage: codex-watcher-hs replay <node-watcher-state-dir> | replay-events <events.jsonl> | healthcheck [--state-root <path>] [--repo owner/name] | mark-runtime-owner --state-dir <path> --owner node|haskell | observe-once --events <events.jsonl> --state-dir <path> --repo owner/name --domain <domain> --observation <name> | run-pr-review|run-issue-implement|run-issue-planning --events <events.jsonl> --state-dir <path> --repo owner/name --workdir <path> --app-server-host host --app-server-port port"

parseHealthcheckOptions :: [String] -> HealthcheckOptions
parseHealthcheckOptions args =
  HealthcheckOptions
    { stateRoot = maybe "/workspace/artifacts" id (lookupFlag "--state-root" args)
    , repoFilter = Text.pack <$> lookupFlag "--repo" args
    , appServerEndpoint = healthcheckAppServerEndpoint args
    }

healthcheckAppServerEndpoint :: [String] -> Maybe AppServerEndpoint
healthcheckAppServerEndpoint args = do
  host <- lookupFlag "--app-server-host" args
  portText <- lookupFlag "--app-server-port" args
  port <- readMaybe portText
  let path = maybe "/" id (lookupFlag "--app-server-path" args)
  pure (AppServerEndpoint host port path)

lookupFlag :: String -> [String] -> Maybe String
lookupFlag _ [] = Nothing
lookupFlag flag (current : value : rest)
  | current == flag = Just value
  | otherwise = lookupFlag flag (value : rest)
lookupFlag _ [_] = Nothing

markRuntimeOwner :: [String] -> IO ()
markRuntimeOwner args = do
  stateDir <- maybe (die "mark-runtime-owner requires --state-dir <path>") pure (lookupFlag "--state-dir" args)
  ownerText <- maybe (die "mark-runtime-owner requires --owner node|haskell") (pure . Text.pack) (lookupFlag "--owner" args)
  owner <- either (die . Text.unpack) pure (parseRuntimeOwner ownerText)
  writeRuntimeOwner ioRuntimeInterpreter stateDir owner
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText owner) <> " to " <> stateDir)

stopDaemon :: [String] -> IO ()
stopDaemon args = do
  pidPath <- stopDaemonPidPath args
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

stopDaemonPidPath :: [String] -> IO FilePath
stopDaemonPidPath args =
  case lookupFlag "--pid-file" args of
    Just pidPath -> pure pidPath
    Nothing -> do
      stateDir <- requiredFlag "--state-dir" args
      domain <- requiredFlag "--domain" args
      unless (domain `elem` ["pr-review", "issue-implement", "issue-planning"]) $
        die ("unsupported daemon domain: " <> domain)
      pure (stateDir </> pidFileNameForDomain domain)

renderService :: [String] -> IO ()
renderService args = do
  service <- serviceConfigFromArgs args
  putStrLn "# systemd service"
  putStr (Text.unpack (renderSystemdService service))
  putStrLn "# logrotate"
  putStr (Text.unpack (renderLogrotateConfig service))

serviceConfigFromArgs :: [String] -> IO WatcherServiceConfig
serviceConfigFromArgs args = do
  name <- Text.pack <$> requiredFlag "--name" args
  domain <- requiredFlag "--domain" args
  unless (domain `elem` ["pr-review", "issue-implement", "issue-planning"]) $
    die ("unsupported daemon domain: " <> domain)
  eventsPath <- requiredFlag "--events" args
  stateDir <- requiredFlag "--state-dir" args
  repo <- requiredFlag "--repo" args
  workdir <- requiredFlag "--workdir" args
  host <- requiredFlag "--app-server-host" args
  port <- requiredFlag "--app-server-port" args
  executable <- maybe getExecutablePath pure (lookupFlag "--executable" args)
  plannerArgs <-
    case (domain, lookupFlag "--planner-thread-id" args <|> lookupFlag "--thread-id" args) of
      ("issue-planning", Just threadId) -> pure ["--planner-thread-id", threadId]
      ("issue-planning", Nothing) -> die "render-service for issue-planning requires --planner-thread-id <thread-id>"
      _ -> pure []
  let pollSeconds = maybe "30" id (lookupFlag "--poll-seconds" args)
      logDir = maybe (stateDir </> "logs") id (lookupFlag "--log-dir" args)
      restartSeconds = maybe 10 id (lookupFlag "--restart-seconds" args >>= readMaybe)
      rotateCount = maybe 14 id (lookupFlag "--rotate" args >>= readMaybe)
      appServerPathArgs =
        maybe [] (\path -> ["--app-server-path", path]) (lookupFlag "--app-server-path" args)
      implementerArgs =
        maybe [] (\root -> ["--implementers-root", root]) (lookupFlag "--implementers-root" args)
      childArgs =
        if hasFlag "--start-children" args then ["--start-children"] else []
      commandArgs =
        [ "run-" <> domain
        , "--events"
        , eventsPath
        , "--state-dir"
        , stateDir
        , "--repo"
        , repo
        , "--workdir"
        , workdir
        , "--app-server-host"
        , host
        , "--app-server-port"
        , port
        , "--poll-seconds"
        , pollSeconds
        , "--execute"
        , "--loop"
        ]
          <> appServerPathArgs
          <> plannerArgs
          <> implementerArgs
          <> childArgs
  pure
    WatcherServiceConfig
      { serviceName = name
      , serviceDescription = "Codex watcher " <> name
      , serviceExecutable = executable
      , serviceArguments = commandArgs
      , serviceWorkingDirectory = workdir
      , serviceLogDirectory = logDir
      , serviceRestartSeconds = restartSeconds
      , serviceLogRotateCount = rotateCount
      }

issueFanout :: [String] -> IO ()
issueFanout args = do
  repo <- RepoName . Text.pack <$> requiredFlag "--repo" args
  implementersRoot <- requiredFlag "--implementers-root" args
  maxParallel <- requiredIntFlag "--max-parallel" args
  openIssues <- resolveFanoutOpenIssues args repo
  activeIssues <- resolveFanoutActiveIssues args repo implementersRoot
  let executionMode = if hasFlag "--execute" args then ExecuteActions else DryRunActions
      maybeEndpoint = healthcheckAppServerEndpoint args
  childLaunch <- issueImplementerChildLaunchMode args executionMode maybeEndpoint
  let fanoutConfig =
        (defaultIssuePlanningFanoutConfig implementersRoot)
          { fanoutWorkdirRoot = lookupFlag "--workdir-root" args
          , fanoutBranchPrefix = Text.pack (maybe "codex/issue-" id (lookupFlag "--branch-prefix" args))
          , fanoutThreadPrefix = Text.pack (maybe "issue-worker-" id (lookupFlag "--thread-prefix" args))
          }
      plannerConfig = PlannerConfig repo maxParallel
      launches = planIssueImplementerLaunches fanoutConfig plannerConfig activeIssues openIssues
      launchEndpoint =
        case executionMode of
          ExecuteActions -> maybeEndpoint
          DryRunActions -> Nothing
  runIssueImplementerLaunches executionMode launchEndpoint childLaunch launches
  putStrLn ("launches: " <> show (length launches))

resolveFanoutOpenIssues :: [String] -> RepoName -> IO [IssueNumber]
resolveFanoutOpenIssues args repo =
  case lookupFlag "--open-issues" args of
    Just value -> parseIssueNumbers "--open-issues" value
    Nothing -> do
      issueResult <- runGhIssueListOpen ioRuntimeInterpreter repo
      case issueResult of
        Left errorMessage -> die ("failed to discover open issues: " <> Text.unpack errorMessage)
        Right issues -> pure (fmap ghIssueNumber issues)

resolveFanoutActiveIssues :: [String] -> RepoName -> FilePath -> IO [IssueNumber]
resolveFanoutActiveIssues args repo implementersRoot =
  case lookupFlag "--active-issues" args of
    Just value -> parseIssueNumbers "--active-issues" value
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

issueImplementerChildLaunchMode :: [String] -> ActionExecutionMode -> Maybe AppServerEndpoint -> IO IssueImplementerChildLaunch
issueImplementerChildLaunchMode args executionMode maybeEndpoint
  | not (hasFlag "--start-children" args) = pure DoNotLaunchChildren
  | otherwise = do
      endpoint <- maybe (die "--start-children requires --app-server-host and --app-server-port") pure maybeEndpoint
      let pollSeconds = maybe 30 id (lookupFlag "--child-poll-seconds" args <|> lookupFlag "--poll-seconds" args >>= readMaybe)
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

observeOnce :: [String] -> IO ()
observeOnce args = do
  eventsPath <- requiredFlag "--events" args
  stateDir <- requiredFlag "--state-dir" args
  repo <- RepoName . Text.pack <$> requiredFlag "--repo" args
  observation <- parseDaemonObservation args
  executor <- observeOnceExecutor args
  let workdir = maybe "." id (lookupFlag "--workdir" args)
      options =
        DaemonOptions
          { daemonEventLogPath = eventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig repo workdir stateDir
          , daemonExecutionMode = if hasFlag "--execute" args then ExecuteActions else DryRunActions
          }
  validateRuntimeOwnerForExecution stateDir options.daemonExecutionMode
  result <- runObservedDaemonTickFromFile executor options observation
  case result of
    Left failure -> die (Text.unpack (formatDaemonFailure failure))
    Right tick -> do
      putStrLn ("event: " <> show tick.daemonObservedEvent)
      putStrLn ("phase: " <> show (somePhase tick.daemonObservedState))
      putStrLn ("compatibility writes: " <> show (length tick.daemonObservedCompatibilityWrites))
      putStrLn ("actions: " <> show (length tick.daemonObservedActionReports))
      putStrLn ("mode: " <> show options.daemonExecutionMode)

observeOnceExecutor :: [String] -> IO (ActionExecutor IO)
observeOnceExecutor args
  | hasFlag "--execute" args = do
      host <- requiredFlag "--app-server-host" args
      port <- requiredIntFlag "--app-server-port" args
      let path = maybe "/" id (lookupFlag "--app-server-path" args)
          endpoint = AppServerEndpoint host port path
      pure (ioActionExecutor (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions) (pure ()) (pure ()))
  | otherwise =
      pure (ioActionExecutor (AppServerInterpreter (\_ -> pure Null)) (pure ()) (pure ()))

runAutomaticLoop :: String -> [String] -> IO ()
runAutomaticLoop domain args = do
  eventsPath <- requiredFlag "--events" args
  stateDir <- requiredFlag "--state-dir" args
  repo <- RepoName . Text.pack <$> requiredFlag "--repo" args
  host <- requiredFlag "--app-server-host" args
  port <- requiredIntFlag "--app-server-port" args
  let workdir = maybe "." id (lookupFlag "--workdir" args)
      path = maybe "/" id (lookupFlag "--app-server-path" args)
      endpoint = AppServerEndpoint host port path
      pollSeconds = maybe 30 id (lookupFlag "--poll-seconds" args >>= readMaybe)
      executionMode = if hasFlag "--execute" args then ExecuteActions else DryRunActions
      options =
        DaemonOptions
          { daemonEventLogPath = eventsPath
          , daemonRuntimeConfig = defaultEffectRuntimeConfig repo workdir stateDir
          , daemonExecutionMode = executionMode
          }
      plannerThread =
        case lookupFlag "--planner-thread-id" args <|> lookupFlag "--thread-id" args of
          Nothing -> Nothing
          Just value -> Just (ThreadId (Text.pack value))
      loopConfig =
        DaemonLoopConfig
          { loopDaemonOptions = options
          , loopPlannerThreadId = plannerThread
          }
      executor =
        ioActionExecutor
          (appServerInterpreterFromEndpoint endpoint defaultAppServerClientOptions)
          (threadDelay (pollSeconds * 1000000))
          (pure ())
      shouldLoop = hasFlag "--loop" args
      maxIterations =
        if shouldLoop
          then maybe maxBound id (lookupFlag "--iterations" args >>= readMaybe)
          else 1
      maybePidFile =
        lookupFlag "--pid-file" args
          <|> if shouldLoop then Just (stateDir </> pidFileNameForDomain domain) else Nothing
      postTick = issuePlanningFanoutAfterTick args endpoint executionMode domain
  validateLoopDomain domain plannerThread
  validateRuntimeOwnerForExecution stateDir executionMode
  runWithOptionalPidFile maybePidFile (runLoopIterations executor loopConfig domain postTick shouldLoop maxIterations 1)

runLoopIterations :: ActionExecutor IO -> DaemonLoopConfig -> String -> (DaemonLoopTickResult -> IO ()) -> Bool -> Int -> Int -> IO ()
runLoopIterations executor loopConfig domain postTick shouldLoop maxIterations iteration = do
  result <- runAutomaticDaemonLoopOnceFromFile executor loopConfig
  case result of
    Left failure -> die (Text.unpack (formatDaemonLoopFailure failure))
    Right tick -> do
      validateLoopResultDomain domain tick
      printLoopTick domain iteration tick
      postTick tick
  when (shouldLoop && iteration < maxIterations) $
    runLoopIterations executor loopConfig domain postTick shouldLoop maxIterations (iteration + 1)

issuePlanningFanoutAfterTick :: [String] -> AppServerEndpoint -> ActionExecutionMode -> String -> DaemonLoopTickResult -> IO ()
issuePlanningFanoutAfterTick args endpoint executionMode domain tick =
  case (domain, lookupFlag "--implementers-root" args, tick.loopObservedTick) of
    ("issue-planning", Just implementersRoot, Just observedTick)
      | issuePlanningCompletionEvent observedTick.daemonObservedEvent -> do
          plannerConfig <- maybe (die "issue planning fanout requires a planner config in the replay state") pure (plannerConfigFromState tick.loopReplayResult.replayState)
          openIssues <- resolveFanoutOpenIssues args plannerConfig.plannerRepo
          activeIssues <- resolveFanoutActiveIssues args plannerConfig.plannerRepo implementersRoot
          let fanoutConfig =
                (defaultIssuePlanningFanoutConfig implementersRoot)
                  { fanoutWorkdirRoot = lookupFlag "--implementer-workdir-root" args <|> lookupFlag "--workdir-root" args
                  , fanoutBranchPrefix = Text.pack (maybe "codex/issue-" id (lookupFlag "--branch-prefix" args))
                  , fanoutThreadPrefix = Text.pack (maybe "issue-worker-" id (lookupFlag "--thread-prefix" args))
                  }
              launches = planIssueImplementerLaunches fanoutConfig plannerConfig activeIssues openIssues
              launchEndpoint =
                case executionMode of
                  ExecuteActions -> Just endpoint
                  DryRunActions -> Nothing
          childLaunch <- issueImplementerChildLaunchMode args executionMode (Just endpoint)
          runIssueImplementerLaunches executionMode launchEndpoint childLaunch launches
          putStrLn ("planner fanout launches: " <> show (length launches))
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

validateLoopDomain :: String -> Maybe ThreadId -> IO ()
validateLoopDomain domain plannerThread = do
  unless (domain `elem` ["pr-review", "issue-implement", "issue-planning"]) $
    die ("unsupported automatic loop domain: " <> domain)
  when (domain == "issue-planning" && plannerThread == Nothing) $
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

pidFileNameForDomain :: String -> FilePath
pidFileNameForDomain "pr-review" = "watcher.pid"
pidFileNameForDomain "issue-implement" = "issue-watcher.pid"
pidFileNameForDomain _ = "issue-planning-watcher.pid"

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

parseDaemonObservation :: [String] -> IO DaemonObservation
parseDaemonObservation args = do
  domain <- requiredFlag "--domain" args
  observation <- requiredFlag "--observation" args
  case (domain, observation) of
    ("issue-planning", "turn-started") ->
      DaemonIssuePlanningObservation
        <$> (ObservedPlanningTurnStarted <$> requiredThreadId "--thread-id" args <*> requiredTurnId "--turn-id" args)
    ("issue-planning", "turn-completed") ->
      pure (DaemonIssuePlanningObservation ObservedPlanningTurnCompleted)
    ("issue-implement", "triage-turn-started") ->
      DaemonIssueImplementObservation . ObservedTriageTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "triage-already-fixed") ->
      pure (DaemonIssueImplementObservation ObservedTriageAlreadyFixed)
    ("issue-implement", "triage-needs-implementation") ->
      pure (DaemonIssueImplementObservation ObservedTriageNeedsImplementation)
    ("issue-implement", "triage-blocked") ->
      DaemonIssueImplementObservation . ObservedTriageBlocked <$> requiredBlockedReason args
    ("issue-implement", "plan-turn-started") ->
      DaemonIssueImplementObservation . ObservedPlanTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "plan-completed") ->
      pure (DaemonIssueImplementObservation (ObservedPlanCompleted (TurnId . Text.pack <$> lookupFlag "--implementation-turn-id" args)))
    ("issue-implement", "pr-created") ->
      DaemonIssueImplementObservation . ObservedPullRequestCreated <$> requiredPrNumber args
    ("issue-implement", "pr-reused") ->
      DaemonIssueImplementObservation . ObservedPullRequestReused <$> requiredPrNumber args
    ("issue-implement", "implementation-turn-started") ->
      DaemonIssueImplementObservation . ObservedImplementationTurnStarted <$> requiredTurnId "--turn-id" args
    ("issue-implement", "implementation-incomplete") ->
      pure (DaemonIssueImplementObservation (ObservedImplementationIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args)))))
    ("issue-implement", "implementation-blocked") ->
      DaemonIssueImplementObservation . ObservedImplementationBlocked <$> requiredBlockedReason args
    ("issue-implement", "review-handoff-initialized") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffInitialized <$> requiredPrNumber args
    ("issue-implement", "review-handoff-started") ->
      DaemonIssueImplementObservation . ObservedReviewHandoffStarted <$> requiredPrNumber args
    ("issue-implement", "implementation-completed") ->
      DaemonIssueImplementObservation . ObservedImplementationCompleted <$> requiredPrNumber args
    ("pr-review", "review-threads") ->
      DaemonPrReviewObservation
        <$> (ObservedReviewThreads <$> reviewThreadsReportFromArgs args <*> requiredCommitSha "--commit-sha" args <*> requiredTurnId "--turn-id" args)
    ("pr-review", "worker-completed") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome WorkerCompleted))
    ("pr-review", "worker-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedWorkerOutcome (WorkerIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args))))))
    ("pr-review", "worker-blocked") ->
      DaemonPrReviewObservation . ObservedWorkerOutcome . WorkerBlocked <$> requiredBlockedReason args
    ("pr-review", "reviewer-clean") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerClean <$> requiredCleanReviewEvidence args
    ("pr-review", "reviewer-problems") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerProblemsAdded <$> requiredCommitSha "--commit-sha" args
    ("pr-review", "reviewer-incomplete") ->
      pure (DaemonPrReviewObservation (ObservedReviewerOutcome (ReviewerIncomplete (Text.pack (maybe "incomplete" id (lookupFlag "--reason" args))))))
    ("pr-review", "reviewer-blocked") ->
      DaemonPrReviewObservation . ObservedReviewerOutcome . ReviewerBlocked <$> requiredBlockedReason args
    ("pr-review", "merge-completed") ->
      DaemonPrReviewObservation . ObservedMergeCompleted . MergeCommit <$> requiredCommitSha "--merge-commit-sha" args
    ("pr-review", "blocked") ->
      DaemonPrReviewObservation . ObservedPrReviewBlocked <$> requiredBlockedReason args
    _ ->
      die ("unsupported observe-once domain/observation: " <> domain <> "/" <> observation)

defaultEffectRuntimeConfig :: RepoName -> FilePath -> FilePath -> EffectRuntimeConfig
defaultEffectRuntimeConfig repo workdir stateDir =
  EffectRuntimeConfig
    { effectRuntimeRepo = repo
    , effectRuntimeWorkdir = workdir
    , effectRuntimeStateDir = stateDir
    , effectRuntimeMergeMethod = "merge"
    , effectRuntimeNextRequestId = 1
    , effectRuntimePlannerTurn = turnConfig plannerTurnInput
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
      , turnRuntimeOutputSchema = Just structuredTurnOutputSchema
      , turnRuntimeCollaborationMode = Nothing
      }

reviewThreadsReportFromArgs :: [String] -> IO ReviewThreadsReport
reviewThreadsReportFromArgs args =
  pure
    ReviewThreadsReport
      { reviewThreads = unresolvedThreads
      , unresolvedReviewThreads = unresolvedThreads
      }
 where
  unresolvedThreads =
    fmap
      (\threadId -> ReviewThread threadId False False Nothing Nothing Nothing [])
      (reviewThreadIdsFromArgs args)

reviewThreadIdsFromArgs :: [String] -> [ReviewThreadId]
reviewThreadIdsFromArgs args =
  case lookupFlag "--review-thread-ids" args of
    Nothing -> []
    Just value ->
      fmap (ReviewThreadId . Text.strip . Text.pack) (filter (not . null) (splitComma value))

splitComma :: String -> [String]
splitComma [] = []
splitComma text =
  case break (== ',') text of
    (part, []) -> [part]
    (part, _comma : rest) -> part : splitComma rest

parseIssueNumbers :: String -> String -> IO [IssueNumber]
parseIssueNumbers flag value =
  either (die . Text.unpack) pure (parseIssueNumbersText flag (Text.pack value))

parseIssueNumbersText :: String -> Text.Text -> Either Text.Text [IssueNumber]
parseIssueNumbersText flag text =
  traverse parsePart (filter (not . Text.null) (Text.strip <$> Text.splitOn "," text))
 where
  parsePart part =
    case readMaybe (Text.unpack part) of
      Just value | value > 0 -> Right (IssueNumber value)
      _ -> Left ("invalid issue number for " <> Text.pack flag <> ": " <> part)

requiredCleanReviewEvidence :: [String] -> IO CleanReviewEvidence
requiredCleanReviewEvidence args =
  CleanReviewEvidence
    <$> requiredCommitSha "--commit-sha" args
    <*> pure (Text.pack (maybe "LGTM" id (lookupFlag "--comment" args)))

requiredBlockedReason :: [String] -> IO BlockedReason
requiredBlockedReason args =
  BlockedReason . Text.pack <$> requiredFlag "--reason" args

requiredThreadId :: String -> [String] -> IO ThreadId
requiredThreadId flag args = ThreadId . Text.pack <$> requiredFlag flag args

requiredTurnId :: String -> [String] -> IO TurnId
requiredTurnId flag args = TurnId . Text.pack <$> requiredFlag flag args

requiredCommitSha :: String -> [String] -> IO CommitSha
requiredCommitSha flag args = CommitSha . Text.pack <$> requiredFlag flag args

requiredPrNumber :: [String] -> IO PrNumber
requiredPrNumber args = PrNumber <$> requiredIntFlag "--pr-number" args

requiredIntFlag :: String -> [String] -> IO Int
requiredIntFlag flag args = do
  value <- requiredFlag flag args
  maybe (die ("invalid integer for " <> flag <> ": " <> value)) pure (readMaybe value)

requiredFlag :: String -> [String] -> IO String
requiredFlag flag args =
  maybe (die ("missing required flag " <> flag)) pure (lookupFlag flag args)

hasFlag :: String -> [String] -> Bool
hasFlag flag = elem flag

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
