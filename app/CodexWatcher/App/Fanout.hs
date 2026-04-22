{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.App.Fanout
  ( issueFanout
  , issueImplementReviewHandoffAfterTick
  , issuePlanningFanoutAfterTick
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.App.Common
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.Cli
import CodexWatcher.CompatibilityState
import CodexWatcher.Daemon
import CodexWatcher.DaemonLoop
import CodexWatcher.EventLog
import CodexWatcher.GhGit
import CodexWatcher.IssuePlanningFanout
import CodexWatcher.IssuePlanningWatcher
import CodexWatcher.Runtime
import CodexWatcher.RuntimeStatus
import CodexWatcher.TurnOutput
import CodexWatcher.Types
import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.Aeson (Value, object, (.=))
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes, fromMaybe)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
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

data PrReviewWatcherLaunchPlan = PrReviewWatcherLaunchPlan
  { reviewLaunchPrConfig :: PrConfig
  , reviewLaunchWorkerThreadId :: ThreadId
  , reviewLaunchReviewerThreadId :: ThreadId
  , reviewLaunchStateDir :: FilePath
  , reviewLaunchConfigPath :: FilePath
  , reviewLaunchEventsPath :: FilePath
  , reviewLaunchWorkdir :: FilePath
  , reviewLaunchConfigJson :: Value
  , reviewLaunchInitialEvent :: WatcherEvent
  , reviewLaunchCompatibilityWrites :: [CompatibilityWrite]
  }
  deriving stock (Eq, Show)

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
runIssueImplementerLaunches ExecuteActions maybeEndpoint childLaunch launches = do
  mapM_ ensureIssueImplementerLaunchWritable launches
  mapM_ prepareIssueImplementerWorkdir launches
  preparedLaunches <- traverse (uncurry (prepareIssueImplementerLaunch maybeEndpoint)) (zip [8000 ..] launches)
  mapM_ writeIssueImplementerLaunch preparedLaunches
  mapM_ (startIssueImplementerChild childLaunch) preparedLaunches

ensureIssueImplementerLaunchWritable :: IssueImplementerLaunchPlan -> IO ()
ensureIssueImplementerLaunchWritable launch =
  ensureLaunchStateWritable "issue implementer" launch.launchStateDir launch.launchConfigPath launch.launchEventsPath

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
  threadId <- startAppServerThread endpoint requestId (issueImplementerThreadStartOptions launch)
  pure (withLaunchThreadId threadId launch)

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
  ensureIssueImplementerLaunchWritable launch
  writeWatcherBootstrap launch.launchConfigPath launch.launchEventsPath launch.launchConfigJson launch.launchInitialEvent launch.launchCompatibilityWrites
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

printIssueImplementerChildLaunch :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
printIssueImplementerChildLaunch DoNotLaunchChildren _launch =
  pure ()
printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch =
  printChildCommand "child command: " (issueImplementerChildArgs endpoint pollSeconds launch)
printIssueImplementerChildLaunch StartChildLaunches {} _launch =
  pure ()

startIssueImplementerChild :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO ()
startIssueImplementerChild DoNotLaunchChildren _launch =
  pure ()
startIssueImplementerChild (PrintChildLaunchCommands endpoint pollSeconds) launch =
  printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch
startIssueImplementerChild (StartChildLaunches endpoint pollSeconds) launch =
  startWatcherChildProcess
    launch.launchStateDir
    (issueImplementerChildArgs endpoint pollSeconds launch)
    (Text.pack ("started issue implementer " <> show (unIssueNumber (launchIssueNumber launch))))

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
  , "--start-children"
  ]
    <> if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]

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

ensurePrReviewWatcherForHandoff :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> IssueConfig -> PrNumber -> IO ()
ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber = do
  let launch = prReviewWatcherLaunchPlan (prReviewWatchersRootForIssueStateDir cli.loopCliStateDir) cli.loopCliWorkdir issueConfig prNumber
  status <- prReviewWatcherRuntimeStatus launch.reviewLaunchStateDir
  case status of
    Missing ->
      launchPrReviewWatcher executionMode (Just endpoint) cli.loopCliPollSeconds cli.loopCliStartChildren launch
    ActiveStopped ->
      startPrReviewWatcherChildIfEnabled cli.loopCliStartChildren endpoint cli.loopCliPollSeconds launch
    ActiveRunning ->
      putStrLn ("PR review watcher already running for #" <> show (unPrNumber prNumber))
    Terminal ->
      putStrLn ("PR review watcher already terminal for #" <> show (unPrNumber prNumber))

