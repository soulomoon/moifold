{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Healthcheck
  ( HealthcheckOptions (..)
  , issueStatusRequiresDaemon
  , planningStatusRequiresDaemon
  , prReviewRequiresDaemon
  , warnIssueImplementDirtyWorkdir
  , warnPrReviewDirtyWorkdir
  , runHealthcheck
  ) where

import CodexWatcher.AppServerProtocol
import CodexWatcher.ChildDaemon (isPidRunning, readPidFile)
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.Healthcheck.Analysis
import CodexWatcher.Healthcheck.Types
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.Runtime.File (readJsonValue)
import CodexWatcher.Runtime.Json (commandJsonValue)
import CodexWatcher.Runtime.Process (runRuntimeCommand, skippedCommand)
import CodexWatcher.Core.State (SomeWatcherState, someDomain, somePhase)
import CodexWatcher.WatcherLiveness
import CodexWatcher.Workflow.Agent.Codex.Client (AppServerTurn (..), formatAppServerClientFailure, parseThreadReadTurns)
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerClientOptions (..), AppServerEndpoint, defaultAppServerClientOptions, sendOneAppServerRequest)
import CodexWatcher.Workflow.Agent.Ids (RequestId (..), ThreadId (..), TurnId (..))
import CodexWatcher.Runtime.WatcherPaths qualified as WatcherPaths
import CodexWatcher.Workflow.GitHub.Command qualified as GitHubCommand
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), CommitSha (..), PrNumber (..), RepoName (..))
import CodexWatcher.Workflow.GitHub.Remote (parseGhPrView, parseGitBranch, parseGitSha, parseLsRemoteBranch, remotePullRequestIsMerged)
import Control.Applicative ((<|>))
import Control.Exception (IOException, try)
import Control.Monad (filterM)
import Data.Aeson
  ( Value (..)
  , eitherDecodeStrict'
  , encode
  , object
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy.Char8 qualified as LazyByteString
import Data.Maybe (catMaybes, fromMaybe, isJust)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (getCurrentTime)
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath (takeFileName, (</>))
import System.IO.Error (isDoesNotExistError)

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

loadInventory :: HealthcheckOptions -> IO [SomeConfigItem]
loadInventory options = do
  let root = if null options.stateRoot then defaultStateRoot else options.stateRoot
  concat
    <$> sequence
      [ loadSomeConfigs SIssuePlanning root options.repoFilter
      , loadSomeConfigs SIssueImplement root options.repoFilter
      , loadSomeConfigs SPrReview root options.repoFilter
      ]

loadSomeConfigs :: SDomain kind -> FilePath -> Maybe Text -> IO [SomeConfigItem]
loadSomeConfigs kind stateRoot repoFilter' =
  fmap (SomeConfigItem kind) <$> loadConfigs kind (stateRoot </> watcherDomainStateSubdir kind) repoFilter'

watcherDomainStateSubdir :: SDomain kind -> FilePath
watcherDomainStateSubdir = \case
  SIssuePlanning -> "issue-planners"
  SIssueImplement -> "issue-implementers"
  SPrReview -> "pr-review-watchers"

loadConfigs :: SDomain kind -> FilePath -> Maybe Text -> IO [ConfigItem kind]
loadConfigs _kind root repoFilter' = do
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
              pure if include then Just ConfigItem {dir, configPath, config = decoded} else Nothing
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

summarizeItem :: HealthcheckOptions -> SomeConfigItem -> IO SomeWatcherSummary
summarizeItem options (SomeConfigItem kind item) =
  SomeWatcherSummary kind
    <$> summarizeTypedItem kind options item

summarizeTypedItem :: SDomain kind -> HealthcheckOptions -> ConfigItem kind -> IO (WatcherSummary kind)
summarizeTypedItem kind options item =
  case item.config of
    Left error' -> summarizeBrokenItem kind item error'
    Right config -> summarizeLoadedItem kind options item config

summarizeBrokenItem :: SDomain kind -> ConfigItem kind -> Text -> IO (WatcherSummary kind)
summarizeBrokenItem kind item error' = do
  let pid = PidReport (fallbackPidPath kind item.dir Nothing) Nothing False
  pure
    WatcherSummary
      { label = itemLabel kind Nothing Nothing Nothing
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

summarizeLoadedItem :: SDomain kind -> HealthcheckOptions -> ConfigItem kind -> GenericConfig -> IO (WatcherSummary kind)
summarizeLoadedItem kind options item config = do
  let stateDir' = fromMaybe item.dir config.stateDir
      pidPath' = fallbackPidPath kind stateDir' config.pidPath
      eventsPath' = config.eventsPath <|> Just (stateDir' </> "events.jsonl")
  pid <- readPid pidPath'
  (eventReplayReport, replayState) <- checkEventReplayWithState kind eventsPath'
  states <- projectStateFiles kind stateDir' replayState
  let issueStatus' = lookupStateText ["issueState", "issue_status"] states
      blocked' = lookupStateBool ["blockedState", "blocked"] states
      blockedReason' = lookupStateText ["blockedState", "reason"] states
      runtimeOwner' = config.runtimeOwner <|> lookupStateText ["runtimeOwner", "owner"] states
  workdirReport <- checkWorkdir config
  gitPush <- checkGitPushDryRun config workdirReport
  remotePrReport <- checkRemotePr kind config
  workerThreadReport <- checkAppServerThread options.appServerEndpoint config.threadId
  reviewerThreadReport <- checkReviewerThread kind options.appServerEndpoint config
  pure
    WatcherSummary
      { label = itemLabel kind config.repoFullName config.issueNumber config.prNumber
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

projectStateFiles :: SDomain kind -> FilePath -> Maybe SomeWatcherState -> IO Value
projectStateFiles kind stateDir' replayState =
  object <$> traverse projectStateFile (stateFileSpecs kind)
 where
  writes = maybe [] (compatibilityStateWrites stateDir') replayState

  projectStateFile (key, fileName) = do
    value <-
      if fileName == "runtime-owner.json"
        then readOptionalValueFile (stateDir' </> fileName)
        else pure (lookupProjectedState fileName writes)
    pure (Key.fromText key .= fromMaybe Null value)

stateFileSpecs :: SDomain kind -> [(Text, FilePath)]
stateFileSpecs = \case
  SIssuePlanning ->
    sharedStateFiles
      [ ("plannerState", "planner-state.json")
      ]
  SIssueImplement ->
    sharedStateFiles
      [ ("issueState", "issue-state.json")
      ]
  SPrReview ->
    [ ("watcherState", "watcher-state.json")
    , ("checkerState", "checker-state.json")
    , ("agentState", "agent-state.json")
    , ("reviewerState", "reviewer-state.json")
    , ("blockedState", "block-state.json")
    , ("runtimeOwner", "runtime-owner.json")
    ]

sharedStateFiles :: [(Text, FilePath)] -> [(Text, FilePath)]
sharedStateFiles domainFiles =
  ("daemonState", "daemon-state.json")
    : domainFiles
      <> [ ("blockedState", "block-state.json")
         , ("runtimeOwner", "runtime-owner.json")
         ]

readOptionalValueFile :: FilePath -> IO (Maybe Value)
readOptionalValueFile path = do
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else either (const Nothing) Just <$> readJsonValue path

lookupProjectedState :: FilePath -> [CompatibilityWrite] -> Maybe Value
lookupProjectedState fileName writes =
  case [value | CompatibilityWrite path value <- writes, takeFileName path == fileName] of
    value : _ -> Just value
    [] -> Nothing

fallbackPidPath :: SDomain kind -> FilePath -> Maybe FilePath -> FilePath
fallbackPidPath kind stateDir' configured =
  fromMaybe (WatcherPaths.defaultPidPath (watcherDomainValue kind) stateDir') configured

readPid :: FilePath -> IO PidReport
readPid pidPath = do
  pid' <- readPidFile pidPath
  running <- maybe (pure False) isPidRunning pid'
  pure PidReport {pidPath, pid = pid', running}

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
      let headSha' = unCommitSha <$> parseGitSha headReport.stdout
          remoteSha = unCommitSha <$> parseLsRemoteBranch remoteReport.stdout
      pure
        WorkdirReport
          { skipped = False
          , reason = Nothing
          , path = Just path'
          , exists
          , isGitCheckout = isGit
          , currentBranch = unBranchName <$> parseGitBranch branchReport.stdout
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

checkRemotePr :: SDomain kind -> GenericConfig -> IO RemotePrReport
checkRemotePr SPrReview config =
  case (config.repoFullName, config.prNumber) of
    (Just repo, Just prNumber') -> do
      report <-
        runRuntimeCommand
          ( GhPrView
              (RepoName repo)
              (PrNumber prNumber')
              GitHubCommand.ghPrViewMergeMetadataFields
          )
      if not report.ok
        then pure RemotePrReport {skipped = False, ok = False, errorMessage = Just (commandText report), raw = Null, merged = False}
        else do
          pure case commandJsonValue report of
            Left error' -> RemotePrReport {skipped = False, ok = False, errorMessage = Just error', raw = Null, merged = False}
            Right value ->
              case parseGhPrView report.stdout of
                Left error' -> RemotePrReport {skipped = False, ok = False, errorMessage = Just error', raw = value, merged = False}
                Right remote -> RemotePrReport {skipped = False, ok = True, errorMessage = Nothing, raw = value, merged = remotePullRequestIsMerged remote}
    _ -> pure (skippedRemotePr "missing repoFullName or prNumber")
checkRemotePr _ _ =
  pure (skippedRemotePr "not a PR watcher")

checkReviewerThread :: SDomain kind -> Maybe AppServerEndpoint -> GenericConfig -> IO AppServerThreadReport
checkReviewerThread SPrReview endpoint config =
  checkAppServerThread endpoint config.reviewerThreadId
checkReviewerThread _ _ config =
  pure (skippedAppServerThread "not a PR watcher" config.reviewerThreadId)

checkEventReplayWithState :: SDomain kind -> Maybe FilePath -> IO (EventReplayReport, Maybe SomeWatcherState)
checkEventReplayWithState kind (Just path') = do
  exists <- doesFileExist path'
  if not exists
    then pure (skippedEventReplay "events log does not exist" (Just path'), Nothing)
    else do
      loaded <- loadEventLogFile path'
      pure case loaded of
        Left error' -> (failedEventReplay path' (Text.pack error'), Nothing)
        Right events ->
          case replayEventLog events of
            Left failure -> (failedEventReplay path' (Text.pack (formatReplayFailureForHealthcheck failure)), Nothing)
            Right replay
              | not (watcherDomainMatches kind replay.replayState) ->
                  ( failedEventReplay
                      path'
                      ( "events replayed as "
                          <> Text.pack (show (someDomain replay.replayState))
                          <> " but config is "
                          <> Text.pack (show (watcherDomainValue kind))
                      )
                  , Nothing
                  )
              | otherwise ->
                  ( EventReplayReport
                      { skipped = False
                      , ok = True
                      , reason = Nothing
                      , eventsPath = Just path'
                      , domain = Just (Text.pack (show (someDomain replay.replayState)))
                      , phase = Just (Text.pack (show (somePhase replay.replayState)))
                      , eventCount = Just (length events)
                      , effectBatchCount = Just (length replay.replayEffects)
                      }
                  , Just replay.replayState
                  )
checkEventReplayWithState _kind Nothing = pure (skippedEventReplay "missing eventsPath" Nothing, Nothing)

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
      (threadReadRequest (RequestId 9001) (ThreadId threadId') True)
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
      pure case commandJsonValue report of
        Left error' -> object ["ok" .= False, "error" .= error']
        Right (Object object') ->
          object
            [ "ok" .= True
            , "login" .= KeyMap.lookup "login" object'
            , "id" .= KeyMap.lookup "id" object'
            , "name" .= KeyMap.lookup "name" object'
            ]
        Right value -> object ["ok" .= True, "raw" .= value]

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

lastMaybe :: [a] -> Maybe a
lastMaybe [] = Nothing
lastMaybe values = Just (last values)

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
