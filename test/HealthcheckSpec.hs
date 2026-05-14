{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module HealthcheckSpec
  ( healthcheckAppServerThreadInspectionTests
  , healthcheckRuntimeStateMigrationContractTests
  , prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork
  , prop_healthcheckDaemonRequiredStatuses
  , prop_healthcheckIssueImplementLifecycleReporting
  , prop_healthcheckSingletonDomains
  , prop_healthcheckSummaryJsonKeepsKindField
  , prop_healthcheckTypedAnalyzerDispatch
  ) where

import CodexWatcher.Healthcheck
import CodexWatcher.Healthcheck.Analysis (analyzeCrossItemRules, analyzeItem, logicReview, summaryObject)
import CodexWatcher.Healthcheck.Types
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.Domain.PrReview.Types (PrConfig (..))
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import CodexWatcher.Runtime.Process (skippedCommand)
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..))
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
import CodexWatcher.Workflow.GitHub.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))
import Control.Exception (bracket, catch, evaluate, finally, mask)
import Data.Aeson (Value (..), eitherDecode', encode, object, toJSON, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy.Char8 qualified as LazyByteString.Char8
import Data.Foldable (traverse_)
import Data.Foldable qualified as Foldable
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectory, createDirectoryIfMissing, getPermissions, getTemporaryDirectory, removeFile, removePathForcibly, setPermissions, writable, executable)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>), searchPathSeparator)
import System.Exit (ExitCode (..))
import System.IO (hClose, hFlush, hGetContents, openTempFile, stderr, stdout)
import System.Posix.IO qualified as Posix
import TestSupport.AppServer (jsonRpcError, jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, maxParallelForTest, sequenceAnd)

healthcheckAppServerThreadInspectionTests :: IO Bool
healthcheckAppServerThreadInspectionTests =
  withHealthcheckCommandStubs $
    sequenceAnd
      [ healthcheckReadsWorkerThread
      , healthcheckSkipsWorkerThreadWithoutEndpoint
      , healthcheckSkipsWorkerThreadWithoutThreadId
      , healthcheckReportsAppServerJsonRpcError
      , healthcheckReportsAppServerDecodeFailure
      ]

healthcheckRuntimeStateMigrationContractTests :: IO Bool
healthcheckRuntimeStateMigrationContractTests =
  withHealthcheckCommandStubs $
    withRuntimeStateContractRoot \stateRoot' -> do
      (_exitCode, stdoutText, _stderrText) <-
        captureStdoutStderr
          ( runHealthcheck
              HealthcheckOptions
                { stateRoot = stateRoot'
                , repoFilter = Just "owner/repo"
                , appServerEndpoint = Nothing
                }
          )
      case eitherDecode' (LazyByteString.Char8.pack stdoutText) of
        Left error' -> assert ("healthcheck runtime-state migration report decodes as JSON: " <> error') False
        Right report ->
          let watchers = watcherObjects report
           in sequenceAnd
                [ assert "healthcheck replacement report includes planner, implementer, and PR review watchers" $
                    length watchers == 3
                , assert "healthcheck projects issue-planning compatibility state from event replay under stable state keys" $
                    watcherStateText "issue-planning" ["plannerState", "status"] watchers == Just "ready"
                      && watcherStateIsNull "issue-planning" ["blockedState"] watchers
                , assert "healthcheck projects issue-implementation compatibility state from event replay under stable state keys" $
                    watcherStateText "issue-implement" ["issueState", "issue_status"] watchers == Just "preparing_pr"
                      && watcherStateIsNull "issue-implement" ["blockedState"] watchers
                , assert "healthcheck projects PR-review compatibility state from event replay under stable state keys" $
                    watcherStateText "pr-review" ["watcherState", "lastTurnStatus"] watchers == Just "checking"
                      && watcherStateBool "pr-review" ["checkerState", "has_unresolved"] watchers == Just False
                      && watcherStateIsNull "pr-review" ["agentState"] watchers
                      && watcherStateIsNull "pr-review" ["reviewerState"] watchers
                      && watcherStateIsNull "pr-review" ["blockedState"] watchers
                ]

