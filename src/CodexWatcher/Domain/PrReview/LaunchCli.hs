{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.Domain.PrReview.LaunchCli
  ( PrReviewWatcherLaunchPlan (..)
  , ensurePrReviewWatcherForHandoff
  , prReviewWatcherLaunchPlan
  , prReviewWatcherRuntimeStatus
  , launchPrReviewWatcher
  ) where

import CodexWatcher.ActionExecutor
import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.ChildDaemon
import CodexWatcher.Cli.Types
import CodexWatcher.Runtime.Compatibility
import CodexWatcher.Daemon (appendWatcherEvent)
import CodexWatcher.EventLog.Types
import CodexWatcher.Runtime.Defaults (defaultThreadStartOptions)
import CodexWatcher.Runtime.File (writeJsonValue)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Owner.Store (readRuntimeOwnerMarker)
import CodexWatcher.Runtime.Owner.Types (RuntimeLease (..), RuntimeOwner (..), RuntimeOwnerMarker (..))
import CodexWatcher.TurnOutput (prReviewThreadDeveloperInstructions)
import CodexWatcher.Core.Ids (BranchName (..), PrNumber (..), RepoName (..), RequestId (..), ThreadId (..))
import CodexWatcher.Core.Kinds (Domain (..), Phase (..))
import CodexWatcher.Core.Limits (PollSeconds)
import CodexWatcher.Core.Reason (BlockedReason (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), somePhaseIs)
import CodexWatcher.Core.Thread (ReviewerThread (..), WorkerThread (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.PrReview.Types (PrConfig (..))
import CodexWatcher.Runtime.WatcherPaths qualified as WatcherPaths
import CodexWatcher.WatcherRuntimeStatus
import Control.Monad (when)
import Data.Aeson (Value, object, (.=))
import Data.Proxy (Proxy (..))
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesFileExist, removeFile)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))

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

ensurePrReviewWatcherForHandoff :: LoopCli -> AppServerEndpoint -> ActionExecutionMode -> IssueConfig -> PrNumber -> IO (Maybe BlockedReason)
ensurePrReviewWatcherForHandoff cli endpoint executionMode issueConfig prNumber = do
  let launch = prReviewWatcherLaunchPlan (prReviewWatchersRootForIssueStateDir cli.loopCliStateDir) cli.loopCliWorkdir issueConfig prNumber
  status <- prReviewWatcherRuntimeStatus launch.reviewLaunchStateDir
  case status of
    WatcherMissing -> do
      launchPrReviewWatcher executionMode (Just endpoint) cli.loopCliPollSeconds launch
      pure Nothing
    WatcherActiveStopped -> do
      startPrReviewWatcherChild endpoint cli.loopCliPollSeconds launch
      pure Nothing
    WatcherActiveRunning -> do
      putStrLn ("PR review watcher already running for #" <> show (unPrNumber prNumber))
      pure Nothing
    WatcherTerminal TerminalComplete -> do
      putStrLn ("PR review watcher already terminal for #" <> show (unPrNumber prNumber))
      pure Nothing
    WatcherTerminal (TerminalBlocked reason) ->
      pure (Just (BlockedReason ("child PR review watcher blocked: " <> reason)))
    WatcherTerminal (TerminalStopped reason) ->
      pure (Just (BlockedReason ("child PR review watcher stopped: " <> reason)))

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

launchPrReviewWatcher :: ActionExecutionMode -> Maybe AppServerEndpoint -> PollSeconds -> PrReviewWatcherLaunchPlan -> IO ()
launchPrReviewWatcher DryRunActions maybeEndpoint pollSeconds launch = do
  printPrReviewWatcherLaunch launch
  maybe (pure ()) (\endpoint -> printPrReviewWatcherChildLaunch endpoint pollSeconds launch) maybeEndpoint
launchPrReviewWatcher ExecuteActions maybeEndpoint pollSeconds launch = do
  ensurePrReviewWatcherLaunchWritable launch
  writePrReviewWatcherLaunchPending launch
  preparedLaunch <- preparePrReviewWatcherLaunch maybeEndpoint launch
  writePrReviewWatcherLaunch preparedLaunch
  writePrReviewWatcherLaunchFinalized preparedLaunch
  maybe (pure ()) (\endpoint -> startPrReviewWatcherChild endpoint pollSeconds preparedLaunch) maybeEndpoint

