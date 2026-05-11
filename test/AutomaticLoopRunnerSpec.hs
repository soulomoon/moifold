{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module AutomaticLoopRunnerSpec
  ( automaticLoopRunnerTests
  ) where

import CodexWatcher.AppServerClient (AppServerClientFailure (..), AppServerEndpoint)
import CodexWatcher.AutomaticLoop.Runner (retryableAutomaticLoopFailure, runAutomaticLoop)
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), unThreadId)
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Daemon (DaemonFailure (..))
import CodexWatcher.DaemonLoop (DaemonLoopFailure (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import Control.Exception (bracket, try)
import Control.Monad (when)
import Data.Aeson
  ( Value (..)
  , encode
  , object
  , (.=)
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, getTemporaryDirectory, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Error (catchIOError)
import System.Posix.Process (getProcessID)
import TestSupport.AppServer (jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, maxParallelForTest, pollSecondsForTest, sequenceAnd)

automaticLoopRunnerTests :: IO Bool
automaticLoopRunnerTests =
  sequenceAnd
    [ automaticLoopExecuteUsesConfiguredEndpoint
    , automaticLoopDryRunDoesNotReachEndpoint
    , automaticLoopRetryClassificationKeepsTransportTransient
    ]

automaticLoopExecuteUsesConfiguredEndpoint :: IO Bool
automaticLoopExecuteUsesConfiguredEndpoint =
  withEndpointBackedAppServer automaticLoopResponse \endpoint getRequests ->
    withAutomaticLoopFixture "execute-endpoint" \fixture -> do
      result <- runLoop (baseLoopCli fixture endpoint True)
      requests <- getRequests
      let methods = requestMethods requests
          ids = requestIds requests
      sequenceAnd
        [ assert "automatic loop execute exits successfully" (result == ExitSuccess)
        , assert "automatic loop execute initializes default app-server session" $
            take 2 methods == [Just "initialize", Just "initialized"]
              && take 2 ids == [Just (Number 0), Nothing]
        , assert "automatic loop execute sends planner thread and turn starts to configured endpoint" $
            methods == [Just "initialize", Just "initialized", Just "thread/start", Just "initialize", Just "initialized", Just "turn/start"]
              && ids == [Just (Number 0), Nothing, Just (Number 1), Just (Number 0), Nothing, Just (Number 2)]
        , assert "automatic loop execute starts planner turn on returned thread" $
            case requests of
              _threadInitialize : _threadInitialized : _threadStart : _turnInitialize : _turnInitialized : turnStart : _ ->
                textParam "threadId" turnStart == Just (unThreadId plannerThreadId)
              _ -> False
        ]

automaticLoopDryRunDoesNotReachEndpoint :: IO Bool
automaticLoopDryRunDoesNotReachEndpoint =
  withEndpointBackedAppServer automaticLoopResponse \endpoint getRequests ->
    withAutomaticLoopFixture "dry-run-no-endpoint-traffic" \fixture -> do
      result <- runLoop (baseLoopCli fixture endpoint False)
      requests <- getRequests
      sequenceAnd
        [ assert "automatic loop dry-run exits successfully" (result == ExitSuccess)
        , assert "automatic loop dry-run records no live app-server traffic" (null requests)
        ]

automaticLoopRetryClassificationKeepsTransportTransient :: IO Bool
automaticLoopRetryClassificationKeepsTransportTransient =
  sequenceAnd
    [ assert "automatic loop retries app-server transport failures" $
        retryableAutomaticLoopFailure (DaemonLoopAppServerFailure (AppServerTransportFailure "connection reset"))
    , assert "automatic loop keeps app-server replay/decode failures fatal" $
        not (retryableAutomaticLoopFailure (DaemonLoopAppServerFailure (AppServerDecodeFailure "bad turn payload")))
    , assert "automatic loop keeps event replay failures fatal" $
        not (retryableAutomaticLoopFailure (DaemonLoopDaemonFailure (DaemonEventLogDecodeFailed "bad event log")))
    , assert "automatic loop keeps unexpected start plans fatal" $
        not (retryableAutomaticLoopFailure (DaemonLoopUnexpectedStartPlan "invalid start plan"))
    ]

data AutomaticLoopFixture = AutomaticLoopFixture
  { fixtureEventsPath :: FilePath
  , fixtureStateDir :: FilePath
  , fixtureWorkdir :: FilePath
  }

withAutomaticLoopFixture :: String -> (AutomaticLoopFixture -> IO a) -> IO a
withAutomaticLoopFixture label action =
  bracket setup cleanup \(_root, fixture) -> do
    writeEvents fixture.fixtureEventsPath [IssuePlanningInitialized (PlannerConfig testRepo (maxParallelForTest 8) [])]
    action fixture
 where
  setup = do
    tmp <- getTemporaryDirectory
    pid <- getProcessID
    let root = tmp </> ("moifold-automatic-loop-runner-" <> label <> "-" <> show pid)
        fixture =
          AutomaticLoopFixture
            { fixtureEventsPath = root </> "events.jsonl"
            , fixtureStateDir = root </> "state"
            , fixtureWorkdir = root </> "work"
            }
    cleanupRoot root
    createDirectoryIfMissing True fixture.fixtureStateDir
    createDirectoryIfMissing True fixture.fixtureWorkdir
    pure (root, fixture)
  cleanup (root, _fixture) =
    cleanupRoot root

cleanupRoot :: FilePath -> IO ()
cleanupRoot root = do
  exists <- doesDirectoryExist root
  when exists (removePathForcibly root `catchIOError` \_ -> pure ())

baseLoopCli :: AutomaticLoopFixture -> AppServerEndpoint -> Bool -> LoopCli
baseLoopCli fixture endpoint execute =
  LoopCli
    { loopCliDomain = IssuePlanning
    , loopCliEventsPath = fixture.fixtureEventsPath
    , loopCliStateDir = fixture.fixtureStateDir
    , loopCliRepo = testRepo
    , loopCliWorkdir = fixture.fixtureWorkdir
    , loopCliEndpoint = endpoint
    , loopCliPollSeconds = pollSecondsForTest 1
    , loopCliExecute = execute
    , loopCliLoop = False
    , loopCliIterations = Nothing
    , loopCliPidFile = Nothing
    , loopCliPlannerThread = Nothing
    , loopCliScopeIssues = []
    , loopCliImplementersRoot = Nothing
    , loopCliOpenIssues = Nothing
    , loopCliActiveIssues = Nothing
    , loopCliImplementerWorkdirRoot = Nothing
    , loopCliWorkdirRoot = Nothing
    , loopCliBranchPrefix = "codex/issue-"
    , loopCliThreadPrefix = "issue-"
    }

runLoop :: LoopCli -> IO ExitCode
runLoop cli = do
  result <- try (runAutomaticLoop cli) :: IO (Either ExitCode ())
  pure case result of
    Left code -> code
    Right () -> ExitSuccess

writeEvents :: FilePath -> [WatcherEvent] -> IO ()
writeEvents eventsPath events =
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

automaticLoopResponse :: Value -> IO Value
automaticLoopResponse request =
  pure $
    case requestMethod request of
      Just "thread/start" ->
        jsonRpcResult request (object ["threadId" .= unThreadId plannerThreadId])
      Just "turn/start" ->
        jsonRpcResult request (object ["turnId" .= ("turn-plan" :: Text)])
      _ ->
        jsonRpcResult request (object [])

requestMethods :: [Value] -> [Maybe Text]
requestMethods =
  fmap requestMethod

requestMethod :: Value -> Maybe Text
requestMethod request =
  case lookupValue "method" request of
    Just (String method) -> Just method
    _ -> Nothing

requestIds :: [Value] -> [Maybe Value]
requestIds =
  fmap requestId

requestId :: Value -> Maybe Value
requestId request =
  case lookupValue "id" request of
    Just Null -> Nothing
    value -> value

textParam :: Text -> Value -> Maybe Text
textParam key request =
  case lookupValue key =<< requestParams request of
    Just (String value) -> Just value
    _ -> Nothing

requestParams :: Value -> Maybe Value
requestParams =
  lookupValue "params"

testRepo :: RepoName
testRepo =
  RepoName "soulomoon/mlf2"

plannerThreadId :: ThreadId
plannerThreadId =
  ThreadId "planner-thread"