prReviewWatchersRootForIssueStateDir :: FilePath -> FilePath
prReviewWatchersRootForIssueStateDir issueStateDir =
  takeDirectory (takeDirectory issueStateDir) </> "pr-review-watchers"

prReviewWatcherLaunchPlan :: FilePath -> FilePath -> IssueConfig -> PrNumber -> PrReviewWatcherLaunchPlan
prReviewWatcherLaunchPlan root workdir issueConfig prNumber =
  PrReviewWatcherLaunchPlan
    { reviewLaunchPrConfig = prConfig
    , reviewLaunchWorkerThreadId = workerThread
    , reviewLaunchReviewerThreadId = reviewerThread
    , reviewLaunchStateDir = stateDir
    , reviewLaunchConfigPath = stateDir </> "config.json"
    , reviewLaunchEventsPath = stateDir </> "events.jsonl"
    , reviewLaunchWorkdir = workdir
    , reviewLaunchConfigJson = prReviewWatcherConfigJson prConfig workerThread reviewerThread stateDir workdir
    , reviewLaunchInitialEvent = PrReviewInitialized prConfig workerThread reviewerThread
    , reviewLaunchCompatibilityWrites = compatibilityStateWrites stateDir initialState
    }
 where
  prConfig = PrConfig issueConfig.issueRepo prNumber issueConfig.issueBranch
  workerThread = ThreadId ("pr-worker-" <> Text.pack (show (unPrNumber prNumber)))
  reviewerThread = ThreadId ("pr-reviewer-" <> Text.pack (show (unPrNumber prNumber)))
  stateDir = root </> prReviewWatcherSlug issueConfig.issueRepo prNumber
  initialState = SomeWatcherState (PrCheckingReviews prConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))

prReviewWatcherSlug :: RepoName -> PrNumber -> FilePath
prReviewWatcherSlug repo prNumber =
  Text.unpack (Text.replace "/" "_" (unRepoName repo) <> "__pr" <> Text.pack (show (unPrNumber prNumber)))

prReviewWatcherConfigJson :: PrConfig -> ThreadId -> ThreadId -> FilePath -> FilePath -> Value
prReviewWatcherConfigJson prConfig workerThread reviewerThread stateDir workdir =
  object
    [ "repoFullName" .= unRepoName prConfig.prRepo
    , "prNumber" .= unPrNumber prConfig.prNumber
    , "branch" .= unBranchName prConfig.prBranch
    , "threadId" .= unThreadId workerThread
    , "reviewerThreadId" .= unThreadId reviewerThread
    , "stateDir" .= stateDir
    , "configPath" .= (stateDir </> "config.json")
    , "eventsPath" .= (stateDir </> "events.jsonl")
    , "workdir" .= workdir
    ]

withPrReviewThreadIds :: ThreadId -> ThreadId -> PrReviewWatcherLaunchPlan -> PrReviewWatcherLaunchPlan
withPrReviewThreadIds workerThread reviewerThread launch =
  launch
    { reviewLaunchWorkerThreadId = workerThread
    , reviewLaunchReviewerThreadId = reviewerThread
    , reviewLaunchConfigJson = prReviewWatcherConfigJson launch.reviewLaunchPrConfig workerThread reviewerThread launch.reviewLaunchStateDir launch.reviewLaunchWorkdir
    , reviewLaunchInitialEvent = PrReviewInitialized launch.reviewLaunchPrConfig workerThread reviewerThread
    , reviewLaunchCompatibilityWrites = compatibilityStateWrites launch.reviewLaunchStateDir initialState
    }
 where
  initialState = SomeWatcherState (PrCheckingReviews launch.reviewLaunchPrConfig (WorkerIdle workerThread) (ReviewerIdle reviewerThread))

launchPrReviewWatcher :: ActionExecutionMode -> Maybe AppServerEndpoint -> Int -> Bool -> PrReviewWatcherLaunchPlan -> IO ()
launchPrReviewWatcher DryRunActions _endpoint pollSeconds startChildren launch = do
  printPrReviewWatcherLaunch launch
  maybe (pure ()) (\endpoint -> when startChildren (printPrReviewWatcherChildLaunch endpoint pollSeconds launch)) _endpoint
launchPrReviewWatcher ExecuteActions maybeEndpoint pollSeconds startChildren launch = do
  ensurePrReviewWatcherLaunchWritable launch
  preparedLaunch <- preparePrReviewWatcherLaunch maybeEndpoint launch
  writePrReviewWatcherLaunch preparedLaunch
  maybe (pure ()) (\endpoint -> when startChildren (startPrReviewWatcherChild endpoint pollSeconds preparedLaunch)) maybeEndpoint

