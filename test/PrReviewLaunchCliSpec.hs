{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module PrReviewLaunchCliSpec
  ( prReviewLaunchCliTests
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.AppServerClient (AppServerEndpoint (..))
import CodexWatcher.Core.Ids (BranchName (..), IssueNumber (..), PrNumber (..), RepoName (..))
import CodexWatcher.Domain.IssueImplement.Types (IssueConfig (..))
import CodexWatcher.Domain.PrReview.LaunchCli (PrReviewWatcherLaunchPlan (..), launchPrReviewWatcher, prReviewWatcherLaunchPlan)
import CodexWatcher.Runtime.File (readJsonValue)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Owner.Store (writeRuntimeLease)
import CodexWatcher.Runtime.Owner.Types (RuntimeLease (..), RuntimeOwner (..))
import Control.Exception (bracket, catch, evaluate, finally, mask)
import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), addUTCTime, secondsToDiffTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, getTemporaryDirectory, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (hClose, hFlush, hGetContents, stderr, stdout)
import System.Posix.IO qualified as Posix
import System.Posix.Process (getProcessID)
import TestSupport.AppServer (jsonRpcError, jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, pollSecondsForTest, sequenceAnd)

prReviewLaunchCliTests :: IO Bool
prReviewLaunchCliTests =
  sequenceAnd
    [ prReviewExecuteStartsWorkerAndReviewerThreads
    , prReviewDryRunRendersRootEndpointChildCommand
    , prReviewDryRunRendersNonRootEndpointChildCommand
    , prReviewExecuteFormatsJsonRpcFailure
    , prReviewExecuteFormatsDecodeFailure
    ]

prReviewExecuteStartsWorkerAndReviewerThreads :: IO Bool
prReviewExecuteStartsWorkerAndReviewerThreads =
  withEndpointBackedAppServer successfulThreadStartResponse \endpoint getRequests ->
    withLaunchFixture "execute-success" \launch -> do
      writeLiveRuntimeOwner launch.reviewLaunchStateDir
      run <- runLaunch ExecuteActions (Just endpoint) launch
      requests <- commandRequests <$> getRequests
      configJson <- readJsonOrNull launch.reviewLaunchConfigPath
      finalizedJson <- readJsonOrNull (launch.reviewLaunchStateDir </> "launch-finalized.json")
      sequenceAnd
        [ assert "pr-review execute exits successfully" (run.launchExitCode == ExitSuccess)
        , assert "pr-review execute starts only worker and reviewer command threads" $
            requestMethods requests == [Just "thread/start", Just "thread/start"]
              && requestIds requests == [Just (Number 9000), Just (Number 9001)]
        , assert "pr-review execute thread starts use launch workdir" $
            all ((== Just (Text.pack launch.reviewLaunchWorkdir)) . textParam "cwd") requests
        , assert "pr-review execute worker instructions keep role and PR context" $
            case requests of
              workerRequest : _ ->
                developerInstructionsContain
                  [ "dedicated English-only PR review fixer"
                  , "soulomoon/mlf2"
                  , "#87"
                  , "https://github.com/soulomoon/mlf2/pull/87"
                  , "codex/pr-review-launch"
                  , Text.pack launch.reviewLaunchWorkdir
                  ]
                  workerRequest
              _ -> False
        , assert "pr-review execute reviewer instructions keep role and PR context" $
            case requests of
              _ : reviewerRequest : _ ->
                developerInstructionsContain
                  [ "dedicated English-only PR reviewer"
                  , "soulomoon/mlf2"
                  , "#87"
                  , "https://github.com/soulomoon/mlf2/pull/87"
                  , "codex/pr-review-launch"
                  , Text.pack launch.reviewLaunchWorkdir
                  ]
                  reviewerRequest
              _ -> False
        , assert "pr-review execute persists refreshed worker and reviewer ids in config" $
            textField "threadId" configJson == Just "worker-created"
              && textField "reviewerThreadId" configJson == Just "reviewer-created"
        , assert "pr-review execute persists refreshed worker and reviewer ids in finalized manifest" $
            textField "workerThreadId" finalizedJson == Just "worker-created"
              && textField "reviewerThreadId" finalizedJson == Just "reviewer-created"
        , assert "pr-review execute skips child daemon through live runtime owner" $
            "already running under runtime owner pid" `Text.isInfixOf` Text.pack run.launchStdout
              && null run.launchStderr
        ]

prReviewDryRunRendersRootEndpointChildCommand :: IO Bool
prReviewDryRunRendersRootEndpointChildCommand =
  withLaunchFixture "dry-run-root" \launch -> do
    let endpoint = AppServerEndpoint "127.0.0.1" 45001 "/"
    run <- runLaunch DryRunActions (Just endpoint) launch
    sequenceAnd
      [ assert "pr-review dry-run root endpoint exits successfully" (run.launchExitCode == ExitSuccess)
      , assert "pr-review dry-run root endpoint renders child command flags" $
          outputContainsAll
            [ "PR review child command:"
            , "run-pr-review"
            , "--events " <> Text.pack launch.reviewLaunchEventsPath
            , "--state-dir " <> Text.pack launch.reviewLaunchStateDir
            , "--repo soulomoon/mlf2"
            , "--workdir " <> Text.pack launch.reviewLaunchWorkdir
            , "--app-server-host 127.0.0.1"
            , "--app-server-port 45001"
            , "--poll-seconds 7"
            , "--execute"
            , "--loop"
            , "--pid-file " <> Text.pack (launch.reviewLaunchStateDir </> "watcher.pid")
            ]
            run.launchStdout
      , assert "pr-review dry-run root endpoint omits app-server path flag" $
          not ("--app-server-path" `Text.isInfixOf` Text.pack run.launchStdout)
      , assert "pr-review dry-run root endpoint leaves stderr empty" (null run.launchStderr)
      ]

prReviewDryRunRendersNonRootEndpointChildCommand :: IO Bool
prReviewDryRunRendersNonRootEndpointChildCommand =
  withLaunchFixture "dry-run-path" \launch -> do
    let endpoint = AppServerEndpoint "127.0.0.1" 45002 "/codex/app-server"
    run <- runLaunch DryRunActions (Just endpoint) launch
    sequenceAnd
      [ assert "pr-review dry-run non-root endpoint exits successfully" (run.launchExitCode == ExitSuccess)
      , assert "pr-review dry-run non-root endpoint renders app-server path flag" $
          outputContainsAll
            [ "--app-server-host 127.0.0.1"
            , "--app-server-port 45002"
            , "--app-server-path /codex/app-server"
            ]
            run.launchStdout
      , assert "pr-review dry-run non-root endpoint leaves stderr empty" (null run.launchStderr)
      ]

prReviewExecuteFormatsJsonRpcFailure :: IO Bool
prReviewExecuteFormatsJsonRpcFailure =
  withEndpointBackedAppServer workerJsonRpcFailureResponse \endpoint getRequests ->
    withLaunchFixture "json-rpc-failure" \launch -> do
      run <- runLaunch ExecuteActions (Just endpoint) launch
      requests <- commandRequests <$> getRequests
      sequenceAnd
        [ assert "pr-review execute JSON-RPC failure exits non-zero" (run.launchExitCode /= ExitSuccess)
        , assert "pr-review execute JSON-RPC failure reports request id 9000" $
            "app-server JSON-RPC error for request id 9000: worker boom" `Text.isInfixOf` Text.pack run.launchStderr
        , assert "pr-review execute JSON-RPC failure stops before reviewer request" $
            requestMethods requests == [Just "thread/start"] && requestIds requests == [Just (Number 9000)]
        ]

prReviewExecuteFormatsDecodeFailure :: IO Bool
prReviewExecuteFormatsDecodeFailure =
  withEndpointBackedAppServer workerDecodeFailureResponse \endpoint getRequests ->
    withLaunchFixture "decode-failure" \launch -> do
      run <- runLaunch ExecuteActions (Just endpoint) launch
      requests <- commandRequests <$> getRequests
      sequenceAnd
        [ assert "pr-review execute decode failure exits non-zero" (run.launchExitCode /= ExitSuccess)
        , assert "pr-review execute decode failure reports formatted decode text" $
            "app-server JSON decode failed:" `Text.isInfixOf` Text.pack run.launchStderr
        , assert "pr-review execute decode failure stops before reviewer request" $
            requestMethods requests == [Just "thread/start"] && requestIds requests == [Just (Number 9000)]
        ]

data LaunchRun = LaunchRun
  { launchExitCode :: ExitCode
  , launchStdout :: String
  , launchStderr :: String
  }

runLaunch :: ActionExecutionMode -> Maybe AppServerEndpoint -> PrReviewWatcherLaunchPlan -> IO LaunchRun
runLaunch mode maybeEndpoint launch = do
  (exitCode, stdoutText, stderrText) <-
    captureStdoutStderr (launchPrReviewWatcher mode maybeEndpoint (pollSecondsForTest 7) launch)
  pure
    LaunchRun
      { launchExitCode = exitCode
      , launchStdout = stdoutText
      , launchStderr = stderrText
      }

withLaunchFixture :: String -> (PrReviewWatcherLaunchPlan -> IO a) -> IO a
withLaunchFixture label action =
  bracket setup cleanup \(root, workdir) -> do
    let launch = prReviewWatcherLaunchPlan (root </> "pr-review-watchers") workdir testIssueConfig testPrNumber
    action launch
 where
  setup = do
    tmp <- getTemporaryDirectory
    pid <- getProcessID
    let root = tmp </> ("moifold-pr-review-launch-cli-" <> label <> "-" <> show pid)
        workdir = root </> "work"
    exists <- doesDirectoryExist root
    whenExists exists (removePathForcibly root)
    createDirectoryIfMissing True workdir
    pure (root, workdir)
  cleanup (root, _workdir) =
    removePathForcibly root

whenExists :: Bool -> IO () -> IO ()
whenExists exists action =
  if exists then action else pure ()

writeLiveRuntimeOwner :: FilePath -> IO ()
writeLiveRuntimeOwner stateDir = do
  pid <- getProcessID
  let claimedAt = UTCTime (fromGregorian 2026 5 11) (secondsToDiffTime 0)
      lease =
        RuntimeLease
          { runtimeLeaseOwner = HaskellRuntime
          , runtimeLeasePid = Text.pack (show pid)
          , runtimeLeaseHost = "test-host"
          , runtimeLeaseClaimedAt = claimedAt
          , runtimeLeaseExpiresAt = addUTCTime 3600 claimedAt
          , runtimeLeaseEventLogHeadHash = "test-head"
          }
  writeRuntimeLease ioRuntimeInterpreter stateDir lease

successfulThreadStartResponse :: Value -> IO Value
successfulThreadStartResponse request =
  pure $
    case requestId request of
      Just (Number 9000) -> jsonRpcResult request (threadStartResult "worker-created")
      Just (Number 9001) -> jsonRpcResult request (threadStartResult "reviewer-created")
      _ -> jsonRpcResult request (object [])

workerJsonRpcFailureResponse :: Value -> IO Value
workerJsonRpcFailureResponse request =
  pure $
    case requestMethod request of
      Just "thread/start" -> jsonRpcError request (-32000) "worker boom"
      _ -> jsonRpcResult request (object [])

workerDecodeFailureResponse :: Value -> IO Value
workerDecodeFailureResponse request =
  pure $
    case requestMethod request of
      Just "thread/start" -> jsonRpcResult request (object ["thread" .= object ["status" .= ("queued" :: Text)]])
      _ -> jsonRpcResult request (object [])

threadStartResult :: Text -> Value
threadStartResult threadId =
  object ["thread" .= object ["id" .= threadId]]

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

commandRequests :: [Value] -> [Value]
commandRequests =
  filter \request ->
    case requestMethod request of
      Just "initialized" -> False
      Just "initialize" | requestId request == Just (Number 0) -> False
      _ -> True

requestMethod :: Value -> Maybe Text
requestMethod request =
  case lookupValue "method" request of
    Just (String method) -> Just method
    _ -> Nothing

requestId :: Value -> Maybe Value
requestId =
  lookupValue "id"

requestParams :: Value -> Maybe Value
requestParams =
  lookupValue "params"

requestMethods :: [Value] -> [Maybe Text]
requestMethods =
  fmap requestMethod

requestIds :: [Value] -> [Maybe Value]
requestIds =
  fmap requestId

textParam :: Text -> Value -> Maybe Text
textParam key request =
  case lookupValue key =<< requestParams request of
    Just (String value) -> Just value
    _ -> Nothing

developerInstructionsContain :: [Text] -> Value -> Bool
developerInstructionsContain needles request =
  case textParam "developerInstructions" request of
    Just instructions -> all (`Text.isInfixOf` instructions) needles
    Nothing -> False

textField :: Text -> Value -> Maybe Text
textField key value =
  case lookupValue key value of
    Just (String text) -> Just text
    _ -> Nothing

readJsonOrNull :: FilePath -> IO Value
readJsonOrNull path = do
  result <- readJsonValue path
  pure case result of
    Right value -> value
    Left _ -> Null

outputContainsAll :: [Text] -> String -> Bool
outputContainsAll needles output =
  let rendered = Text.pack output
   in all (`Text.isInfixOf` rendered) needles

testIssueConfig :: IssueConfig
testIssueConfig =
  IssueConfig
    { issueRepo = RepoName "soulomoon/mlf2"
    , issueNumber = IssueNumber 42
    , issueBranch = BranchName "codex/pr-review-launch"
    }

testPrNumber :: PrNumber
testPrNumber =
  PrNumber 87
