{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Healthcheck
  ( HealthcheckOptions (..)
  , runHealthcheck
  ) where

import CodexWatcher.AppServerClient
import CodexWatcher.AppServerProtocol
import CodexWatcher.EventLog
import CodexWatcher.Runtime
import CodexWatcher.Types (BranchName (..), Domain (..), PrNumber (..), RepoName (..), ThreadId (..), TurnId (..), someDomain, somePhase)
import Control.Applicative ((<|>))
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , Value (..)
  , eitherDecodeStrict'
  , encode
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Map.Strict qualified as Map
import Data.Maybe (catMaybes, fromMaybe, isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding
import Data.Time (getCurrentTime)
import GHC.Generics (Generic)
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath ((</>))
import System.IO.Error (isDoesNotExistError)

data HealthcheckOptions = HealthcheckOptions
  { stateRoot :: FilePath
  , repoFilter :: Maybe Text
  , appServerEndpoint :: Maybe AppServerEndpoint
  }
  deriving stock (Eq, Show, Generic)

data WatcherKind
  = IssuePlanningKind
  | IssueImplementKind
  | PrReviewKind
  deriving stock (Eq, Ord, Show, Generic)

instance ToJSON WatcherKind where
  toJSON = String . \case
    IssuePlanningKind -> "issue-planning"
    IssueImplementKind -> "issue-implement"
    PrReviewKind -> "pr-review"

data GenericConfig = GenericConfig
  { repoFullName :: Maybe Text
  , issueNumber :: Maybe Int
  , prNumber :: Maybe Int
  , branch :: Maybe Text
  , workdir :: Maybe FilePath
  , stateDir :: Maybe FilePath
  , pidPath :: Maybe FilePath
  , eventsPath :: Maybe FilePath
  , threadId :: Maybe Text
  , reviewerThreadId :: Maybe Text
  , reviewWhenClean :: Maybe Bool
  , maxParallel :: Maybe Int
  , handoffReview :: Maybe Bool
  , runtimeOwner :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON GenericConfig where
  parseJSON = withObject "GenericConfig" \object' ->
    GenericConfig
      <$> object' .:? "repoFullName"
      <*> object' .:? "issueNumber"
      <*> object' .:? "prNumber"
      <*> object' .:? "branch"
      <*> object' .:? "workdir"
      <*> object' .:? "stateDir"
      <*> object' .:? "pidPath"
      <*> object' .:? "eventsPath"
      <*> object' .:? "threadId"
      <*> object' .:? "reviewerThreadId"
      <*> object' .:? "reviewWhenClean"
      <*> object' .:? "maxParallel"
      <*> object' .:? "handoffReview"
      <*> object' .:? "runtimeOwner"

data ConfigItem = ConfigItem
  { kind :: WatcherKind
  , dir :: FilePath
  , configPath :: FilePath
  , config :: Either Text GenericConfig
  }
  deriving stock (Eq, Show, Generic)

data WorkdirReport = WorkdirReport
  { skipped :: Bool
  , reason :: Maybe Text
  , path :: Maybe FilePath
  , exists :: Bool
  , isGitCheckout :: Bool
  , currentBranch :: Maybe Text
  , headSha :: Maybe Text
  , remoteHeadSha :: Maybe Text
  , localDiffersFromRemote :: Bool
  , dirty :: Bool
  , dirtyStatus :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data EventReplayReport = EventReplayReport
  { skipped :: Bool
  , ok :: Bool
  , reason :: Maybe Text
  , eventsPath :: Maybe FilePath
  , domain :: Maybe Text
  , phase :: Maybe Text
  , eventCount :: Maybe Int
  , effectBatchCount :: Maybe Int
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data RemotePrReport = RemotePrReport
  { skipped :: Bool
  , ok :: Bool
  , errorMessage :: Maybe Text
  , raw :: Value
  , merged :: Bool
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data PidReport = PidReport
  { pidPath :: FilePath
  , pid :: Maybe Text
  , running :: Bool
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data AppServerThreadReport = AppServerThreadReport
  { skipped :: Bool
  , ok :: Bool
  , threadId :: Maybe Text
  , reason :: Maybe Text
  , turnCount :: Maybe Int
  , latestTurnId :: Maybe Text
  , latestTurnStatus :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data WatcherSummary = WatcherSummary
  { kind :: WatcherKind
  , label :: Text
  , configPath :: FilePath
  , configLoadError :: Maybe Text
  , repoFullName :: Maybe Text
  , issueNumber :: Maybe Int
  , prNumber :: Maybe Int
  , branch :: Maybe Text
  , workdirPath :: Maybe FilePath
  , threadId :: Maybe Text
  , reviewerThreadId :: Maybe Text
  , reviewWhenClean :: Maybe Bool
  , maxParallel :: Maybe Int
  , runtimeOwner :: Maybe Text
  , pid :: PidReport
  , issueStatus :: Maybe Text
  , blocked :: Bool
  , blockedReason :: Maybe Text
  , workdir :: WorkdirReport
  , gitPushDryRun :: CommandReport
  , remotePr :: RemotePrReport
  , eventReplay :: EventReplayReport
  , workerThreadInspection :: AppServerThreadReport
  , reviewerThreadInspection :: AppServerThreadReport
  , states :: Value
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

data Problem = Problem
  { severity :: Text
  , component :: Text
  , message :: Text
  , recommendation :: Maybe Text
  }
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

runHealthcheck :: HealthcheckOptions -> IO ()
runHealthcheck options = do
  inventory <- loadInventory options
  summaries <- traverse (summarizeItem options) inventory
  commands <- environmentCommands
  ghAuth <- runRuntimeCommand GhAuthStatus
  ghUser <- githubUserReport
  checkedAt <- Text.pack . show <$> getCurrentTime
  let problems =
        commandProblems commands ghAuth
          <> concatMap analyzeItem summaries
          <> analyzeCrossItemRules summaries
      report =
        object
          [ "checkedAt" .= checkedAt
          , "repoFilter" .= options.repoFilter
          , "status" .= statusSeverity problems
          , "summary" .= summaryObject summaries
          , "commands" .= commands
          , "githubCli" .= object ["authOk" .= ghAuth.ok, "authStatus" .= commandText ghAuth, "user" .= ghUser]
          , "watchers" .= summaries
          , "problems" .= problems
          , "logicReview" .= logicReview
          ]
  LazyByteString.putStrLn (encode report)

defaultStateRoot :: FilePath
defaultStateRoot = "/workspace/artifacts"

loadInventory :: HealthcheckOptions -> IO [ConfigItem]
loadInventory options = do
  let root = if null options.stateRoot then defaultStateRoot else options.stateRoot
  concat
    <$> sequence
      [ loadConfigs IssuePlanningKind (root </> "issue-planners") options.repoFilter
      , loadConfigs IssueImplementKind (root </> "issue-implementers") options.repoFilter
      , loadConfigs PrReviewKind (root </> "pr-review-watchers") options.repoFilter
      ]

loadConfigs :: WatcherKind -> FilePath -> Maybe Text -> IO [ConfigItem]
loadConfigs kind root repoFilter' = do
  dirs <- listConfigDirs root
  fmap catMaybes $
    traverse
      ( \dir -> do
          let configPath = dir </> "config.json"
          exists <- doesFileExist configPath
          if not exists
            then pure Nothing
            else do
              decoded <- decodeConfig configPath
              let include =
                    case (repoFilter', decoded) of
                      (Nothing, _) -> True
                      (Just expected, Right config) -> config.repoFullName == Just expected
                      (Just _, Left _) -> False
              pure if include then Just ConfigItem {kind, dir, configPath, config = decoded} else Nothing
      )
      dirs

decodeConfig :: FilePath -> IO (Either Text GenericConfig)
decodeConfig path = do
  bytesResult <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case bytesResult of
    Left error' -> Left (Text.pack (show error'))
    Right bytes -> either (Left . Text.pack) Right (eitherDecodeStrict' bytes)

listConfigDirs :: FilePath -> IO [FilePath]
listConfigDirs root = do
  exists <- doesDirectoryExist root
  if not exists
    then pure []
    else do
      entriesResult <- try (listDirectory root) :: IO (Either IOException [FilePath])
      case entriesResult of
        Left error'
          | isDoesNotExistError error' -> pure []
          | otherwise -> pure []
        Right entries -> do
          let dirs = fmap (root </>) entries
          filterM doesDirectoryExist dirs

summarizeItem :: HealthcheckOptions -> ConfigItem -> IO WatcherSummary
summarizeItem options item =
  case item.config of
    Left error' -> summarizeBrokenItem item error'
    Right config -> summarizeLoadedItem options item config

summarizeBrokenItem :: ConfigItem -> Text -> IO WatcherSummary
summarizeBrokenItem item error' = do
  let pid = PidReport (fallbackPidPath item.kind item.dir Nothing) Nothing False
  pure
    WatcherSummary
      { kind = item.kind
      , label = itemLabel item.kind Nothing Nothing Nothing
      , configPath = item.configPath
      , configLoadError = Just error'
      , repoFullName = Nothing
      , issueNumber = Nothing
      , prNumber = Nothing
      , branch = Nothing
      , workdirPath = Nothing
      , threadId = Nothing
      , reviewerThreadId = Nothing
      , reviewWhenClean = Nothing
      , maxParallel = Nothing
      , runtimeOwner = Nothing
      , pid
      , issueStatus = Nothing
      , blocked = False
      , blockedReason = Nothing
      , workdir = skippedWorkdir "config failed to load"
      , gitPushDryRun = skippedCommand "config failed to load"
      , remotePr = skippedRemotePr "config failed to load"
      , eventReplay = skippedEventReplay "config failed to load" Nothing
      , workerThreadInspection = skippedAppServerThread "config failed to load" Nothing
      , reviewerThreadInspection = skippedAppServerThread "config failed to load" Nothing
      , states = Null
      }

summarizeLoadedItem :: HealthcheckOptions -> ConfigItem -> GenericConfig -> IO WatcherSummary
summarizeLoadedItem options item config = do
  let stateDir' = fromMaybe item.dir config.stateDir
      pidPath' = fallbackPidPath item.kind stateDir' config.pidPath
      eventsPath' = config.eventsPath <|> Just (stateDir' </> "events.jsonl")
  pid <- readPid pidPath'
  states <- readStateFiles item.kind stateDir'
  let issueStatus' = lookupStateText ["issueState", "issue_status"] states
      blocked' = lookupStateBool ["blockedState", "blocked"] states
      blockedReason' = lookupStateText ["blockedState", "reason"] states
      runtimeOwner' = config.runtimeOwner <|> lookupStateText ["runtimeOwner", "owner"] states
  workdirReport <- checkWorkdir config
  gitPush <- checkGitPushDryRun config workdirReport
  remotePrReport <- checkRemotePr config
  eventReplayReport <- checkEventReplay item.kind eventsPath'
  workerThreadReport <- checkAppServerThread options.appServerEndpoint config.threadId
  reviewerThreadReport <- checkAppServerThread options.appServerEndpoint config.reviewerThreadId
  pure
    WatcherSummary
      { kind = item.kind
      , label = itemLabel item.kind config.repoFullName config.issueNumber config.prNumber
      , configPath = item.configPath
      , configLoadError = Nothing
      , repoFullName = config.repoFullName
      , issueNumber = config.issueNumber
      , prNumber = config.prNumber
      , branch = config.branch
      , workdirPath = config.workdir
      , threadId = config.threadId
      , reviewerThreadId = config.reviewerThreadId
      , reviewWhenClean = config.reviewWhenClean
      , maxParallel = config.maxParallel
      , runtimeOwner = runtimeOwner'
      , pid
      , issueStatus = issueStatus'
      , blocked = fromMaybe False blocked'
      , blockedReason = blockedReason'
      , workdir = workdirReport
      , gitPushDryRun = gitPush
      , remotePr = remotePrReport
      , eventReplay = eventReplayReport
      , workerThreadInspection = workerThreadReport
      , reviewerThreadInspection = reviewerThreadReport
      , states
      }

readStateFiles :: WatcherKind -> FilePath -> IO Value
readStateFiles kind stateDir' =
  case kind of
    IssuePlanningKind -> object
      <$> sequence
        [ "daemonState" .=? readOptionalValueFile (stateDir' </> "daemon-state.json")
        , "plannerState" .=? readOptionalValueFile (stateDir' </> "planner-state.json")
        , "blockedState" .=? readOptionalValueFile (stateDir' </> "block-state.json")
        , "runtimeOwner" .=? readOptionalValueFile (stateDir' </> "runtime-owner.json")
        ]
    IssueImplementKind -> object
      <$> sequence
        [ "daemonState" .=? readOptionalValueFile (stateDir' </> "daemon-state.json")
        , "issueState" .=? readOptionalValueFile (stateDir' </> "issue-state.json")
        , "blockedState" .=? readOptionalValueFile (stateDir' </> "block-state.json")
        , "runtimeOwner" .=? readOptionalValueFile (stateDir' </> "runtime-owner.json")
        ]
    PrReviewKind -> object
      <$> sequence
        [ "watcherState" .=? readOptionalValueFile (stateDir' </> "watcher-state.json")
        , "checkerState" .=? readOptionalValueFile (stateDir' </> "checker-state.json")
        , "agentState" .=? readOptionalValueFile (stateDir' </> "agent-state.json")
        , "reviewerState" .=? readOptionalValueFile (stateDir' </> "reviewer-state.json")
        , "blockedState" .=? readOptionalValueFile (stateDir' </> "block-state.json")
        , "runtimeOwner" .=? readOptionalValueFile (stateDir' </> "runtime-owner.json")
        ]
 where
  key .=? action = do
    value <- action
    pure (key .= fromMaybe Null value)

readOptionalValueFile :: FilePath -> IO (Maybe Value)
readOptionalValueFile path = do
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else either (const Nothing) Just <$> readJsonValue path

fallbackPidPath :: WatcherKind -> FilePath -> Maybe FilePath -> FilePath
fallbackPidPath kind stateDir' configured =
  fromMaybe (stateDir' </> pidName kind) configured
 where
  pidName = \case
    IssuePlanningKind -> "issue-planning-watcher.pid"
    IssueImplementKind -> "issue-watcher.pid"
    PrReviewKind -> "watcher.pid"

readPid :: FilePath -> IO PidReport
readPid pidPath = do
  contents <- readTextFileMaybe pidPath
  let pid' = Text.strip <$> contents
  running <- maybe (pure False) isProcessAlive pid'
  pure PidReport {pidPath, pid = emptyToNothing =<< pid', running}

isProcessAlive :: Text -> IO Bool
isProcessAlive pid' = do
  result <- runRuntimeCommand (KillZero pid')
  pure result.ok

checkWorkdir :: GenericConfig -> IO WorkdirReport
checkWorkdir config =
  case config.workdir of
    Nothing -> pure (skippedWorkdir "config has no workdir")
    Just path' -> do
      exists <- doesDirectoryExist path'
      gitDir <- doesDirectoryExist (path' </> ".git")
      gitFile <- doesFileExist (path' </> ".git")
      let isGit = gitDir || gitFile
      branchReport <- if isGit then runRuntimeCommand (GitBranchCurrent path') else pure (skippedCommand "not a git checkout")
      headReport <- if isGit then runRuntimeCommand (GitRevParseHead path') else pure (skippedCommand "not a git checkout")
      dirtyReport <- if isGit then runRuntimeCommand (GitStatusPorcelain path') else pure (skippedCommand "not a git checkout")
      remoteReport <-
        case (isGit, config.branch) of
          (True, Just branchName) -> runRuntimeCommand (GitLsRemoteBranch path' (BranchName branchName))
          _ -> pure (skippedCommand "missing branch or git checkout")
      let headSha' = emptyToNothing headReport.stdout
          remoteSha = parseRemoteSha remoteReport.stdout
      pure
        WorkdirReport
          { skipped = False
          , reason = Nothing
          , path = Just path'
          , exists
          , isGitCheckout = isGit
          , currentBranch = emptyToNothing branchReport.stdout
          , headSha = headSha'
          , remoteHeadSha = remoteSha
          , localDiffersFromRemote = isJust headSha' && isJust remoteSha && headSha' /= remoteSha
          , dirty = maybe False (not . Text.null) (emptyToNothing dirtyReport.stdout)
          , dirtyStatus = emptyToNothing dirtyReport.stdout
          }

checkGitPushDryRun :: GenericConfig -> WorkdirReport -> IO CommandReport
checkGitPushDryRun config workdirReport =
  case (config.workdir, config.branch, workdirReport.isGitCheckout) of
    (Just path', Just branchName, True) ->
      runRuntimeCommand (GitPushDryRun path' (BranchName branchName))
    _ -> pure (skippedCommand "missing branch or git checkout")

checkRemotePr :: GenericConfig -> IO RemotePrReport
checkRemotePr config =
  case (config.repoFullName, config.prNumber) of
    (Just repo, Just prNumber') -> do
      report <-
        runRuntimeCommand
          ( GhPrView
              (RepoName repo)
              (PrNumber prNumber')
              ["state", "mergedAt", "mergeCommit", "url", "headRefOid"]
          )
      if not report.ok
        then pure RemotePrReport {skipped = False, ok = False, errorMessage = Just (commandText report), raw = Null, merged = False}
        else do
          let parsed = eitherDecodeStrict' (Text.Encoding.encodeUtf8 report.stdout) :: Either String Value
          pure case parsed of
            Left error' -> RemotePrReport {skipped = False, ok = False, errorMessage = Just (Text.pack error'), raw = Null, merged = False}
            Right value -> RemotePrReport {skipped = False, ok = True, errorMessage = Nothing, raw = value, merged = remotePrMerged value}
    _ -> pure (skippedRemotePr "not a PR watcher")

checkEventReplay :: WatcherKind -> Maybe FilePath -> IO EventReplayReport
checkEventReplay kind (Just path') = do
  exists <- doesFileExist path'
  if not exists
    then pure (skippedEventReplay "events log does not exist" (Just path'))
    else do
      loaded <- loadEventLogFile path'
      pure case loaded of
        Left error' -> failedEventReplay path' (Text.pack error')
        Right events ->
          case replayEventLog events of
            Left failure -> failedEventReplay path' (Text.pack (formatReplayFailureForHealthcheck failure))
            Right replay
              | someDomain replay.replayState /= expectedDomain kind ->
                  failedEventReplay
                    path'
                    ( "events replayed as "
                        <> Text.pack (show (someDomain replay.replayState))
                        <> " but config is "
                        <> Text.pack (show kind)
                    )
              | otherwise ->
                  EventReplayReport
                    { skipped = False
                    , ok = True
                    , reason = Nothing
                    , eventsPath = Just path'
                    , domain = Just (Text.pack (show (someDomain replay.replayState)))
                    , phase = Just (Text.pack (show (somePhase replay.replayState)))
                    , eventCount = Just (length events)
                    , effectBatchCount = Just (length replay.replayEffects)
                    }
checkEventReplay _ Nothing = pure (skippedEventReplay "missing eventsPath" Nothing)

checkAppServerThread :: Maybe AppServerEndpoint -> Maybe Text -> IO AppServerThreadReport
checkAppServerThread Nothing maybeThreadId =
  pure (skippedAppServerThread "healthcheck app-server endpoint not configured" maybeThreadId)
checkAppServerThread (Just _endpoint) Nothing =
  pure (skippedAppServerThread "config has no thread id" Nothing)
checkAppServerThread (Just endpoint) (Just threadId') = do
  result <-
    sendOneAppServerRequest
      endpoint
      defaultAppServerClientOptions {appServerResponseTimeoutMicros = Just 5000000}
      (threadReadRequest 9001 (ThreadId threadId') True)
  pure case result of
    Left failure ->
      failedAppServerThread threadId' (formatAppServerClientFailure failure)
    Right value ->
      case parseThreadReadTurns value of
        Left failure -> failedAppServerThread threadId' (formatAppServerClientFailure failure)
        Right turns ->
          let latestTurn = lastMaybe turns
           in AppServerThreadReport
                { skipped = False
                , ok = True
                , threadId = Just threadId'
                , reason = Nothing
                , turnCount = Just (length turns)
                , latestTurnId = fmap (unTurnId . appServerTurnId) latestTurn
                , latestTurnStatus = fmap appServerTurnStatus latestTurn
                }

failedAppServerThread :: Text -> Text -> AppServerThreadReport
failedAppServerThread threadId' reason' =
  AppServerThreadReport
    { skipped = False
    , ok = False
    , threadId = Just threadId'
    , reason = Just reason'
    , turnCount = Nothing
    , latestTurnId = Nothing
    , latestTurnStatus = Nothing
    }

expectedDomain :: WatcherKind -> Domain
expectedDomain IssuePlanningKind = IssuePlanning
expectedDomain IssueImplementKind = IssueImplement
expectedDomain PrReviewKind = PrReview

failedEventReplay :: FilePath -> Text -> EventReplayReport
failedEventReplay path' reason' =
  EventReplayReport
    { skipped = False
    , ok = False
    , reason = Just reason'
    , eventsPath = Just path'
    , domain = Nothing
    , phase = Nothing
    , eventCount = Nothing
    , effectBatchCount = Nothing
    }

environmentCommands :: IO Value
environmentCommands = do
  git <- checkCommand "git"
  gh <- checkCommand "gh"
  cabal <- checkCommand "cabal"
  ghc <- checkCommand "ghc"
  ghcup <- checkCommand "ghcup"
  let reports =
        [ ("git", git)
        , ("gh", gh)
        , ("cabal", cabal)
        , ("ghc", ghc)
        , ("ghcup", ghcup)
        ]
  pure (object (fmap (\(key, report) -> key .= report) reports))

checkCommand :: String -> IO CommandReport
checkCommand command = runRuntimeCommand (CommandVersion command)

githubUserReport :: IO Value
githubUserReport = do
  report <- runRuntimeCommand GhApiUser
  if not report.ok
    then pure (object ["ok" .= False, "error" .= commandText report])
    else
      pure case eitherDecodeStrict' (Text.Encoding.encodeUtf8 report.stdout) of
        Left error' -> object ["ok" .= False, "error" .= Text.pack error']
        Right (Object object') ->
          object
            [ "ok" .= True
            , "login" .= KeyMap.lookup "login" object'
            , "id" .= KeyMap.lookup "id" object'
            , "name" .= KeyMap.lookup "name" object'
            ]
        Right value -> object ["ok" .= True, "raw" .= value]

analyzeItem :: WatcherSummary -> [Problem]
analyzeItem summary =
  concat
    [ [problem (blockedSeverity summary) summary.label ("blocked: " <> fromMaybe "no reason recorded" summary.blockedReason) Nothing | summary.blocked]
    , [problem "error" summary.label "config failed to load" summary.configLoadError | isJust summary.configLoadError]
    , analyzePlanning summary
    , analyzeImplement summary
    , analyzePrReview summary
    ]

analyzePlanning :: WatcherSummary -> [Problem]
analyzePlanning summary
  | summary.kind /= IssuePlanningKind = []
  | otherwise =
      [problem "error" summary.label "missing planner threadId" (Just "create a Codex planner thread, then run run-issue-planning with --planner-thread-id") | summary.threadId == Nothing]
        <> [problem "error" summary.label "maxParallel is less than 1" Nothing | maybe False (< 1) summary.maxParallel]

analyzeImplement :: WatcherSummary -> [Problem]
analyzeImplement summary
  | summary.kind /= IssueImplementKind = []
  | otherwise =
      [problem "error" summary.label "missing worker threadId" (Just "create a Codex worker thread or rehearse legacy state before run-issue-implement --execute") | summary.threadId == Nothing]
        <> workdirProblems summary
        <> [problem "warn" summary.label "workdir has uncommitted changes" Nothing | summary.workdir.dirty]
        <> [problem "warn" summary.label ("git push dry-run failed: " <> commandText summary.gitPushDryRun) Nothing | shouldWarnGitPush summary.gitPushDryRun]
        <> [problem "warn" summary.label ("issue status is " <> status <> " but daemon is not running") Nothing | Just status <- [summary.issueStatus], status `elem` activeIssueStatuses, not summary.pid.running]
        <> appServerThreadProblems summary.label "worker" summary.workerThreadInspection

analyzePrReview :: WatcherSummary -> [Problem]
analyzePrReview summary
  | summary.kind /= PrReviewKind = []
  | otherwise =
      [problem "error" summary.label "missing PR worker threadId" (Just "create a Codex worker thread or rehearse legacy state before run-pr-review --execute") | summary.threadId == Nothing]
        <> [problem "error" summary.label "reviewWhenClean is enabled but reviewerThreadId is missing" Nothing | summary.reviewWhenClean /= Just False && summary.reviewerThreadId == Nothing]
        <> workdirProblems summary
        <> [problem "warn" summary.label "workdir has uncommitted changes" Nothing | summary.workdir.dirty]
        <> [problem "warn" summary.label "local HEAD differs from remote branch head" Nothing | summary.workdir.localDiffersFromRemote]
        <> [problem "warn" summary.label ("git push dry-run failed: " <> commandText summary.gitPushDryRun) Nothing | shouldWarnGitPush summary.gitPushDryRun]
        <> [problem "warn" summary.label ("cannot read remote PR state: " <> fromMaybe "unknown" summary.remotePr.errorMessage) Nothing | not summary.remotePr.skipped && not summary.remotePr.ok]
        <> [problem "error" summary.label ("events.jsonl failed Haskell replay: " <> fromMaybe "unknown" summary.eventReplay.reason) Nothing | not summary.eventReplay.skipped && not summary.eventReplay.ok]
        <> appServerThreadProblems summary.label "worker" summary.workerThreadInspection
        <> appServerThreadProblems summary.label "reviewer" summary.reviewerThreadInspection

appServerThreadProblems :: Text -> Text -> AppServerThreadReport -> [Problem]
appServerThreadProblems label role report =
  [ problem "warn" label ("app-server " <> role <> " thread inspection failed: " <> fromMaybe "unknown" report.reason) Nothing
  | not report.skipped
  , not report.ok
  ]

workdirProblems :: WatcherSummary -> [Problem]
workdirProblems summary =
  [problem "error" summary.label ("workdir missing: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], not summary.workdir.exists]
    <> [problem "error" summary.label ("workdir is not a git checkout: " <> Text.pack path') Nothing | Just path' <- [summary.workdir.path], summary.workdir.exists, not summary.workdir.isGitCheckout]

analyzeCrossItemRules :: [WatcherSummary] -> [Problem]
analyzeCrossItemRules summaries =
  duplicateActiveImplementerProblems summaries
    <> duplicateRunningPrWatcherProblems summaries
    <> duplicateWorkdirProblems summaries
    <> maxParallelProblems summaries

duplicateActiveImplementerProblems :: [WatcherSummary] -> [Problem]
duplicateActiveImplementerProblems summaries =
  [ problem "error" key ("multiple active implementers own the same issue: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy activeIssueKey summaries
  ]
 where
  activeIssueKey summary
    | isActiveImplementer summary = (\repo issue -> repo <> "#" <> Text.pack (show issue)) <$> summary.repoFullName <*> summary.issueNumber
    | otherwise = Nothing

duplicateRunningPrWatcherProblems :: [WatcherSummary] -> [Problem]
duplicateRunningPrWatcherProblems summaries =
  [ problem "error" key ("multiple running review watchers own the same PR: " <> Text.intercalate ", " labels) Nothing
  | (key, labels) <- duplicateLabelsBy runningPrKey summaries
  ]
 where
  runningPrKey summary
    | summary.kind == PrReviewKind && summary.pid.running = (\repo pr -> repo <> "#" <> Text.pack (show pr)) <$> summary.repoFullName <*> summary.prNumber
    | otherwise = Nothing

duplicateWorkdirProblems :: [WatcherSummary] -> [Problem]
duplicateWorkdirProblems summaries =
  [ problem "warn" workdir' ("workdir is shared by multiple configs: " <> Text.intercalate ", " labels) Nothing
  | (workdir', labels) <- duplicateLabelsBy (fmap Text.pack . workdirPath) summaries
  ]

maxParallelProblems :: [WatcherSummary] -> [Problem]
maxParallelProblems summaries =
  [ problem "warn" planner.label ("active implementers (" <> Text.pack (show activeCount) <> ") exceed maxParallel (" <> Text.pack (show maxParallel') <> ")") Nothing
  | planner <- summaries
  , planner.kind == IssuePlanningKind
  , Just repo <- [planner.repoFullName]
  , let maxParallel' = fromMaybe 8 planner.maxParallel
  , let activeCount = length [() | summary <- summaries, summary.repoFullName == Just repo, isActiveImplementer summary]
  , activeCount > maxParallel'
  ]

duplicateLabelsBy :: Ord key => (WatcherSummary -> Maybe key) -> [WatcherSummary] -> [(key, [Text])]
duplicateLabelsBy keyOf summaries =
  [ (key, labels)
  | (key, labels) <- Map.toList grouped
  , length labels > 1
  ]
 where
  grouped =
    Map.fromListWith
      (<>)
      [(key, [summary.label]) | summary <- summaries, Just key <- [keyOf summary]]

isActiveImplementer :: WatcherSummary -> Bool
isActiveImplementer summary =
  summary.kind == IssueImplementKind
    && (summary.pid.running || maybe False (`elem` activeIssueStatuses) summary.issueStatus)

activeIssueStatuses :: [Text]
activeIssueStatuses = ["needs_implementation", "plan_ready", "in_progress", "incomplete"]

blockedSeverity :: WatcherSummary -> Text
blockedSeverity summary
  | summary.kind == PrReviewKind && summary.remotePr.merged = "warn"
  | otherwise = "error"

shouldWarnGitPush :: CommandReport -> Bool
shouldWarnGitPush report =
  not report.ok && report.errorMessage /= Just "missing branch or git checkout" && report.errorMessage /= Just "not a git checkout"

commandProblems :: Value -> CommandReport -> [Problem]
commandProblems commands ghAuth =
  [problem "error" "environment" "git is not installed" Nothing | not (commandOk "git")]
    <> [problem "error" "environment" "GitHub CLI gh is not installed" Nothing | not (commandOk "gh")]
    <> [problem "error" "environment" ("gh auth status failed: " <> commandText ghAuth) Nothing | not ghAuth.ok]
 where
  commandOk key =
    case commands of
      Object object' ->
        case KeyMap.lookup (Key.fromString key) object' of
          Just (Object commandObject) ->
            KeyMap.lookup "ok" commandObject == Just (Bool True)
          _ -> False
      _ -> False

statusSeverity :: [Problem] -> Text
statusSeverity problems
  | any ((== "error") . (.severity)) problems = "fail"
  | any ((== "warn") . (.severity)) problems = "warn"
  | otherwise = "ok"

summaryObject :: [WatcherSummary] -> Value
summaryObject summaries =
  object
    [ "totalConfigs" .= length summaries
    , "planners" .= countKind IssuePlanningKind
    , "implementers" .= countKind IssueImplementKind
    , "reviewWatchers" .= countKind PrReviewKind
    , "runningDaemons" .= length [() | summary <- summaries, summary.pid.running]
    , "blockedConfigs" .= length [() | summary <- summaries, summary.blocked]
    , "activeImplementers" .= length [() | summary <- summaries, isActiveImplementer summary]
    ]
 where
  countKind kind' = length [() | summary <- summaries, summary.kind == kind']

logicReview :: Value
logicReview =
  object
    [ "checkedRules"
        .= [ "one active implementer per issue" :: Text
           , "one running review watcher per PR"
           , "planner maxParallel not exceeded"
           , "review/implement workdirs exist, are git checkouts, and are not dirty"
           , "gh-authenticated git push dry-run works for workdirs with branches"
           , "watcher events.jsonl can replay through the Haskell lifecycle model when present"
           , "configured app-server threads can be read when an app-server endpoint is provided"
           , "runtime-owner marker is surfaced for migration/backout visibility when present"
           , "blocked states are surfaced instead of retried forever"
           ]
    , "notes"
        .= [ "This Haskell healthcheck is read-only." :: Text
           , "It does not mutate GitHub, app-server threads, or local checkouts."
           , "App-server thread inspection is skipped unless --app-server-host and --app-server-port are provided."
           ]
    ]

problem :: Text -> Text -> Text -> Maybe Text -> Problem
problem severity component message recommendation =
  Problem {severity, component, message, recommendation}

itemLabel :: WatcherKind -> Maybe Text -> Maybe Int -> Maybe Int -> Text
itemLabel kind repo issue pr =
  case kind of
    IssuePlanningKind -> fromMaybe "unknown repo" repo <> " planner"
    IssueImplementKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) issue <> " implementer"
    PrReviewKind -> fromMaybe "unknown repo" repo <> "#" <> maybe "unknown" (Text.pack . show) pr <> " reviewer"

skippedWorkdir :: Text -> WorkdirReport
skippedWorkdir reason' =
  WorkdirReport
    { skipped = True
    , reason = Just reason'
    , path = Nothing
    , exists = False
    , isGitCheckout = False
    , currentBranch = Nothing
    , headSha = Nothing
    , remoteHeadSha = Nothing
    , localDiffersFromRemote = False
    , dirty = False
    , dirtyStatus = Nothing
    }

skippedRemotePr :: Text -> RemotePrReport
skippedRemotePr reason' =
  RemotePrReport {skipped = True, ok = False, errorMessage = Just reason', raw = Null, merged = False}

skippedEventReplay :: Text -> Maybe FilePath -> EventReplayReport
skippedEventReplay reason' path' =
  EventReplayReport
    { skipped = True
    , ok = False
    , reason = Just reason'
    , eventsPath = path'
    , domain = Nothing
    , phase = Nothing
    , eventCount = Nothing
    , effectBatchCount = Nothing
    }

skippedAppServerThread :: Text -> Maybe Text -> AppServerThreadReport
skippedAppServerThread reason' maybeThreadId =
  AppServerThreadReport
    { skipped = True
    , ok = True
    , threadId = maybeThreadId
    , reason = Just reason'
    , turnCount = Nothing
    , latestTurnId = Nothing
    , latestTurnStatus = Nothing
    }

remotePrMerged :: Value -> Bool
remotePrMerged (Object object') =
  KeyMap.lookup "state" object' == Just (String "MERGED")
    || case KeyMap.lookup "mergedAt" object' of
      Just (String text) -> not (Text.null text)
      _ -> False
remotePrMerged _ = False

lookupStateText :: [Text] -> Value -> Maybe Text
lookupStateText path' value =
  case lookupPath path' value of
    Just (String text) -> Just text
    _ -> Nothing

lookupStateBool :: [Text] -> Value -> Maybe Bool
lookupStateBool path' value =
  case lookupPath path' value of
    Just (Bool bool) -> Just bool
    _ -> Nothing

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (key : rest) (Object object') = KeyMap.lookup (Key.fromText key) object' >>= lookupPath rest
lookupPath _ _ = Nothing

parseRemoteSha :: Text -> Maybe Text
parseRemoteSha text =
  case Text.words text of
    sha : _ -> Just sha
    [] -> Nothing

lastMaybe :: [a] -> Maybe a
lastMaybe [] = Nothing
lastMaybe values = Just (last values)

readTextFileMaybe :: FilePath -> IO (Maybe Text)
readTextFileMaybe path = do
  result <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
  pure case result of
    Left _ -> Nothing
    Right bytes -> Just (Text.Encoding.decodeUtf8 bytes)

emptyToNothing :: Text -> Maybe Text
emptyToNothing text
  | Text.null (Text.strip text) = Nothing
  | otherwise = Just (Text.strip text)

formatReplayFailureForHealthcheck :: ReplayFailure -> String
formatReplayFailureForHealthcheck failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