preparePrReviewWatcherLaunch :: Maybe AppServerEndpoint -> PrReviewWatcherLaunchPlan -> IO PrReviewWatcherLaunchPlan
preparePrReviewWatcherLaunch Nothing launch =
  pure launch
preparePrReviewWatcherLaunch (Just endpoint) launch = do
  workerThread <- startPrReviewThread endpoint 9000 launch "worker"
  reviewerThread <- startPrReviewThread endpoint 9001 launch "reviewer"
  pure (withPrReviewThreadIds workerThread reviewerThread launch)

startPrReviewThread :: AppServerEndpoint -> Int -> PrReviewWatcherLaunchPlan -> Text.Text -> IO ThreadId
startPrReviewThread endpoint requestId launch role =
  startAppServerThread endpoint requestId (prReviewThreadStartOptions launch role)

prReviewThreadStartOptions :: PrReviewWatcherLaunchPlan -> Text.Text -> ThreadStartOptions
prReviewThreadStartOptions launch role =
  defaultThreadStartOptions
    launch.reviewLaunchWorkdir
    (prReviewThreadDeveloperInstructions launch.reviewLaunchWorkdir launch.reviewLaunchStateDir launch.reviewLaunchPrConfig role)

writePrReviewWatcherLaunch :: PrReviewWatcherLaunchPlan -> IO ()
writePrReviewWatcherLaunch launch = do
  ensurePrReviewWatcherLaunchWritable launch
  writeWatcherBootstrap launch.reviewLaunchConfigPath launch.reviewLaunchEventsPath launch.reviewLaunchConfigJson launch.reviewLaunchInitialEvent launch.reviewLaunchCompatibilityWrites
  putStrLn ("wrote PR review watcher " <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber) <> " to " <> launch.reviewLaunchStateDir)

ensurePrReviewWatcherLaunchWritable :: PrReviewWatcherLaunchPlan -> IO ()
ensurePrReviewWatcherLaunchWritable launch =
  ensureLaunchStateWritable "PR review watcher" launch.reviewLaunchStateDir launch.reviewLaunchConfigPath launch.reviewLaunchEventsPath

printPrReviewWatcherLaunch :: PrReviewWatcherLaunchPlan -> IO ()
printPrReviewWatcherLaunch launch =
  putStrLn
    ( "PR #"
        <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber)
        <> " -> "
        <> launch.reviewLaunchStateDir
        <> " worker "
        <> Text.unpack (unThreadId launch.reviewLaunchWorkerThreadId)
        <> " reviewer "
        <> Text.unpack (unThreadId launch.reviewLaunchReviewerThreadId)
    )

printPrReviewWatcherChildLaunch :: AppServerEndpoint -> Int -> PrReviewWatcherLaunchPlan -> IO ()
printPrReviewWatcherChildLaunch endpoint pollSeconds launch =
  printChildCommand "PR review child command: " (prReviewWatcherChildArgs endpoint pollSeconds launch)

startPrReviewWatcherChildIfEnabled :: Bool -> AppServerEndpoint -> Int -> PrReviewWatcherLaunchPlan -> IO ()
startPrReviewWatcherChildIfEnabled False _endpoint _pollSeconds _launch =
  pure ()
startPrReviewWatcherChildIfEnabled True endpoint pollSeconds launch =
  startPrReviewWatcherChild endpoint pollSeconds launch

startPrReviewWatcherChild :: AppServerEndpoint -> Int -> PrReviewWatcherLaunchPlan -> IO ()
startPrReviewWatcherChild endpoint pollSeconds launch =
  startWatcherChildProcess
    launch.reviewLaunchStateDir
    (prReviewWatcherChildArgs endpoint pollSeconds launch)
    (Text.pack ("started PR review watcher " <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber)))

