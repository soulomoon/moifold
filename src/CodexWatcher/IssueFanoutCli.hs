{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.IssueFanoutCli
  ( IssueImplementerChildLaunch (..)
  , issueFanout
  , issueImplementerChildLaunchMode
  , runIssueImplementerLaunches
  , startIssueImplementerChild
  , resolveFanoutActiveIssues
  , issueImplementerRuntimeStatus
  , readyIssueStatusFromRuntime
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.ChildDaemon
import CodexWatcher.Cli
import CodexWatcher.CompatibilityRuntime
import CodexWatcher.Daemon (appendWatcherEvent)
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.Runtime
import CodexWatcher.RuntimeOwner (RuntimeOwner (HaskellRuntime), writeRuntimeOwner)
import CodexWatcher.RuntimeDefaults (defaultThreadStartOptions)
import CodexWatcher.TurnOutput (issueImplementerThreadDeveloperInstructions)
import CodexWatcher.Types
import CodexWatcher.WatcherPaths qualified as WatcherPaths
import CodexWatcher.WatcherRuntimeStatus
import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.Aeson (Value, object, (.=))
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, removeFile)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))

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
      plannerConfig = PlannerConfig options.issueFanoutCliRepo options.issueFanoutCliMaxParallel []
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
      issues <- traverse (loadActiveIssueImplementerIssue repo . (implementersRoot </>)) children
      pure (nub (sortOn unIssueNumber (catMaybes issues)))

loadActiveIssueImplementerIssue :: RepoName -> FilePath -> IO (Maybe IssueNumber)
loadActiveIssueImplementerIssue repo stateDir = do
  maybeIssue <- loadIssueImplementerConfigIssue repo stateDir
  case maybeIssue of
    Nothing -> pure Nothing
    Just issue -> do
      active <- issueImplementerStateIsActive stateDir
      pure (if active then Just issue else Nothing)

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

issueImplementerStateIsActive :: FilePath -> IO Bool
issueImplementerStateIsActive stateDir = do
  let eventsPath = stateDir </> "events.jsonl"
  exists <- doesFileExist eventsPath
  if not exists
    then pure True
    else do
      loaded <- loadEventLogFile eventsPath
      case loaded of
        Left _ -> pure True
        Right events ->
          case replayEventLog events of
            Left _ -> pure True
            Right replay ->
              pure (someDomain replay.replayState == IssueImplement && not (isTerminalPhase (somePhase replay.replayState)))

data IssueImplementerChildLaunch
  = DoNotLaunchChildren
  | PrintChildLaunchCommands AppServerEndpoint Int
  | StartChildLaunches AppServerEndpoint Int

issueImplementerChildLaunchMode :: Bool -> Maybe Int -> Maybe Int -> ActionExecutionMode -> Maybe AppServerEndpoint -> IO IssueImplementerChildLaunch
issueImplementerChildLaunchMode startChildren maybePollSeconds maybeChildPollSeconds executionMode maybeEndpoint
  | not startChildren = pure DoNotLaunchChildren
  | otherwise = do
      endpoint <- maybe (die "--start-children requires --app-server-host and --app-server-port") pure maybeEndpoint
      let pollSeconds = fromMaybe 30 (maybeChildPollSeconds <|> maybePollSeconds)
      pure case executionMode of
        DryRunActions -> PrintChildLaunchCommands endpoint pollSeconds
        ExecuteActions -> StartChildLaunches endpoint pollSeconds

runIssueImplementerLaunches :: ActionExecutionMode -> Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> [IssueImplementerLaunchPlan] -> IO ()
runIssueImplementerLaunches DryRunActions _endpoint childLaunch launches = do
  mapM_ printIssueImplementerLaunch launches
  mapM_ (printIssueImplementerChildLaunch childLaunch) launches
runIssueImplementerLaunches ExecuteActions maybeEndpoint childLaunch launches =
  mapM_ (uncurry (runIssueImplementerLaunch maybeEndpoint childLaunch)) (zip [8000 ..] launches)

runIssueImplementerLaunch :: Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> Int -> IssueImplementerLaunchPlan -> IO ()
runIssueImplementerLaunch maybeEndpoint childLaunch requestId launch = do
  ensureIssueImplementerLaunchWritable launch
  prepareIssueImplementerWorkdir launch
  writeIssueImplementerLaunchPending childLaunch launch
  preparedLaunch <- prepareIssueImplementerLaunch maybeEndpoint requestId launch
  writeIssueImplementerLaunch preparedLaunch
  writeIssueImplementerLaunchFinalized childLaunch preparedLaunch
  startIssueImplementerChild childLaunch preparedLaunch

ensureIssueImplementerLaunchWritable :: IssueImplementerLaunchPlan -> IO ()
ensureIssueImplementerLaunchWritable launch = do
  ensureIssueImplementerLaunchStateEmpty launch
  pendingExists <- doesFileExist (launchPendingManifestPath launch.launchStateDir)
  when pendingExists $
    die
      ( "refusing to overwrite pending issue implementer launch state: "
          <> launch.launchStateDir
          <> "; inspect or remove "
          <> launchPendingManifestPath launch.launchStateDir
          <> " before retrying"
      )