preparePrReviewWatcherLaunch :: Maybe AppServerEndpoint -> PrReviewWatcherLaunchPlan -> IO PrReviewWatcherLaunchPlan
preparePrReviewWatcherLaunch Nothing launch =
  pure launch
preparePrReviewWatcherLaunch (Just endpoint) launch = do
  workerThread <- startPrReviewThread endpoint (RequestId 9000) launch "worker"
  reviewerThread <- startPrReviewThread endpoint (RequestId 9001) launch "reviewer"
  pure (withPrReviewThreadIds workerThread reviewerThread launch)

startPrReviewThread :: AppServerEndpoint -> RequestId -> PrReviewWatcherLaunchPlan -> Text.Text -> IO ThreadId
startPrReviewThread endpoint requestId launch role = do
  result <-
    startThreadWithEndpoint
      endpoint
      defaultAppServerClientOptions
      requestId
      (prReviewThreadStartOptions launch role)
  case result of
    Left failure -> die (Text.unpack (formatAppServerClientFailure failure))
    Right threadId -> pure threadId

prReviewThreadStartOptions :: PrReviewWatcherLaunchPlan -> Text.Text -> ThreadStartOptions
prReviewThreadStartOptions launch role =
  defaultThreadStartOptions
    launch.reviewLaunchWorkdir
    (prReviewThreadDeveloperInstructions launch.reviewLaunchWorkdir launch.reviewLaunchStateDir launch.reviewLaunchPrConfig role)

writePrReviewWatcherLaunch :: PrReviewWatcherLaunchPlan -> IO ()
writePrReviewWatcherLaunch launch = do
  ensurePrReviewWatcherLaunchStateEmpty launch
  createDirectoryIfMissing True launch.reviewLaunchStateDir
  writeJsonValue launch.reviewLaunchConfigPath launch.reviewLaunchConfigJson
  appendWatcherEvent ioRuntimeInterpreter launch.reviewLaunchEventsPath launch.reviewLaunchInitialEvent
  mapM_ (writeCompatibility ioRuntimeInterpreter) launch.reviewLaunchCompatibilityWrites
  putStrLn ("wrote PR review watcher " <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber) <> " to " <> launch.reviewLaunchStateDir)

ensurePrReviewWatcherLaunchWritable :: PrReviewWatcherLaunchPlan -> IO ()
ensurePrReviewWatcherLaunchWritable launch = do
  ensurePrReviewWatcherLaunchStateEmpty launch
  pendingExists <- doesFileExist (launchPendingManifestPath launch.reviewLaunchStateDir)
  when pendingExists $
    die
      ( "refusing to overwrite pending PR review watcher launch state: "
          <> launch.reviewLaunchStateDir
          <> "; inspect or remove "
          <> launchPendingManifestPath launch.reviewLaunchStateDir
          <> " before retrying"
      )

ensurePrReviewWatcherLaunchStateEmpty :: PrReviewWatcherLaunchPlan -> IO ()
ensurePrReviewWatcherLaunchStateEmpty launch = do
  configExists <- doesFileExist launch.reviewLaunchConfigPath
  eventsExists <- doesFileExist launch.reviewLaunchEventsPath
  finalizedExists <- doesFileExist (launchFinalizedManifestPath launch.reviewLaunchStateDir)
  when (configExists || eventsExists || finalizedExists) $
    die ("refusing to overwrite existing PR review watcher state: " <> launch.reviewLaunchStateDir)

writePrReviewWatcherLaunchPending :: PrReviewWatcherLaunchPlan -> IO ()
writePrReviewWatcherLaunchPending launch =
  writeJsonValue
    (launchPendingManifestPath launch.reviewLaunchStateDir)
    (prReviewLaunchManifest "pending" launch)

writePrReviewWatcherLaunchFinalized :: PrReviewWatcherLaunchPlan -> IO ()
writePrReviewWatcherLaunchFinalized launch = do
  writeJsonValue
    (launchFinalizedManifestPath launch.reviewLaunchStateDir)
    (prReviewLaunchManifest "finalized" launch)
  pendingExists <- doesFileExist (launchPendingManifestPath launch.reviewLaunchStateDir)
  when pendingExists (removeFile (launchPendingManifestPath launch.reviewLaunchStateDir))

