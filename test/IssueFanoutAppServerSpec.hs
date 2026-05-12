{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module IssueFanoutAppServerSpec
  ( issueFanoutAppServerTests
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.Cli.Command.IssueFanout
  ( IssueImplementerChildLaunch (..)
  , IssueImplementerChildStartResult (..)
  , issueImplementerChildArgs
  , retryableLaunchCommandFailure
  , runIssueImplementerLaunchesDetailed
  )
import CodexWatcher.Core.Ids (IssueNumber (..), RepoName (..), unIssueNumber)
import CodexWatcher.Domain.IssuePlanning.Fanout
  ( IssueImplementerLaunchPlan (..)
  , IssuePlanningFanoutConfig (..)
  , defaultIssuePlanningFanoutConfig
  , issueImplementerLaunchPlan
  )
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.Runtime.Command.Render (commandText)
import CodexWatcher.Runtime.Command.Types (CommandReport (..), RuntimeCommand (..))
import CodexWatcher.Runtime.File (readJsonValue)
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint (..))
import Control.Exception (bracket, catch, evaluate, finally, mask)
import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getTemporaryDirectory
  , removePathForcibly
  )
import System.Exit (ExitCode (..), die)
import System.FilePath ((</>))
import System.IO (hClose, hFlush, hGetContents)
import System.IO qualified as IO
import System.Posix.IO qualified as Posix
import System.Posix.Process (getProcessID)
import System.Process (CreateProcess (..), proc, createProcess, waitForProcess)
import TestSupport.AppServer (jsonRpcError, jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.SourceScan (textNeedlesInOrder)
import TestSupport.Workflow (assert, lookupValue, maxParallelForTest, pollSecondsForTest, sequenceAnd)

issueFanoutAppServerTests :: IO Bool
issueFanoutAppServerTests =
  sequenceAnd
    [ issueFanoutExecuteStartsAppServerBackedIssueThreads
    , issueFanoutChildArgsRenderRootEndpoint
    , issueFanoutChildArgsRenderNonRootEndpoint
    , issueFanoutRetainsRetryableCloneFailureContract
    , issueFanoutChildStartClassificationSourceContract
    , issueFanoutExecuteFormatsJsonRpcFailure
    , issueFanoutExecuteFormatsDecodeFailure
    ]

issueFanoutExecuteStartsAppServerBackedIssueThreads :: IO Bool
issueFanoutExecuteStartsAppServerBackedIssueThreads =
  withEndpointBackedAppServer successfulThreadStartResponse \endpoint getRequests ->
    withFanoutFixture "execute-success" \fixture -> do
      let pollSeconds = pollSecondsForTest 13
          childLaunch = PrintChildLaunchCommands endpoint pollSeconds
          launches = fixtureLaunches fixture [IssueNumber 10, IssueNumber 11]
      mapM_ prepareExistingGitWorkdir launches
      results <- runIssueImplementerLaunchesDetailed ExecuteActions (Just endpoint) childLaunch launches
      requests <- commandRequests <$> getRequests
      configs <- traverse (readJsonOrNull . (.launchConfigPath)) launches
      finalized <- traverse (readJsonOrNull . launchFinalizedManifestPath . (.launchStateDir)) launches
      pendingExists <- traverse (doesFileExist . launchPendingManifestPath . (.launchStateDir)) launches
      eventLogs <- traverse (TextIO.readFile . (.launchEventsPath)) launches
      sequenceAnd
        [ assert "issue fanout execute reports both issue implementers started" $
            results == [IssueImplementerChildStarted (IssueNumber 10), IssueImplementerChildStarted (IssueNumber 11)]
        , assert "issue fanout execute starts app-server threads with deterministic request ids" $
            requestMethods requests == [Just "thread/start", Just "thread/start"]
              && requestIds requests == [Just (Number 8000), Just (Number 8001)]
        , assert "issue fanout execute uses launch workdirs as thread cwd" $
            fmap (textParam "cwd") requests == fmap (fmap Text.pack . (.launchWorkdir)) launches
        , assert "issue fanout execute developer instructions preserve first issue context" $
            case requests of
              firstRequest : _ ->
                developerInstructionsContain
                  [ "soulomoon/mlf2"
                  , "10"
                  , "https://github.com/soulomoon/mlf2/issues/10"
                  , "codex/issue-10"
                  , Text.pack (fixtureWorkdir fixture (IssueNumber 10))
                  , Text.pack (fixtureStateDir fixture (IssueNumber 10))
                  ]
                  firstRequest
              _ -> False
        , assert "issue fanout execute persists app-server thread ids in configs" $
            fmap (textField "threadId") configs == [Just "created-thread-10", Just "created-thread-11"]
        , assert "issue fanout execute appends initialized events with app-server thread ids" $
            all (uncurry Text.isInfixOf) (zip ["created-thread-10", "created-thread-11"] eventLogs)
        , assert "issue fanout execute finalizes manifests with app-server thread ids" $
            fmap (textField "threadId") finalized == [Just "created-thread-10", Just "created-thread-11"]
        , assert "issue fanout execute removes pending manifests after finalization" $
            pendingExists == [False, False]
        ]

issueFanoutChildArgsRenderRootEndpoint :: IO Bool
issueFanoutChildArgsRenderRootEndpoint =
  withFanoutFixture "child-args-root" \fixture -> do
    let endpoint = AppServerEndpoint "127.0.0.1" 45001 "/"
        pollSeconds = pollSecondsForTest 17
        launch = fixtureLaunch fixture (IssueNumber 42)
        args = issueImplementerChildArgs endpoint pollSeconds launch
        output = unwords args
    sequenceAnd
      [ assert "issue fanout root endpoint omits app-server path flag" $
          not ("--app-server-path" `elem` args)
      , assert "issue fanout root endpoint child args keep runtime shape" $
          outputContainsAll
            [ "run-issue-implement"
            , "--events " <> Text.pack launch.launchEventsPath
            , "--state-dir " <> Text.pack launch.launchStateDir
            , "--repo soulomoon/mlf2"
            , "--workdir " <> Text.pack (fixtureWorkdir fixture (IssueNumber 42))
            , "--app-server-host 127.0.0.1"
            , "--app-server-port 45001"
            , "--poll-seconds 17"
            , "--execute"
            , "--loop"
            , "--pid-file " <> Text.pack (launch.launchStateDir </> "issue-watcher.pid")
            ]
            output
      ]

issueFanoutChildArgsRenderNonRootEndpoint :: IO Bool
issueFanoutChildArgsRenderNonRootEndpoint =
  withFanoutFixture "child-args-path" \fixture -> do
    let endpoint = AppServerEndpoint "127.0.0.1" 45002 "/codex/app-server"
        pollSeconds = pollSecondsForTest 19
        launch = fixtureLaunch fixture (IssueNumber 43)
        args = issueImplementerChildArgs endpoint pollSeconds launch
        output = unwords args
    sequenceAnd
      [ assert "issue fanout non-root endpoint includes app-server path flag" $
          outputContainsAll
            [ "--app-server-host 127.0.0.1"
            , "--app-server-port 45002"
            , "--app-server-path /codex/app-server"
            , "--poll-seconds 19"
            ]
            output
      ]

issueFanoutRetainsRetryableCloneFailureContract :: IO Bool
issueFanoutRetainsRetryableCloneFailureContract =
  sequenceAnd
    [ assert "issue fanout retries transient gh repo clone failures" $
        retryableLaunchCommandFailure cloneCommand tlsCloneFailure
          && retryableLaunchCommandFailure cloneCommand dnsCloneFailure
    , assert "issue fanout does not retry auth or non-clone failures" $
        not (retryableLaunchCommandFailure cloneCommand authCloneFailure)
          && not (retryableLaunchCommandFailure checkoutCommand tlsCloneFailure)
    , assert "issue fanout failure text keeps transient detail visible" $
        "TLS connection was non-properly terminated" `Text.isInfixOf` commandText tlsCloneFailure
    ]
 where
  cloneCommand = RawCommand "gh" ["repo", "clone", "owner/name", "/tmp/worktrees/owner_name__issue1"] Nothing
  checkoutCommand = RawCommand "git" ["checkout", "-B", "codex/issue-1"] (Just "/tmp/worktrees/owner_name__issue1")
  tlsCloneFailure =
    CommandReport
      { ok = False
      , status = Just 128
      , stdout = ""
      , stderr = "fatal: unable to access 'https://github.com/owner/name.git/': gnutls_handshake() failed: The TLS connection was non-properly terminated."
      , errorMessage = Nothing
      }
  dnsCloneFailure =
    CommandReport
      { ok = False
      , status = Just 128
      , stdout = ""
      , stderr = "fatal: unable to access 'https://github.com/owner/name.git/': Could not resolve host: github.com"
      , errorMessage = Nothing
      }
  authCloneFailure =
    CommandReport
      { ok = False
      , status = Just 1
      , stdout = ""
      , stderr = "HTTP 403: Resource not accessible by integration"
      , errorMessage = Nothing
      }

issueFanoutChildStartClassificationSourceContract :: IO Bool
issueFanoutChildStartClassificationSourceContract = do
  source <- TextIO.readFile "src/CodexWatcher/Cli/Command/IssueFanout.hs"
  sequenceAnd
    [ assert "issue fanout daemon pid ready classifies child as started" $
        textNeedlesInOrder
          [ "DaemonPidReady ->"
          , "IssueImplementerChildStarted issue"
          ]
          source
    , assert "issue fanout terminal complete before pid readiness classifies completed before ready" $
        textNeedlesInOrder
          [ "DaemonPidNotReady detail -> do"
          , "WatcherTerminal TerminalComplete ->"
          , "IssueImplementerChildCompletedBeforeReady issue"
          ]
          source
    , assert "issue fanout non-running non-complete status keeps readiness detail in problem" $
        textNeedlesInOrder
          [ "WatcherActiveRunning ->"
          , "IssueImplementerChildStarted issue"
          , "_ ->"
          , "IssueImplementerChildStartProblem issue detail status"
          ]
          source
    ]

issueFanoutExecuteFormatsJsonRpcFailure :: IO Bool
issueFanoutExecuteFormatsJsonRpcFailure =
  withEndpointBackedAppServer workerJsonRpcFailureResponse \endpoint getRequests ->
    withFanoutFixture "json-rpc-failure" \fixture -> do
      let pollSeconds = pollSecondsForTest 13
          childLaunch = PrintChildLaunchCommands endpoint pollSeconds
          launches = fixtureLaunches fixture [IssueNumber 10, IssueNumber 11]
      mapM_ prepareExistingGitWorkdir launches
      run <- runLaunches ExecuteActions (Just endpoint) childLaunch launches
      requests <- commandRequests <$> getRequests
      secondConfigExists <- doesFileExist ((launches !! 1).launchConfigPath)
      sequenceAnd
        [ assert "issue fanout JSON-RPC failure exits non-zero" (run.launchExitCode /= ExitSuccess)
        , assert "issue fanout JSON-RPC failure reports request id 8000" $
            "app-server JSON-RPC error for request id 8000: worker boom" `Text.isInfixOf` Text.pack run.launchStderr
        , assert "issue fanout JSON-RPC failure stops before later child-thread requests" $
            requestMethods requests == [Just "thread/start"] && requestIds requests == [Just (Number 8000)]
        , assert "issue fanout JSON-RPC failure does not write later child config" $
            not secondConfigExists
        ]

issueFanoutExecuteFormatsDecodeFailure :: IO Bool
issueFanoutExecuteFormatsDecodeFailure =
  withEndpointBackedAppServer workerDecodeFailureResponse \endpoint getRequests ->
    withFanoutFixture "decode-failure" \fixture -> do
      let pollSeconds = pollSecondsForTest 13
          childLaunch = PrintChildLaunchCommands endpoint pollSeconds
          launches = fixtureLaunches fixture [IssueNumber 10, IssueNumber 11]
      mapM_ prepareExistingGitWorkdir launches
      run <- runLaunches ExecuteActions (Just endpoint) childLaunch launches
      requests <- commandRequests <$> getRequests
      secondConfigExists <- doesFileExist ((launches !! 1).launchConfigPath)
      sequenceAnd
        [ assert "issue fanout decode failure exits non-zero" (run.launchExitCode /= ExitSuccess)
        , assert "issue fanout decode failure reports formatted decode text" $
            "app-server JSON decode failed:" `Text.isInfixOf` Text.pack run.launchStderr
        , assert "issue fanout decode failure stops before later child-thread requests" $
            requestMethods requests == [Just "thread/start"] && requestIds requests == [Just (Number 8000)]
        , assert "issue fanout decode failure does not write later child config" $
            not secondConfigExists
        ]

data FanoutFixture = FanoutFixture
  { fixtureRoot :: FilePath
  , fixtureImplementersRoot :: FilePath
  , fixtureWorkdirRoot :: FilePath
  }

withFanoutFixture :: String -> (FanoutFixture -> IO a) -> IO a
withFanoutFixture label action =
  bracket setup cleanup action
 where
  setup = do
    tmp <- getTemporaryDirectory
    pid <- getProcessID
    let root = tmp </> ("moifold-issue-fanout-app-server-" <> label <> "-" <> show pid)
    exists <- doesDirectoryExist root
    whenExists exists (removePathForcibly root)
    createDirectoryIfMissing True root
    pure
      FanoutFixture
        { fixtureRoot = root
        , fixtureImplementersRoot = root </> "implementers"
        , fixtureWorkdirRoot = root </> "worktrees"
        }
  cleanup fixture =
    removePathForcibly fixture.fixtureRoot

fixtureLaunches :: FanoutFixture -> [IssueNumber] -> [IssueImplementerLaunchPlan]
fixtureLaunches fixture =
  fmap (fixtureLaunch fixture)

fixtureLaunch :: FanoutFixture -> IssueNumber -> IssueImplementerLaunchPlan
fixtureLaunch fixture =
  issueImplementerLaunchPlan fanoutConfig plannerConfig
 where
  fanoutConfig =
    (defaultIssuePlanningFanoutConfig fixture.fixtureImplementersRoot)
      { fanoutWorkdirRoot = Just fixture.fixtureWorkdirRoot
      }
  plannerConfig = PlannerConfig (RepoName "soulomoon/mlf2") (maxParallelForTest 4) []

fixtureWorkdir :: FanoutFixture -> IssueNumber -> FilePath
fixtureWorkdir fixture issue =
  fixture.fixtureWorkdirRoot </> ("soulomoon_mlf2__issue" <> show (unIssueNumber issue))

fixtureStateDir :: FanoutFixture -> IssueNumber -> FilePath
fixtureStateDir fixture issue =
  fixture.fixtureImplementersRoot </> ("soulomoon_mlf2__issue" <> show (unIssueNumber issue))

prepareExistingGitWorkdir :: IssueImplementerLaunchPlan -> IO ()
prepareExistingGitWorkdir launch =
  case launch.launchWorkdir of
    Nothing -> pure ()
    Just workdir -> do
      createDirectoryIfMissing True workdir
      runProcessIn workdir "git" ["init", "-q"]
      runProcessIn workdir "git" ["remote", "add", "origin", "https://github.com/soulomoon/mlf2.git"]

runProcessIn :: FilePath -> FilePath -> [String] -> IO ()
runProcessIn workdir command args = do
  (_, _, _, processHandle) <- createProcess (proc command args) {cwd = Just workdir}
  exitCode <- waitForProcess processHandle
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code -> die ("test setup command failed with exit " <> show code <> ": " <> unwords (command : args))

successfulThreadStartResponse :: Value -> IO Value
successfulThreadStartResponse request =
  pure $
    case requestId request of
      Just (Number 8000) -> jsonRpcResult request (threadStartResult "created-thread-10")
      Just (Number 8001) -> jsonRpcResult request (threadStartResult "created-thread-11")
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

data LaunchRun = LaunchRun
  { launchExitCode :: ExitCode
  , launchStdout :: String
  , launchStderr :: String
  }

runLaunches :: ActionExecutionMode -> Maybe AppServerEndpoint -> IssueImplementerChildLaunch -> [IssueImplementerLaunchPlan] -> IO LaunchRun
runLaunches mode maybeEndpoint childLaunch launches = do
  (exitCode, stdoutText, stderrText) <-
    captureStdoutStderr (runIssueImplementerLaunchesDetailed mode maybeEndpoint childLaunch launches >> pure ())
  pure
    LaunchRun
      { launchExitCode = exitCode
      , launchStdout = stdoutText
      , launchStderr = stderrText
      }

captureStdoutStderr :: IO () -> IO (ExitCode, String, String)
captureStdoutStderr action =
  mask \restore -> do
    hFlush IO.stdout
    hFlush IO.stderr
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
          hFlush IO.stdout
          hFlush IO.stderr
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

launchPendingManifestPath :: FilePath -> FilePath
launchPendingManifestPath stateDir =
  stateDir </> "launch-pending.json"

launchFinalizedManifestPath :: FilePath -> FilePath
launchFinalizedManifestPath stateDir =
  stateDir </> "launch-finalized.json"

outputContainsAll :: [Text] -> String -> Bool
outputContainsAll needles output =
  let rendered = Text.pack output
   in all (`Text.isInfixOf` rendered) needles

whenExists :: Bool -> IO () -> IO ()
whenExists exists action =
  if exists then action else pure ()