ensureIssueImplementerLaunchStateEmpty :: IssueImplementerLaunchPlan -> IO ()
ensureIssueImplementerLaunchStateEmpty launch = do
  configExists <- doesFileExist launch.launchConfigPath
  eventsExists <- doesFileExist launch.launchEventsPath
  finalizedExists <- doesFileExist (launchFinalizedManifestPath launch.launchStateDir)
  when (configExists || eventsExists || finalizedExists) $
    die ("refusing to overwrite existing issue implementer state: " <> launch.launchStateDir)

prepareIssueImplementerWorkdir :: IssueImplementerLaunchPlan -> IO ()
prepareIssueImplementerWorkdir launch =
  case launch.launchWorkdir of
    Nothing -> pure ()
    Just workdir -> do
      exists <- doesDirectoryExist workdir
      if exists
        then do
          ensureLaunchCommand launch (RawCommand "git" ["rev-parse", "--is-inside-work-tree"] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["checkout", "-B", Text.unpack (unBranchName launch.launchIssueConfig.issueBranch)] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["config", "user.email", "codex-watcher@users.noreply.github.com"] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["config", "user.name", "codex-watcher"] (Just workdir))
        else do
          createDirectoryIfMissing True (takeDirectory workdir)
          mapM_ (ensureLaunchCommand launch) (issueImplementerWorkdirSetupCommands launch)

ensureLaunchCommand :: IssueImplementerLaunchPlan -> RuntimeCommand -> IO ()
ensureLaunchCommand launch command = do
  report <- runRuntimeCommand command
  unless report.ok $
    die
      ( "failed to prepare workdir for issue "
          <> show (unIssueNumber (launchIssueNumber launch))
          <> " with "
          <> show (renderRuntimeCommand command)
          <> ": "
          <> Text.unpack (commandText report)
      )

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
  defaultThreadStartOptions
    (maybe "." id launch.launchWorkdir)
    ( issueImplementerThreadDeveloperInstructions
        (maybe "." id launch.launchWorkdir)
        launch.launchStateDir
        launch.launchIssueConfig
    )

writeIssueImplementerLaunch :: IssueImplementerLaunchPlan -> IO ()
writeIssueImplementerLaunch launch = do
  ensureIssueImplementerLaunchStateEmpty launch
  createDirectoryIfMissing True launch.launchStateDir
  writeJsonValue launch.launchConfigPath launch.launchConfigJson
  appendWatcherEvent ioRuntimeInterpreter launch.launchEventsPath launch.launchInitialEvent
  mapM_ (writeCompatibility ioRuntimeInterpreter) launch.launchCompatibilityWrites
  writeRuntimeOwner ioRuntimeInterpreter launch.launchStateDir HaskellRuntime
  putStrLn ("wrote issue implementer " <> show (unIssueNumber (launchIssueNumber launch)) <> " to " <> launch.launchStateDir)

writeIssueImplementerLaunchPending :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
writeIssueImplementerLaunchPending childLaunch launch =
  writeJsonValue
    (launchPendingManifestPath launch.launchStateDir)
    (issueImplementerLaunchManifest "pending" childLaunch launch)

writeIssueImplementerLaunchFinalized :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
writeIssueImplementerLaunchFinalized childLaunch launch = do
  writeJsonValue
    (launchFinalizedManifestPath launch.launchStateDir)
    (issueImplementerLaunchManifest "finalized" childLaunch launch)
  pendingExists <- doesFileExist (launchPendingManifestPath launch.launchStateDir)
  when pendingExists (removeFile (launchPendingManifestPath launch.launchStateDir))

issueImplementerLaunchManifest :: Text.Text -> IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> Value
issueImplementerLaunchManifest status childLaunch launch =
  object
    [ "status" .= status
    , "launchKind" .= ("issue-implementer" :: Text.Text)
    , "repo" .= unRepoName launch.launchIssueConfig.issueRepo
    , "issueNumber" .= unIssueNumber launch.launchIssueConfig.issueNumber
    , "workdir" .= launch.launchWorkdir
    , "stateDir" .= launch.launchStateDir
    , "configPath" .= launch.launchConfigPath
    , "eventsPath" .= launch.launchEventsPath
    , "intendedThreadRoles" .= (["worker"] :: [Text.Text])
    , "threadId" .= unThreadId launch.launchThreadId
    , "childLaunch" .= issueImplementerChildLaunchText childLaunch
    , "createdAt" .= ("unknown" :: Text.Text)
    ]

issueImplementerChildLaunchText :: IssueImplementerChildLaunch -> Text.Text
issueImplementerChildLaunchText = \case
  DoNotLaunchChildren -> "disabled"
  PrintChildLaunchCommands {} -> "print"
  StartChildLaunches {} -> "start"