healthcheckReadsWorkerThread :: IO Bool
healthcheckReadsWorkerThread =
  withEndpointBackedAppServer successResponse \endpoint getRequests ->
    withHealthcheckReport (Just endpoint) (Just "worker-thread") \report -> do
      requests <- getRequests
      let readRequests = threadReadRequests requests
          inspection = workerThreadInspectionValue report
      sequenceAnd
        [ assert "healthcheck issues one worker thread/read" (length readRequests == 1)
        , assert "healthcheck worker thread/read uses request id 9001, configured thread, and includeTurns=true" $
            case readRequests of
              request : _ -> threadReadMatches request
              [] -> False
        , assert "healthcheck report marks worker thread inspection successful" $
            lookupValue "skipped" inspection == Just (Bool False)
              && lookupValue "ok" inspection == Just (Bool True)
              && lookupValue "threadId" inspection == Just (String "worker-thread")
              && lookupValue "turnCount" inspection == Just (Number 2)
              && lookupValue "latestTurnId" inspection == Just (String "turn-latest")
              && lookupValue "latestTurnStatus" inspection == Just (String "completed")
        ]

healthcheckSkipsWorkerThreadWithoutEndpoint :: IO Bool
healthcheckSkipsWorkerThreadWithoutEndpoint =
  withHealthcheckReport Nothing (Just "worker-thread") \report -> do
    let inspection = workerThreadInspectionValue report
    sequenceAnd
      [ assert "healthcheck missing endpoint skip is healthy" $
          lookupValue "skipped" inspection == Just (Bool True)
            && lookupValue "ok" inspection == Just (Bool True)
      , assert "healthcheck missing endpoint preserves configured thread id" $
          lookupValue "threadId" inspection == Just (String "worker-thread")
      , assert "healthcheck missing endpoint records stable skip reason" $
          lookupValue "reason" inspection == Just (String "healthcheck app-server endpoint not configured")
      ]

healthcheckSkipsWorkerThreadWithoutThreadId :: IO Bool
healthcheckSkipsWorkerThreadWithoutThreadId =
  withEndpointBackedAppServer successResponse \endpoint getRequests ->
    withHealthcheckReport (Just endpoint) Nothing \report -> do
      requests <- getRequests
      let inspection = workerThreadInspectionValue report
      sequenceAnd
        [ assert "healthcheck missing thread id skip is healthy" $
            lookupValue "skipped" inspection == Just (Bool True)
              && lookupValue "ok" inspection == Just (Bool True)
        , assert "healthcheck missing thread id omits report thread id" $
            lookupValue "threadId" inspection == Just Null
        , assert "healthcheck missing thread id records stable skip reason" $
            lookupValue "reason" inspection == Just (String "config has no thread id")
        , assert "healthcheck missing thread id does not issue thread/read" $
            null (threadReadRequests requests)
        ]

healthcheckReportsAppServerJsonRpcError :: IO Bool
healthcheckReportsAppServerJsonRpcError =
  withEndpointBackedAppServer (\request -> pure (jsonRpcError request (-32000) "read boom")) \endpoint _getRequests ->
    withHealthcheckReport (Just endpoint) (Just "worker-thread") \report -> do
      let inspection = workerThreadInspectionValue report
      sequenceAnd
        [ assert "healthcheck JSON-RPC error marks worker thread inspection failed" $
            lookupValue "skipped" inspection == Just (Bool False)
              && lookupValue "ok" inspection == Just (Bool False)
        , assert "healthcheck JSON-RPC error includes request id and message" $
            maybe False ("app-server JSON-RPC error for request id 9001: read boom" `Text.isInfixOf`) (textField "reason" inspection)
        ]