prReviewWatcherChildArgs :: AppServerEndpoint -> Int -> PrReviewWatcherLaunchPlan -> [String]
prReviewWatcherChildArgs endpoint pollSeconds launch =
  [ "run-pr-review"
  , "--events"
  , launch.reviewLaunchEventsPath
  , "--state-dir"
  , launch.reviewLaunchStateDir
  , "--repo"
  , Text.unpack (unRepoName launch.reviewLaunchPrConfig.prRepo)
  , "--workdir"
  , launch.reviewLaunchWorkdir
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

prReviewWatcherRuntimeStatus :: FilePath -> IO RuntimeStatus
prReviewWatcherRuntimeStatus stateDir = do
  let configPath = stateDir </> "config.json"
      eventsPath = stateDir </> "events.jsonl"
  watcherRuntimeStatus
    configPath
    eventsPath
    (prReviewWatcherPidRunning stateDir)
    (pure Missing)
    \state ->
      pure
        if someDomain state == PrReview && isTerminalPhase (somePhase state)
          then Just Terminal
          else Nothing

prReviewWatcherPidRunning :: FilePath -> IO Bool
prReviewWatcherPidRunning =
  watcherPidRunning "watcher.pid"

launchIssueNumber :: IssueImplementerLaunchPlan -> IssueNumber
launchIssueNumber launch =
  case launch.launchIssueConfig of
    IssueConfig _ issue _ -> issue

issuePlanningFanoutAfterTick :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> DaemonLoopTickResult -> IO Bool
issuePlanningFanoutAfterTick cli endpoint executionMode tick =
  case (cli.loopCliDomain, cli.loopCliImplementersRoot) of
    (CliIssuePlanning, Just implementersRoot) -> do
      maintainObservedPlanningState implementersRoot
      maintainReplayPlanningState implementersRoot
      pure False
    _ -> pure False
 where
  maintainObservedPlanningState implementersRoot =
    case tick.loopObservedTick of
      Just observedTick
        | issuePlanningCompletionEvent observedTick.daemonObservedEvent -> do
            plannerConfig <- maybe (die "issue planning fanout requires a planner config in the observed state") pure (plannerConfigFromState observedTick.daemonObservedState)
            readyIssues <- resolveFanoutReadyIssues observedTick.daemonObservedEvent
            maintainReadyIssueImplementers cli endpoint executionMode implementersRoot observedTick.daemonObservedState plannerConfig readyIssues
      _ -> pure ()
  maintainReplayPlanningState implementersRoot =
    case tick.loopReplayResult.replayState of
      SomeWatcherState (PlanningWaitingForReadyIssues plannerConfig graph) ->
        maintainReadyIssueImplementers cli endpoint executionMode implementersRoot tick.loopReplayResult.replayState plannerConfig graph.planningReadyIssues
      _ -> pure ()

maintainReadyIssueImplementers :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> FilePath -> SomeWatcherState -> PlannerConfig -> [IssueNumber] -> IO ()
maintainReadyIssueImplementers cli endpoint executionMode implementersRoot planningState plannerConfig readyIssues = do
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
  when allReadyIssuesTerminal $
    markPlanningReadyIssuesFixed executionMode cli planningState

readyIssueStatusFromRuntime :: RuntimeStatus -> ReadyIssueStatus
readyIssueStatusFromRuntime = \case
  Missing -> ReadyIssueMissing
  ActiveStopped -> ReadyIssueActiveStopped
  ActiveRunning -> ReadyIssueActiveRunning
  Terminal -> ReadyIssueTerminal

issueImplementerRuntimeStatus :: IssuePlanningFanoutConfig -> PlannerConfig -> IssueNumber -> IO RuntimeStatus
issueImplementerRuntimeStatus fanoutConfig plannerConfig issueNumber' = do
  let stateDir = issueImplementerStateDir fanoutConfig.fanoutImplementersRoot plannerConfig.plannerRepo issueNumber'
      eventsPath = stateDir </> "events.jsonl"
      configPath = stateDir </> "config.json"
  watcherRuntimeStatus
    configPath
    eventsPath
    (issueImplementerPidRunning stateDir)
    missingIssueImplementerStatus
    terminalIssueImplementerStatus
 where
  missingIssueImplementerStatus = do
    fixed <- githubIssueClosed plannerConfig.plannerRepo issueNumber'
    pure (if fixed then Terminal else Missing)
  terminalIssueImplementerStatus state
    | someDomain state == IssueImplement && isTerminalPhase (somePhase state) = do
        fixed <- githubIssueClosed plannerConfig.plannerRepo issueNumber'
        pure (Just (if fixed then Terminal else ActiveRunning))
    | otherwise =
        pure Nothing

githubIssueClosed :: RepoName -> IssueNumber -> IO Bool
githubIssueClosed repo issueNumber' = do
  remoteIssue <- runGhIssueView ioRuntimeInterpreter repo issueNumber'
  case remoteIssue of
    Right issue ->
      pure (issue.remoteIssueClosed || issue.remoteIssueState == "CLOSED")
    Left errorMessage -> do
      putStrLn ("planner could not verify issue " <> show (unIssueNumber issueNumber') <> " remote state: " <> Text.unpack errorMessage)
      pure False

issueImplementerPidRunning :: FilePath -> IO Bool
issueImplementerPidRunning =
  watcherPidRunning "issue-watcher.pid"

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
            mapM_ (writeCompatibilityLaunch ioRuntimeInterpreter) (compatibilityStateWrites cli.loopCliStateDir fixedTick.issuePlanningTickState)
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
