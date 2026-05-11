{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module ObserveCommandSpec
  ( observeCommandTests
  ) where

import CodexWatcher.Cli.Command.Observe (observeOnce)
import CodexWatcher.Cli.Types (ObserveOnceCli (..))
import CodexWatcher.Core.Ids (RepoName (..), ThreadId (..), TurnId (..), unThreadId)
import CodexWatcher.Core.Kinds (Domain (..))
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import Control.Exception (bracket, catch, evaluate, finally, mask)
import Control.Monad (when)
import Data.Aeson
  ( Value (..)
  , encode
  , object
  , (.=)
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, getTemporaryDirectory, removePathForcibly)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO (hClose, hFlush, hGetContents, stderr, stdout)
import System.Posix.IO qualified as Posix
import System.Posix.Process (getProcessID)
import TestSupport.AppServer (jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, maxParallelForTest, sequenceAnd)

observeCommandTests :: IO Bool
observeCommandTests =
  sequenceAnd
    [ observeExecuteWithoutEndpointFails
    , observeDryRunWithoutEndpointUsesNullInterpreter
    , observeExecuteWithConfiguredEndpointReachesAppServer
    ]

observeExecuteWithoutEndpointFails :: IO Bool
observeExecuteWithoutEndpointFails =
  withObserveFixture "missing-endpoint" \cli -> do
    run <- runObserve (cli {observeCliExecute = True, observeCliEndpoint = Nothing})
    sequenceAnd
      [ assert "observe execute without endpoint exits non-zero" (run.observeExitCode /= ExitSuccess)
      , assert "observe execute without endpoint reports required endpoint flags" $
          "--execute requires --app-server-host and --app-server-port" `Text.isInfixOf` Text.pack run.observeStderr
      , assert "observe execute without endpoint produces no success output" $
          not ("mode:" `Text.isInfixOf` Text.pack run.observeStdout)
      ]

observeDryRunWithoutEndpointUsesNullInterpreter :: IO Bool
observeDryRunWithoutEndpointUsesNullInterpreter =
  withObserveFixture "dry-run-without-endpoint" \cli -> do
    run <- runObserve (cli {observeCliExecute = False, observeCliEndpoint = Nothing})
    sequenceAnd
      [ assert "observe dry-run without endpoint exits successfully" (run.observeExitCode == ExitSuccess)
      , assert "observe dry-run reports one planned action and dry-run mode" $
          outputContainsAll ["event: IssuePlanningTurnStarted", "actions: 1", "mode: DryRunActions"] run.observeStdout
      , assert "observe dry-run without endpoint leaves stderr empty" (null run.observeStderr)
      ]

observeExecuteWithConfiguredEndpointReachesAppServer :: IO Bool
observeExecuteWithConfiguredEndpointReachesAppServer =
  withEndpointBackedAppServer observeTurnResponse \endpoint getRequests ->
    withObserveFixture "execute-with-endpoint" \cli -> do
      run <- runObserve (cli {observeCliExecute = True, observeCliEndpoint = Just endpoint})
      requests <- getRequests
      let methods = requestMethods requests
          ids = requestIds requests
      sequenceAnd
        [ assert "observe execute with endpoint exits successfully" (run.observeExitCode == ExitSuccess)
        , assert "observe execute reports execute mode" $
            outputContainsAll ["event: IssuePlanningTurnStarted", "actions: 1", "mode: ExecuteActions"] run.observeStdout
        , assert "observe execute reaches configured app-server session and turn request" $
            methods == [Just "initialize", Just "initialized", Just "turn/start"]
              && ids == [Just (Number 0), Nothing, Just (Number 1)]
        , assert "observe execute turn/start uses configured planner thread" $
            case requests of
              _initialize : _initialized : turnStart : _ ->
                textParam "threadId" turnStart == Just (unThreadId plannerThreadId)
              _ -> False
        , assert "observe execute leaves stderr empty" (null run.observeStderr)
        ]

data ObserveRun = ObserveRun
  { observeExitCode :: ExitCode
  , observeStdout :: String
  , observeStderr :: String
  }

runObserve :: ObserveOnceCli -> IO ObserveRun
runObserve cli = do
  (exitCode, stdoutText, stderrText) <- captureStdoutStderr (observeOnce cli)
  pure
    ObserveRun
      { observeExitCode = exitCode
      , observeStdout = stdoutText
      , observeStderr = stderrText
      }

withObserveFixture :: String -> (ObserveOnceCli -> IO a) -> IO a
withObserveFixture label action =
  bracket setup cleanup \(_root, eventsPath, stateDir, workdir) -> do
    writeEvents eventsPath [IssuePlanningInitialized (PlannerConfig testRepo (maxParallelForTest 8) [])]
    action (baseObserveCli eventsPath stateDir workdir)
 where
  setup = do
    tmp <- getTemporaryDirectory
    pid <- getProcessID
    let root = tmp </> ("moifold-observe-command-" <> label <> "-" <> show pid)
        eventsPath = root </> "events.jsonl"
        stateDir = root </> "state"
        workdir = root </> "work"
    exists <- doesDirectoryExist root
    when exists (removePathForcibly root)
    createDirectoryIfMissing True stateDir
    createDirectoryIfMissing True workdir
    pure (root, eventsPath, stateDir, workdir)
  cleanup (root, _eventsPath, _stateDir, _workdir) =
    removePathForcibly root

baseObserveCli :: FilePath -> FilePath -> FilePath -> ObserveOnceCli
baseObserveCli eventsPath stateDir workdir =
  ObserveOnceCli
    { observeCliEventsPath = eventsPath
    , observeCliStateDir = stateDir
    , observeCliRepo = testRepo
    , observeCliWorkdir = workdir
    , observeCliDomain = IssuePlanning
    , observeCliObservation = "turn-started"
    , observeCliExecute = False
    , observeCliEndpoint = Nothing
    , observeCliThreadId = Just plannerThreadId
    , observeCliTurnId = Just plannerTurnId
    , observeCliImplementationTurnId = Nothing
    , observeCliPrNumber = Nothing
    , observeCliCommitSha = Nothing
    , observeCliMergeCommitSha = Nothing
    , observeCliReason = Nothing
    , observeCliPlanMarkdown = Nothing
    , observeCliReviewThreadIds = []
    , observeCliComment = Nothing
    }

writeEvents :: FilePath -> [WatcherEvent] -> IO ()
writeEvents eventsPath events =
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

observeTurnResponse :: Value -> IO Value
observeTurnResponse request =
  pure $
    jsonRpcResult request $
      object ["turn" .= object ["id" .= ("turn-plan" :: Text)]]

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

outputContainsAll :: [Text] -> String -> Bool
outputContainsAll needles output =
  let rendered = Text.pack output
   in all (`Text.isInfixOf` rendered) needles

testRepo :: RepoName
testRepo =
  RepoName "soulomoon/mlf2"

plannerThreadId :: ThreadId
plannerThreadId =
  ThreadId "planner-thread"

plannerTurnId :: TurnId
plannerTurnId =
  TurnId "turn-plan"
