{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Cli.Command.IssueFanout
  ( IssueImplementerChildLaunch (..)
  , IssueImplementerChildStartResult (..)
  , issueFanout
  , issueImplementerChildLaunchMode
  , runIssueImplementerLaunches
  , runIssueImplementerLaunchesDetailed
  , startIssueImplementerChild
  , startIssueImplementerChildDetailed
  , resolveFanoutActiveIssues
  , issueImplementerRuntimeStatus
  , readyIssueStatusFromRuntime
  , retryableLaunchCommandFailure
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.ChildDaemon
import CodexWatcher.Cli.Types
import CodexWatcher.Runtime.Compatibility
import CodexWatcher.Daemon (appendWatcherEvent)
import CodexWatcher.EventLog.Types
import CodexWatcher.Failure (transientFailureText)
import CodexWatcher.GhGit
import CodexWatcher.Domain.IssuePlanning.Fanout
import CodexWatcher.Runtime.Command.Render (commandText, renderRuntimeCommand)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions)
import CodexWatcher.Runtime.File (readJsonValue, writeJsonValue)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Process (runRuntimeCommand)
import CodexWatcher.TurnOutput (issueImplementerThreadDeveloperInstructions)
import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), RepoName (..), RequestId (..), ThreadId (..))
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Core.Limits (PollSeconds, mkPollSeconds)
import CodexWatcher.Core.State (CompletionEvidence (..), SomeWatcherState (..), WatcherState (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.Runtime.WatcherPaths qualified as WatcherPaths
import CodexWatcher.WatcherRuntimeStatus
import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Monad (when)
import Data.Aeson (Value, object, (.=))
import Data.List (nub, sortOn)
import Data.Maybe (catMaybes, fromMaybe)
import Data.Proxy (Proxy (..))
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, doesPathExist, listDirectory, removeFile, removePathForcibly)
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
      status <- issueImplementerRuntimeStatusFromStateDir repo issue stateDir
      pure (if statusIsActiveRunning status then Just issue else Nothing)

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

issueImplementerRuntimeStatusFromStateDir :: RepoName -> IssueNumber -> FilePath -> IO WatcherRuntimeStatus
issueImplementerRuntimeStatusFromStateDir repo issueNumber' stateDir = do
  let statusConfig :: WatcherRuntimeStatusConfig 'IssueImplement
      statusConfig =
        WatcherRuntimeStatusConfig
          { watcherRuntimeConfigPath = stateDir </> "config.json"
          , watcherRuntimeEventsPath = stateDir </> "events.jsonl"
          , watcherRuntimePidPath = WatcherPaths.defaultPidPathForKnownDomain (Proxy @'IssueImplement) stateDir
          , watcherRuntimeMissingIsTerminal = pure False
          , watcherRuntimeReplayTerminalIsTerminal = issueImplementReplayTerminalSucceeded repo issueNumber'
          }
  watcherRuntimeStatus statusConfig

data IssueImplementerChildLaunch
  = DoNotLaunchChildren
  | PrintChildLaunchCommands AppServerEndpoint PollSeconds
  | StartChildLaunches AppServerEndpoint PollSeconds

data IssueImplementerChildStartResult
  = IssueImplementerChildStarted IssueNumber
  | IssueImplementerChildCompletedBeforeReady IssueNumber
  | IssueImplementerChildStartProblem IssueNumber Text.Text WatcherRuntimeStatus
  deriving stock (Eq, Show)

issueImplementerChildLaunchMode :: Bool -> Maybe PollSeconds -> Maybe PollSeconds -> ActionExecutionMode -> Maybe AppServerEndpoint -> IO IssueImplementerChildLaunch
issueImplementerChildLaunchMode startChildren maybePollSeconds maybeChildPollSeconds executionMode maybeEndpoint
  | not startChildren = pure DoNotLaunchChildren
  | otherwise = do
      endpoint <- maybe (die "--start-children requires --app-server-host and --app-server-port") pure maybeEndpoint
      let pollSeconds = fromMaybe defaultChildPollSeconds (maybeChildPollSeconds <|> maybePollSeconds)
      pure case executionMode of
        DryRunActions -> PrintChildLaunchCommands endpoint pollSeconds
        ExecuteActions -> StartChildLaunches endpoint pollSeconds

runIssueImplementerLaunches :: ActionExecutionMode -> Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> [IssueImplementerLaunchPlan] -> IO ()
runIssueImplementerLaunches executionMode maybeEndpoint childLaunch launches = do
  results <- runIssueImplementerLaunchesDetailed executionMode maybeEndpoint childLaunch launches
  case firstChildStartProblem results of
    Nothing -> pure ()
    Just (issue, detail, status) ->
      die
        ( "issue implementer "
            <> show (unIssueNumber issue)
            <> " did not become running and is not complete: "
            <> Text.unpack detail
            <> "; status="
            <> show status
        )

runIssueImplementerLaunchesDetailed :: ActionExecutionMode -> Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> [IssueImplementerLaunchPlan] -> IO [IssueImplementerChildStartResult]
runIssueImplementerLaunchesDetailed DryRunActions _endpoint childLaunch launches = do
  mapM_ printIssueImplementerLaunch launches
  mapM_ (printIssueImplementerChildLaunch childLaunch) launches
  pure (fmap (IssueImplementerChildStarted . launchIssueNumber) launches)
runIssueImplementerLaunchesDetailed ExecuteActions maybeEndpoint childLaunch launches =
  traverse (uncurry (runIssueImplementerLaunch maybeEndpoint childLaunch)) (zip (RequestId <$> [8000 ..]) launches)

runIssueImplementerLaunch :: Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> RequestId -> IssueImplementerLaunchPlan -> IO IssueImplementerChildStartResult
runIssueImplementerLaunch maybeEndpoint childLaunch requestId launch = do
  ensureIssueImplementerLaunchWritable launch
  prepareIssueImplementerWorkdir launch
  writeIssueImplementerLaunchPending childLaunch launch
  preparedLaunch <- prepareIssueImplementerLaunch maybeEndpoint requestId launch
  writeIssueImplementerLaunch preparedLaunch
  writeIssueImplementerLaunchFinalized childLaunch preparedLaunch
  startIssueImplementerChildDetailed childLaunch preparedLaunch

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
          ensureLaunchCommand launch (RawCommand "git" ["remote", "set-url", "origin", Text.unpack (issueImplementerGitRemoteUrl launch.launchIssueConfig.issueRepo)] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["checkout", "-B", Text.unpack (unBranchName launch.launchIssueConfig.issueBranch)] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["config", "user.email", "codex-watcher@users.noreply.github.com"] (Just workdir))
          ensureLaunchCommand launch (RawCommand "git" ["config", "user.name", "codex-watcher"] (Just workdir))
        else do
          createDirectoryIfMissing True (takeDirectory workdir)
          mapM_ (ensureLaunchCommand launch) (issueImplementerWorkdirSetupCommands launch)

ensureLaunchCommand :: IssueImplementerLaunchPlan -> RuntimeCommand -> IO ()
ensureLaunchCommand launch command =
  go launchCommandRetryDelaysMicros
 where
  go retryDelays = do
    report <- runRuntimeCommand command
    if report.ok
      then pure ()
      else
        case retryDelays of
          delayMicros : remainingDelays
            | retryableLaunchCommandFailure command report -> do
                cleanupRetryableLaunchCommand command
                putStrLn
                  ( "retrying workdir setup for issue "
                      <> show (unIssueNumber (launchIssueNumber launch))
                      <> " after transient "
                      <> commandNameForMessage command
                      <> " failure: "
                      <> Text.unpack (commandText report)
                  )
                threadDelay delayMicros
                go remainingDelays
          _ ->
            die
              ( "failed to prepare workdir for issue "
                  <> show (unIssueNumber (launchIssueNumber launch))
                  <> " with "
                  <> show (renderRuntimeCommand command)
                  <> ": "
                  <> Text.unpack (commandText report)
              )

launchCommandRetryDelaysMicros :: [Int]
launchCommandRetryDelaysMicros =
  [2 * 1000 * 1000, 5 * 1000 * 1000, 10 * 1000 * 1000]

retryableLaunchCommandFailure :: RuntimeCommand -> CommandReport -> Bool
retryableLaunchCommandFailure command report =
  isGhRepoClone command && transientFailureText (commandText report)

cleanupRetryableLaunchCommand :: RuntimeCommand -> IO ()
cleanupRetryableLaunchCommand command =
  case ghRepoCloneWorkdir command of
    Nothing -> pure ()
    Just workdir -> do
      exists <- doesPathExist workdir
      when exists (removePathForcibly workdir)

isGhRepoClone :: RuntimeCommand -> Bool
isGhRepoClone command =
  case ghRepoCloneWorkdir command of
    Just _ -> True
    Nothing -> False

ghRepoCloneWorkdir :: RuntimeCommand -> Maybe FilePath
ghRepoCloneWorkdir = \case
  RawCommand "gh" ["repo", "clone", _repo, workdir] Nothing -> Just workdir
  _ -> Nothing

commandNameForMessage :: RuntimeCommand -> String
commandNameForMessage = \case
  RawCommand command _ _ -> command
  _ -> "command"

prepareIssueImplementerLaunch :: Maybe AppServerEndpoint -> RequestId -> IssueImplementerLaunchPlan -> IO IssueImplementerLaunchPlan
prepareIssueImplementerLaunch Nothing _requestId launch =
  pure launch
prepareIssueImplementerLaunch (Just endpoint) requestId launch = do
  result <-
    startThreadWithEndpoint
      endpoint
      defaultAppServerClientOptions
      requestId
      (issueImplementerThreadStartOptions launch)
  case result of
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
startIssueImplementerChild childLaunch launch = do
  result <- startIssueImplementerChildDetailed childLaunch launch
  case result of
    IssueImplementerChildStarted {} -> pure ()
    IssueImplementerChildCompletedBeforeReady {} -> pure ()
    IssueImplementerChildStartProblem issue detail status ->
      die
        ( "issue implementer "
            <> show (unIssueNumber issue)
            <> " did not become running and is not complete: "
            <> Text.unpack detail
            <> "; status="
            <> show status
        )

startIssueImplementerChildDetailed :: IssueImplementerChildLaunch -> IssueImplementerLaunchPlan -> IO IssueImplementerChildStartResult
startIssueImplementerChildDetailed DoNotLaunchChildren launch =
  pure (IssueImplementerChildStarted (launchIssueNumber launch))
startIssueImplementerChildDetailed (PrintChildLaunchCommands endpoint pollSeconds) launch = do
  printIssueImplementerChildLaunch (PrintChildLaunchCommands endpoint pollSeconds) launch
  pure (IssueImplementerChildStarted (launchIssueNumber launch))
startIssueImplementerChildDetailed (StartChildLaunches endpoint pollSeconds) launch = do
  readiness <-
    startChildDaemonChecked
      label
      launch.launchStateDir
      "issue-watcher.pid"
      (issueImplementerChildArgs endpoint pollSeconds launch)
  case readiness of
    DaemonPidReady ->
      pure (IssueImplementerChildStarted issue)
    DaemonPidNotReady detail -> do
      status <- issueImplementerRuntimeStatusForLaunch launch
      pure case status of
        WatcherTerminal TerminalComplete ->
          IssueImplementerChildCompletedBeforeReady issue
        WatcherActiveRunning ->
          IssueImplementerChildStarted issue
        _ ->
          IssueImplementerChildStartProblem issue detail status
 where
  issue = launchIssueNumber launch
  label = "issue implementer " <> show (unIssueNumber issue)

issueImplementerChildArgs :: AppServerEndpoint -> PollSeconds -> IssueImplementerLaunchPlan -> [String]
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

defaultChildPollSeconds :: PollSeconds
defaultChildPollSeconds =
  case mkPollSeconds 30 of
    Just parsed -> parsed
    Nothing -> error "invalid default child poll seconds"

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
      launch =
        (issueImplementerLaunchPlan fanoutConfig plannerConfig issueNumber')
          { launchStateDir = stateDir
          , launchConfigPath = stateDir </> "config.json"
          , launchEventsPath = stateDir </> "events.jsonl"
          }
  issueImplementerRuntimeStatusForLaunch launch

issueImplementerRuntimeStatusForLaunch :: IssueImplementerLaunchPlan -> IO WatcherRuntimeStatus
issueImplementerRuntimeStatusForLaunch launch = do
  let repo = launch.launchIssueConfig.issueRepo
      issueNumber' = launchIssueNumber launch
      eventsPath = stateDir </> "events.jsonl"
      configPath = stateDir </> "config.json"
      pidPath = WatcherPaths.defaultPidPathForKnownDomain (Proxy @'IssueImplement) stateDir
      stateDir = launch.launchStateDir
      issueClosed = githubIssueClosed repo issueNumber'
      statusConfig :: WatcherRuntimeStatusConfig 'IssueImplement
      statusConfig =
        WatcherRuntimeStatusConfig
          { watcherRuntimeConfigPath = configPath
          , watcherRuntimeEventsPath = eventsPath
          , watcherRuntimePidPath = pidPath
          , watcherRuntimeMissingIsTerminal = issueClosed
          , watcherRuntimeReplayTerminalIsTerminal = issueImplementReplayTerminalSucceeded repo issueNumber'
          }
  watcherRuntimeStatus
    statusConfig

firstChildStartProblem :: [IssueImplementerChildStartResult] -> Maybe (IssueNumber, Text.Text, WatcherRuntimeStatus)
firstChildStartProblem [] = Nothing
firstChildStartProblem (IssueImplementerChildStartProblem issue detail status : _) =
  Just (issue, detail, status)
firstChildStartProblem (_ : rest) =
  firstChildStartProblem rest

issueImplementReplayTerminalSucceeded :: RepoName -> IssueNumber -> EventReplayResult -> IO Bool
issueImplementReplayTerminalSucceeded repo issueNumber' replay =
  case replay.replayState of
    SomeWatcherState (CompleteState (IssueComplete _prNumber)) ->
      githubIssueClosed repo issueNumber'
    _ ->
      pure False

githubIssueClosed :: RepoName -> IssueNumber -> IO Bool
githubIssueClosed repo issueNumber' = do
  remoteIssue <- runGhIssueView ioRuntimeInterpreter repo issueNumber'
  case remoteIssue of
    Right issue ->
      pure (remoteIssueIsClosed issue)
    Left errorMessage -> do
      putStrLn ("planner could not verify issue " <> show (unIssueNumber issueNumber') <> " remote state: " <> Text.unpack errorMessage)
      pure False

launchIssueNumber :: IssueImplementerLaunchPlan -> IssueNumber
launchIssueNumber launch =
  case launch.launchIssueConfig of
    IssueConfig _ issue _ -> issue