launchPendingManifestPath :: FilePath -> FilePath
launchPendingManifestPath stateDir =
  stateDir </> "launch-pending.json"

launchFinalizedManifestPath :: FilePath -> FilePath
launchFinalizedManifestPath stateDir =
  stateDir </> "launch-finalized.json"

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

printIssueImplementerChildLaunch :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
printIssueImplementerChildLaunch DoNotLaunchChildren _launch =
  pure ()
printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch = do
  executable <- stableExecutablePath
  putStrLn ("child command: " <> unwords (executable : issueImplementerChildArgs endpoint pollSeconds launch))
printIssueImplementerChildLaunch StartChildLaunches {} _launch =
  pure ()

startIssueImplementerChild :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
startIssueImplementerChild DoNotLaunchChildren _launch =
  pure ()
startIssueImplementerChild (PrintChildLaunchCommands endpoint pollSeconds) launch =
  printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch
startIssueImplementerChild (StartChildLaunches endpoint pollSeconds) launch =
  startChildDaemon
    ( "issue implementer "
        <> show (unIssueNumber (launchIssueNumber launch))
    )
    launch.launchStateDir
    "issue-watcher.pid"
    (issueImplementerChildArgs endpoint pollSeconds launch)

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
  , "--pid-file"
  , launch.launchStateDir </> "issue-watcher.pid"
  , "--start-children"
  ]
    <> if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]

readyIssueStatusFromRuntime :: WatcherRuntimeStatus -> ReadyIssueStatus
readyIssueStatusFromRuntime = \case
  WatcherMissing -> ReadyIssueMissing
  WatcherActiveStopped -> ReadyIssueActiveStopped
  WatcherActiveRunning -> ReadyIssueActiveRunning
  WatcherTerminal TerminalComplete -> ReadyIssueTerminal
  WatcherTerminal (TerminalBlocked _) -> ReadyIssueActiveStopped
  WatcherTerminal (TerminalStopped _) -> ReadyIssueActiveStopped

issueImplementerRuntimeStatus :: IssuePlanningFanoutConfig -> PlannerConfig -> IssueNumber -> IO WatcherRuntimeStatus
issueImplementerRuntimeStatus fanoutConfig plannerConfig issueNumber' = do
  let stateDir = issueImplementerStateDir fanoutConfig.fanoutImplementersRoot plannerConfig.plannerRepo issueNumber'
      eventsPath = stateDir </> "events.jsonl"
      configPath = stateDir </> "config.json"
      pidPath = WatcherPaths.defaultPidPath IssueImplement stateDir
      issueClosed = githubIssueClosed plannerConfig.plannerRepo issueNumber'
  watcherRuntimeStatus
    WatcherRuntimeStatusConfig
      { watcherRuntimeExpectedDomain = IssueImplement
      , watcherRuntimeConfigPath = configPath
      , watcherRuntimeEventsPath = eventsPath
      , watcherRuntimePidPath = pidPath
      , watcherRuntimeMissingIsTerminal = issueClosed
      , watcherRuntimeReplayTerminalIsTerminal = issueImplementReplayTerminalSucceeded plannerConfig.plannerRepo issueNumber'
      }

issueImplementReplayTerminalSucceeded :: RepoName -> IssueNumber -> EventReplayResult -> IO Bool
issueImplementReplayTerminalSucceeded repo issueNumber' replay =
  case replay.replayState of
    SomeWatcherState (CompleteState (IssueAlreadyResolved resolvedIssueNumber)) ->
      githubIssueClosed repo resolvedIssueNumber
    SomeWatcherState (CompleteState (IssueComplete prNumber)) ->
      (&&) <$> githubPullRequestMerged repo prNumber <*> githubIssueClosed repo issueNumber'
    _ ->
      pure False

githubPullRequestMerged :: RepoName -> PrNumber -> IO Bool
githubPullRequestMerged repo prNumber = do
  remotePr <- runGhPrView ioRuntimeInterpreter repo prNumber
  case remotePr of
    Right pr ->
      pure (Text.toUpper pr.remotePullRequestState == "MERGED")
    Left errorMessage -> do
      putStrLn ("planner could not verify PR " <> show (unPrNumber prNumber) <> " remote state: " <> Text.unpack errorMessage)
      pure False

githubIssueClosed :: RepoName -> IssueNumber -> IO Bool
githubIssueClosed repo issueNumber' = do
  remoteIssue <- runGhIssueView ioRuntimeInterpreter repo issueNumber'
  case remoteIssue of
    Right issue ->
      pure (issue.remoteIssueClosed || issue.remoteIssueState == "CLOSED")
    Left errorMessage -> do
      putStrLn ("planner could not verify issue " <> show (unIssueNumber issueNumber') <> " remote state: " <> Text.unpack errorMessage)
      pure False

launchIssueNumber :: IssueImplementerLaunchPlan -> IssueNumber
launchIssueNumber launch =
  case launch.launchIssueConfig of
    IssueConfig _ issue _ -> issue