prReviewLaunchManifest :: Text.Text -> PrReviewWatcherLaunchPlan -> Value
prReviewLaunchManifest status launch =
  object
    [ "status" .= status
    , "launchKind" .= ("pr-review" :: Text.Text)
    , "repo" .= unRepoName launch.reviewLaunchPrConfig.prRepo
    , "prNumber" .= unPrNumber launch.reviewLaunchPrConfig.prNumber
    , "workdir" .= launch.reviewLaunchWorkdir
    , "stateDir" .= launch.reviewLaunchStateDir
    , "configPath" .= launch.reviewLaunchConfigPath
    , "eventsPath" .= launch.reviewLaunchEventsPath
    , "intendedThreadRoles" .= (["worker", "reviewer"] :: [Text.Text])
    , "workerThreadId" .= unThreadId launch.reviewLaunchWorkerThreadId
    , "reviewerThreadId" .= unThreadId launch.reviewLaunchReviewerThreadId
    , "childLaunch" .= ("start" :: Text.Text)
    , "createdAt" .= ("unknown" :: Text.Text)
    ]

launchPendingManifestPath :: FilePath -> FilePath
launchPendingManifestPath stateDir =
  stateDir </> "launch-pending.json"

launchFinalizedManifestPath :: FilePath -> FilePath
launchFinalizedManifestPath stateDir =
  stateDir </> "launch-finalized.json"

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

printPrReviewWatcherChildLaunch :: AppServerEndpoint -> PollSeconds -> PrReviewWatcherLaunchPlan -> IO ()
printPrReviewWatcherChildLaunch endpoint pollSeconds launch = do
  executable <- stableExecutablePath
  putStrLn ("PR review child command: " <> unwords (executable : prReviewWatcherChildArgs endpoint pollSeconds launch))

startPrReviewWatcherChild :: AppServerEndpoint -> PollSeconds -> PrReviewWatcherLaunchPlan -> IO ()
startPrReviewWatcherChild endpoint pollSeconds launch = do
  liveOwner <- livePrReviewRuntimeOwnerPid launch.reviewLaunchStateDir
  case liveOwner of
    Just pidText -> do
      restoreOwnedPidFile (launch.reviewLaunchStateDir </> "watcher.pid") pidText
      putStrLn ("PR review watcher " <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber) <> " already running under runtime owner pid " <> Text.unpack pidText)
    Nothing ->
      startChildDaemon
        ( "PR review watcher "
            <> show (unPrNumber launch.reviewLaunchPrConfig.prNumber)
        )
        launch.reviewLaunchStateDir
        "watcher.pid"
        (prReviewWatcherChildArgs endpoint pollSeconds launch)

livePrReviewRuntimeOwnerPid :: FilePath -> IO (Maybe Text.Text)
livePrReviewRuntimeOwnerPid stateDir = do
  marker <- readRuntimeOwnerMarker stateDir
  case marker of
    Right (Just (RuntimeOwnerLeased lease))
      | lease.runtimeLeaseOwner == HaskellRuntime -> do
          running <- isPidRunning lease.runtimeLeasePid
          pure if running then Just lease.runtimeLeasePid else Nothing
    _ ->
      pure Nothing

prReviewWatcherChildArgs :: AppServerEndpoint -> PollSeconds -> PrReviewWatcherLaunchPlan -> [String]
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
  , "--pid-file"
  , launch.reviewLaunchStateDir </> "watcher.pid"
  ]
    <> if endpoint.appServerPath == "/" then [] else ["--app-server-path", endpoint.appServerPath]

prReviewWatcherRuntimeStatus :: FilePath -> IO WatcherRuntimeStatus
prReviewWatcherRuntimeStatus stateDir = do
  let configPath = stateDir </> "config.json"
      eventsPath = stateDir </> "events.jsonl"
      pidPath = WatcherPaths.defaultPidPathForKnownDomain (Proxy @'PrReview) stateDir
      statusConfig :: WatcherRuntimeStatusConfig 'PrReview
      statusConfig =
        WatcherRuntimeStatusConfig
          { watcherRuntimeConfigPath = configPath
          , watcherRuntimeEventsPath = eventsPath
          , watcherRuntimePidPath = pidPath
          , watcherRuntimeMissingIsTerminal = pure False
          , watcherRuntimeReplayTerminalIsTerminal = \replay -> pure (somePhaseIs @'Complete replay.replayState)
          }
  watcherRuntimeStatus
    statusConfig