healthcheckReportsAppServerDecodeFailure :: IO Bool
healthcheckReportsAppServerDecodeFailure =
  withEndpointBackedAppServer malformedTurnsResponse \endpoint _getRequests ->
    withHealthcheckReport (Just endpoint) (Just "worker-thread") \report -> do
      let inspection = workerThreadInspectionValue report
      sequenceAnd
        [ assert "healthcheck decode failure marks worker thread inspection failed" $
            lookupValue "skipped" inspection == Just (Bool False)
              && lookupValue "ok" inspection == Just (Bool False)
        , assert "healthcheck decode failure keeps stable prefix" $
            maybe False ("app-server JSON decode failed:" `Text.isPrefixOf`) (textField "reason" inspection)
        ]

withHealthcheckReport :: Maybe AppServerEndpoint -> Maybe Text -> (Value -> IO Bool) -> IO Bool
withHealthcheckReport endpoint threadId' action =
  withHealthcheckState threadId' \stateRoot' -> do
    (_exitCode, stdoutText, _stderrText) <-
      captureStdoutStderr
        ( runHealthcheck
            HealthcheckOptions
              { stateRoot = stateRoot'
              , repoFilter = Nothing
              , appServerEndpoint = endpoint
              }
        )
    case eitherDecode' (LazyByteString.Char8.pack stdoutText) of
      Left error' ->
        assert ("healthcheck stdout decodes as JSON: " <> error') False
      Right report ->
        action report

withHealthcheckState :: Maybe Text -> (FilePath -> IO a) -> IO a
withHealthcheckState threadId' action =
  bracket makeRoot removePathForcibly \stateRoot' -> do
    let watcherDir = stateRoot' </> "issue-implementers" </> "owner-repo-1"
    createDirectoryIfMissing True watcherDir
    LazyByteString.Char8.writeFile (watcherDir </> "config.json") (encode (configJson watcherDir))
    action stateRoot'
 where
  makeRoot = do
    tempRoot <- getTemporaryDirectory
    createTempDirectoryLocal tempRoot "healthcheck-appserver-"
  configJson watcherDir =
    object
      [ "stateDir" .= watcherDir
      , "pidPath" .= (watcherDir </> "watcher.pid")
      , "eventsPath" .= (watcherDir </> "events.jsonl")
      , "threadId" .= threadId'
      ]

withRuntimeStateContractRoot :: (FilePath -> IO a) -> IO a
withRuntimeStateContractRoot action =
  bracket makeRoot removePathForcibly \stateRoot' -> do
    let plannerDir = stateRoot' </> "issue-planners" </> "owner-repo"
        implementDir = stateRoot' </> "issue-implementers" </> "owner-repo-issue-7"
        reviewDir = stateRoot' </> "pr-review-watchers" </> "owner-repo-pr-11"
    createDirectoryIfMissing True plannerDir
    createDirectoryIfMissing True implementDir
    createDirectoryIfMissing True reviewDir
    LazyByteString.Char8.writeFile (plannerDir </> "config.json") (encode (plannerConfigJson plannerDir))
    LazyByteString.Char8.writeFile (implementDir </> "config.json") (encode (implementConfigJson implementDir))
    LazyByteString.Char8.writeFile (reviewDir </> "config.json") (encode (reviewConfigJson reviewDir))
    writeEventsFile
      (plannerDir </> "events.jsonl")
      [IssuePlanningInitialized (PlannerConfig (RepoName "owner/repo") (maxParallelForTest 2) [])]
    writeEventsFile
      (implementDir </> "events.jsonl")
      [IssueImplementInitialized (IssueConfig (RepoName "owner/repo") (IssueNumber 7) (BranchName "issue-7")) (ThreadId "worker-thread")]
    writeEventsFile
      (reviewDir </> "events.jsonl")
      [PrReviewInitialized (PrConfig (RepoName "owner/repo") (PrNumber 11) (BranchName "pr-11")) (ThreadId "pr-worker-thread") (ThreadId "reviewer-thread")]
    action stateRoot'
 where
  makeRoot = do
    tempRoot <- getTemporaryDirectory
    createTempDirectoryLocal tempRoot "healthcheck-runtime-state-"
  plannerConfigJson plannerDir =
    object
      [ "repoFullName" .= ("owner/repo" :: Text)
      , "stateDir" .= plannerDir
      , "pidPath" .= (plannerDir </> "watcher.pid")
      , "eventsPath" .= (plannerDir </> "events.jsonl")
      , "threadId" .= ("planner-thread" :: Text)
      , "maxParallel" .= (2 :: Int)
      ]
  implementConfigJson implementDir =
    object
      [ "repoFullName" .= ("owner/repo" :: Text)
      , "issueNumber" .= (7 :: Int)
      , "stateDir" .= implementDir
      , "pidPath" .= (implementDir </> "watcher.pid")
      , "eventsPath" .= (implementDir </> "events.jsonl")
      , "threadId" .= ("worker-thread" :: Text)
      ]
  reviewConfigJson reviewDir =
    object
      [ "repoFullName" .= ("owner/repo" :: Text)
      , "prNumber" .= (11 :: Int)
      , "stateDir" .= reviewDir
      , "pidPath" .= (reviewDir </> "watcher.pid")
      , "eventsPath" .= (reviewDir </> "events.jsonl")
      , "threadId" .= ("pr-worker-thread" :: Text)
      , "reviewerThreadId" .= ("reviewer-thread" :: Text)
      ]

writeEventsFile :: FilePath -> [WatcherEvent] -> IO ()
writeEventsFile path events =
  LazyByteString.Char8.writeFile path (LazyByteString.Char8.unlines (fmap encode events))

withHealthcheckCommandStubs :: IO a -> IO a
withHealthcheckCommandStubs action =
  bracket makeBin removePathForcibly \binDir -> do
    oldPath <- lookupEnv "PATH"
    let restorePath =
          case oldPath of
            Nothing -> unsetEnv "PATH"
            Just path' -> setEnv "PATH" path'
    setEnv "PATH" (binDir <> [searchPathSeparator] <> maybe "" id oldPath)
    action `finally` restorePath
 where
  makeBin = do
    tempRoot <- getTemporaryDirectory
    binDir <- createTempDirectoryLocal tempRoot "healthcheck-bin-"
    traverse_ (writeStub binDir) ["git", "gh", "cabal", "ghc", "ghcup"]
    pure binDir
  writeStub binDir command = do
    let path' = binDir </> command
    writeFile path' (stubScript command)
    permissions <- getPermissions path'
    setPermissions path' permissions {writable = True, executable = True}
  stubScript "gh" =
    unlines
      [ "#!/bin/sh"
      , "if [ \"$1\" = \"api\" ] && [ \"$2\" = \"user\" ]; then"
      , "  printf '{\"login\":\"test-user\",\"id\":1,\"name\":\"Test User\"}\\n'"
      , "  exit 0"
      , "fi"
      , "printf 'gh test stub\\n'"
      ]
  stubScript command =
    "#!/bin/sh\nprintf '" <> command <> " test stub\\n'\n"

createTempDirectoryLocal :: FilePath -> String -> IO FilePath
createTempDirectoryLocal parent template = do
  (path', handle) <- openTempFile parent template
  hClose handle
  removeFile path'
  createDirectory path'
  pure path'

captureStdoutStderr :: IO () -> IO (ExitCode, String, String)
captureStdoutStderr action =
  mask \restore -> do
    hFlush stdout
    hFlush stderr
    originalStdout <- Posix.dup Posix.stdOutput
    originalStderr <- Posix.dup Posix.stdError
    (stdoutReadFd, stdoutWriteFd) <- Posix.createPipe
    (stderrReadFd, stderrWriteFd) <- Posix.createPipe
    stdoutRead <- Posix.fdToHandle stdoutReadFd
    stderrRead <- Posix.fdToHandle stderrReadFd
    _ <- Posix.dupTo stdoutWriteFd Posix.stdOutput
    _ <- Posix.dupTo stderrWriteFd Posix.stdError
    Posix.closeFd stdoutWriteFd
    Posix.closeFd stderrWriteFd
    let restoreStreams = do
          hFlush stdout
          hFlush stderr
          _ <- Posix.dupTo originalStdout Posix.stdOutput
          _ <- Posix.dupTo originalStderr Posix.stdError
          Posix.closeFd originalStdout
          Posix.closeFd originalStderr
    exitCode <-
      (restore (action >> pure ExitSuccess) `catch` \(code :: ExitCode) -> pure code)
        `finally` restoreStreams
    stdoutText <- hGetContents stdoutRead
    stderrText <- hGetContents stderrRead
    _ <- evaluate (length stdoutText)
    _ <- evaluate (length stderrText)
    hClose stdoutRead
    hClose stderrRead
    pure (exitCode, stdoutText, stderrText)

successResponse :: Value -> IO Value
successResponse request =
  pure (jsonRpcResult request (threadReadResult [turnObject "turn-old" "running", turnObject "turn-latest" "completed"]))

malformedTurnsResponse :: Value -> IO Value
malformedTurnsResponse request =
  pure (jsonRpcResult request (threadReadResult [object ["status" .= ("completed" :: Text)]]))

threadReadResult :: [Value] -> Value
threadReadResult turns =
  object
    [ "thread" .= object ["id" .= ("worker-thread" :: Text), "status" .= object ["type" .= ("running" :: Text)]]
    , "turns" .= turns
    ]

turnObject :: Text -> Text -> Value
turnObject turnId' status =
  object
    [ "id" .= turnId'
    , "status" .= status
    , "output" .= (Nothing :: Maybe Text)
    ]

workerThreadInspectionValue :: Value -> Value
workerThreadInspectionValue report =
  case lookupValue "watchers" report of
    Just (Array watchers)
      | Just watcher <- firstArrayElement watchers ->
          maybe Null id (lookupValue "workerThreadInspection" watcher)
    _ -> Null

firstArrayElement :: Foldable t => t Value -> Maybe Value
firstArrayElement =
  foldr (const . Just) Nothing

threadReadRequests :: [Value] -> [Value]
threadReadRequests =
  filter \request -> requestMethod request == Just "thread/read"

threadReadMatches :: Value -> Bool
threadReadMatches request =
  lookupValue "id" request == Just (Number 9001)
    && requestMethod request == Just "thread/read"
    && (lookupValue "threadId" =<< requestParams request) == Just (String "worker-thread")
    && (lookupValue "includeTurns" =<< requestParams request) == Just (Bool True)

requestMethod :: Value -> Maybe Text
requestMethod request =
  case lookupValue "method" request of
    Just (String method) -> Just method
    _ -> Nothing

requestParams :: Value -> Maybe Value
requestParams =
  lookupValue "params"

textField :: Text -> Value -> Maybe Text
textField key value =
  case lookupValue key value of
    Just (String text) -> Just text
    _ -> Nothing

watcherObjects :: Value -> [Value]
watcherObjects report =
  case lookupValue "watchers" report of
    Just (Array watchers) -> Foldable.toList watchers
    _ -> []

watcherStateText :: Text -> [Text] -> [Value] -> Maybe Text
watcherStateText kind path watchers =
  case watcherStateValue kind path watchers of
    Just (String text) -> Just text
    _ -> Nothing

watcherStateBool :: Text -> [Text] -> [Value] -> Maybe Bool
watcherStateBool kind path watchers =
  case watcherStateValue kind path watchers of
    Just (Bool bool) -> Just bool
    _ -> Nothing

watcherStateIsNull :: Text -> [Text] -> [Value] -> Bool
watcherStateIsNull kind path watchers =
  watcherStateValue kind path watchers == Just Null

watcherStateValue :: Text -> [Text] -> [Value] -> Maybe Value
watcherStateValue kind path watchers = do
  watcher <- firstMatchingWatcher kind watchers
  states <- lookupValue "states" watcher
  valueAtTextPath path states

firstMatchingWatcher :: Text -> [Value] -> Maybe Value
firstMatchingWatcher kind =
  foldr
    ( \watcher found ->
        if lookupValue "kind" watcher == Just (String kind)
          then Just watcher
          else found
    )
    Nothing

valueAtTextPath :: [Text] -> Value -> Maybe Value
valueAtTextPath [] value = Just value
valueAtTextPath (key : rest) value = do
  child <- lookupValue key value
  valueAtTextPath rest child

prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork :: Bool
prop_healthcheckDirtyWarningsOnlyForStoppedLiveWork =
  warnIssueImplementDirtyWorkdir True False
    && not (warnIssueImplementDirtyWorkdir True True)
    && not (warnIssueImplementDirtyWorkdir False False)
    && warnPrReviewDirtyWorkdir True False False
    && not (warnPrReviewDirtyWorkdir True True False)
    && not (warnPrReviewDirtyWorkdir True False True)

prop_healthcheckDaemonRequiredStatuses :: Bool
prop_healthcheckDaemonRequiredStatuses =
  planningStatusRequiresDaemon (Just "Initialized") (Just "ready")
    && planningStatusRequiresDaemon (Just "Initialized") (Just "waiting_ready_issues")
    && not (planningStatusRequiresDaemon (Just "Complete") (Just "ready"))
    && not (planningStatusRequiresDaemon (Just "Initialized") (Just "complete"))
    && issueStatusRequiresDaemon "waiting_pr_merge"
    && issueStatusRequiresDaemon "ready_to_plan"
    && issueStatusRequiresDaemon "planning"
    && issueStatusRequiresDaemon "plan_ready"
    && issueStatusRequiresDaemon "in_progress"
    && not (issueStatusRequiresDaemon "complete")
    && prReviewRequiresDaemon False (Just "Reviewing")
    && not (prReviewRequiresDaemon True (Just "Reviewing"))
    && not (prReviewRequiresDaemon False (Just "Complete"))

prop_healthcheckSingletonDomains :: Bool
prop_healthcheckSingletonDomains =
  watcherDomainValue SIssuePlanning == IssuePlanning
    && watcherDomainValue SIssueImplement == IssueImplement
    && watcherDomainValue SPrReview == PrReview

prop_healthcheckSummaryJsonKeepsKindField :: Bool
prop_healthcheckSummaryJsonKeepsKindField =
  kindField (SomeWatcherSummary SIssuePlanning sampleSummary) == Just (String "issue-planning")
    && kindField (SomeWatcherSummary SIssueImplement sampleSummary) == Just (String "issue-implement")
    && kindField (SomeWatcherSummary SPrReview sampleSummary) == Just (String "pr-review")

prop_healthcheckTypedAnalyzerDispatch :: Bool
prop_healthcheckTypedAnalyzerDispatch =
  containsMessage "maxParallel is less than 1" planningProblems
    && not (containsMessage "missing worker threadId" planningProblems)
    && containsMessage "missing worker threadId" implementProblems
    && not (containsMessage "reviewWhenClean is enabled but reviewerThreadId is missing" implementProblems)
    && containsMessage "missing PR worker threadId" reviewProblems
    && containsMessage "reviewWhenClean is enabled but reviewerThreadId is missing" reviewProblems
 where
  planningProblems =
    analyzeItem (SomeWatcherSummary SIssuePlanning planningSummary)
  implementProblems =
    analyzeItem (SomeWatcherSummary SIssueImplement implementSummary)
  reviewProblems =
    analyzeItem (SomeWatcherSummary SPrReview reviewSummary)
  planningSummary :: WatcherSummary 'IssuePlanning
  planningSummary = sampleSummaryWith Nothing (Just "reviewer-thread") (Just False) (Just 0)
  implementSummary :: WatcherSummary 'IssueImplement
  implementSummary = sampleSummaryWith Nothing Nothing (Just False) (Just 8)
  reviewSummary :: WatcherSummary 'PrReview
  reviewSummary = sampleSummaryWith Nothing Nothing (Just True) (Just 8)

prop_healthcheckIssueImplementLifecycleReporting :: Bool
prop_healthcheckIssueImplementLifecycleReporting =
  not (containsMessage "issue status is complete but daemon is not running" terminalProblems)
    && containsMessage "issue status is in_progress but daemon is not running" stoppedProblems
    && containsMessage "workdir has uncommitted changes while daemon is stopped" stoppedProblems
    && containsMessage "multiple active implementers own the same issue: owner/repo#7 implementer, owner/repo#7 implementer" duplicateProblems
    && summaryField "activeImplementers" == Just (Number 2)
    && "This Haskell healthcheck is read-only." `Text.isInfixOf` Text.pack (show logicReview)
 where
  terminalProblems =
    analyzeItem (SomeWatcherSummary SIssueImplement (issueSummary (Just "complete") False False))
  stoppedProblems =
    analyzeItem (SomeWatcherSummary SIssueImplement (issueSummary (Just "in_progress") False True))
  duplicateProblems =
    analyzeCrossItemRules
      [ SomeWatcherSummary SIssueImplement (issueSummary (Just "in_progress") True False)
      , SomeWatcherSummary SIssueImplement (issueSummary (Just "plan_ready") True False)
      ]
  summaryField key =
    case summaryObject
      [ SomeWatcherSummary SIssueImplement (issueSummary (Just "in_progress") True False)
      , SomeWatcherSummary SIssueImplement (issueSummary (Just "plan_ready") True False)
      ] of
      Object object' -> KeyMap.lookup (Key.fromString key) object'
      _ -> Nothing

issueSummary :: Maybe Text -> Bool -> Bool -> WatcherSummary 'IssueImplement
issueSummary status running dirty =
  sampleSummary
    { label = "owner/repo#7 implementer"
    , repoFullName = Just "owner/repo"
    , issueNumber = Just 7
    , runtimeOwner = Just "runtime-owner-1"
    , pid = PidReport "issue-watcher.pid" (Just "1234") running
    , issueStatus = status
    , workdir = sampleSummary.workdir {dirty = dirty}
    }

kindField :: SomeWatcherSummary -> Maybe Value
kindField summary =
  case toJSON summary of
    Object object' -> KeyMap.lookup (Key.fromString "kind") object'
    _ -> Nothing

containsMessage :: Text -> [Problem] -> Bool
containsMessage message' =
  any ((== message') . (.message))

sampleSummary :: WatcherSummary kind
sampleSummary =
  sampleSummaryWith (Just "worker-thread") (Just "reviewer-thread") (Just False) (Just 8)

sampleSummaryWith :: Maybe Text -> Maybe Text -> Maybe Bool -> Maybe Int -> WatcherSummary kind
sampleSummaryWith threadId' reviewerThreadId' reviewWhenClean' maxParallel' =
  WatcherSummary
    { label = "owner/repo#1"
    , configPath = "config.json"
    , configLoadError = Nothing
    , repoFullName = Just "owner/repo"
    , issueNumber = Just 1
    , prNumber = Just 2
    , branch = Just "main"
    , workdirPath = Just "/tmp/workdir"
    , threadId = threadId'
    , reviewerThreadId = reviewerThreadId'
    , reviewWhenClean = reviewWhenClean'
    , maxParallel = maxParallel'
    , runtimeOwner = Nothing
    , pid = PidReport "watcher.pid" Nothing False
    , issueStatus = Nothing
    , blocked = False
    , blockedReason = Nothing
    , workdir =
        WorkdirReport
          { skipped = True
          , reason = Just "test"
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
    , gitPushDryRun = skippedCommand "test"
    , remotePr = RemotePrReport {skipped = True, ok = False, errorMessage = Just "test", raw = Null, merged = False}
    , eventReplay =
        EventReplayReport
          { skipped = True
          , ok = False
          , reason = Just "test"
          , eventsPath = Nothing
          , domain = Nothing
          , phase = Just "Complete"
          , eventCount = Nothing
          , effectBatchCount = Nothing
          }
    , workerThreadInspection = sampleThreadReport
    , reviewerThreadInspection = sampleThreadReport
    , states = Null
    }

sampleThreadReport :: AppServerThreadReport
sampleThreadReport =
  AppServerThreadReport
    { skipped = True
    , ok = True
    , threadId = Nothing
    , reason = Just "test"
    , turnCount = Nothing
    , latestTurnId = Nothing
    , latestTurnStatus = Nothing
    }
