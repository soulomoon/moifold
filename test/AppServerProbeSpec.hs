{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module AppServerProbeSpec
  ( appServerProbeCommandTests
  ) where

import CodexWatcher.Cli.Command.AppServerProbe (probeAppServer)
import CodexWatcher.Cli.Types (AppServerProbeCli (..))
import CodexWatcher.Workflow.Agent.Ids (ThreadId (..), unThreadId)
import CodexWatcher.Workflow.Agent.Codex.Transport (AppServerEndpoint)
import Control.Exception (catch, evaluate, finally, mask)
import Data.Aeson
  ( Value (..)
  , object
  , (.=)
  )
import Data.Foldable qualified as Foldable
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (ExitCode (..))
import System.IO (hClose, hFlush, hGetContents, stderr, stdout)
import System.Posix.IO qualified as Posix
import TestSupport.AppServer (jsonRpcError, jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, sequenceAnd)

appServerProbeCommandTests :: IO Bool
appServerProbeCommandTests =
  sequenceAnd
    [ appServerProbeInitializeOnlySuccess
    , appServerProbeExistingThreadSmokeSuccess
    , appServerProbeSmokeTurnCreatesThreadSuccess
    , appServerProbeThreadReadFailure
    , appServerProbeThreadStartFailure
    , appServerProbeTurnStartParseFailure
    ]

appServerProbeInitializeOnlySuccess :: IO Bool
appServerProbeInitializeOnlySuccess =
  runProbe "initialize-only" successResponse baseProbeCli \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe initialize-only exits successfully" (run.probeExitCode == ExitSuccess)
      , assert "app-server probe initialize-only sends only explicit initialize command" $
          requestMethods requests == [Just "initialize"] && requestIds requests == [Just (Number 1)]
      , assert "app-server probe initialize carries probe client identity" $
          case requests of
            request : _ ->
              textAtPath ["params", "clientInfo", "name"] request == Just "moifold-probe"
                && textAtPath ["params", "clientInfo", "version"] request == Just "0.1.0"
            [] -> False
      , assert "app-server probe initialize-only prints success output" $
          outputContainsAll ["ok initialize", "app-server probe passed"] run.probeStdout
      , assert "app-server probe initialize-only leaves stderr empty" (null run.probeStderr)
      ]

appServerProbeExistingThreadSmokeSuccess :: IO Bool
appServerProbeExistingThreadSmokeSuccess =
  runProbe
    "existing-thread-smoke"
    successResponse
    ( \endpoint ->
        (baseProbeCli endpoint)
          { appServerProbeCliThreadId = Just existingThreadId
          , appServerProbeCliCreateSmokeThread = True
          , appServerProbeCliStartSmokeTurn = True
          }
    ) \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe existing-thread smoke exits successfully" (run.probeExitCode == ExitSuccess)
      , assert "app-server probe existing-thread smoke sends command methods in order" $
          requestMethods requests == [Just "initialize", Just "thread/read", Just "thread/start", Just "turn/start"]
      , assert "app-server probe existing-thread smoke uses command request ids 1 through 4" $
          requestIds requests == [Just (Number 1), Just (Number 2), Just (Number 3), Just (Number 4)]
      , assert "app-server probe thread/read uses configured thread id without turns" $
          case requests of
            _ : threadRead : _ ->
              textParam "threadId" threadRead == Just (unThreadId existingThreadId)
                && boolParam "includeTurns" threadRead == Just False
            _ -> False
      , assert "app-server probe smoke thread carries workdir and developer instructions" $
          case requests of
            _ : _ : threadStart : _ ->
              textParam "cwd" threadStart == Just probeWorkdir
                && textParam "developerInstructions" threadStart == Just "moifold app-server smoke probe"
            _ -> False
      , assert "app-server probe smoke turn uses existing thread and prompt" $
          case requests of
            _ : _ : _ : turnStart : _ ->
              textParam "threadId" turnStart == Just (unThreadId existingThreadId)
                && textParam "cwd" turnStart == Just probeWorkdir
                && turnInputText turnStart == Just "Reply with OK for a moifold app-server smoke probe."
            _ -> False
      , assert "app-server probe existing-thread smoke prints all success lines" $
          outputContainsAll
            [ "ok initialize"
            , "ok thread/read existing-thread"
            , "ok thread/start smoke-thread"
            , "ok turn/start smoke-turn"
            , "app-server probe passed"
            ]
            run.probeStdout
      , assert "app-server probe existing-thread smoke leaves stderr empty" (null run.probeStderr)
      ]

appServerProbeSmokeTurnCreatesThreadSuccess :: IO Bool
appServerProbeSmokeTurnCreatesThreadSuccess =
  runProbe
    "smoke-turn-created-thread"
    successResponse
    (\endpoint -> (baseProbeCli endpoint) {appServerProbeCliStartSmokeTurn = True}) \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe smoke-turn without thread exits successfully" (run.probeExitCode == ExitSuccess)
      , assert "app-server probe smoke-turn without thread creates thread before turn" $
          requestMethods requests == [Just "initialize", Just "thread/start", Just "turn/start"]
      , assert "app-server probe smoke-turn without thread uses ids 1, 3, and 4" $
          requestIds requests == [Just (Number 1), Just (Number 3), Just (Number 4)]
      , assert "app-server probe smoke-turn uses created smoke thread id" $
          case requests of
            _ : _ : turnStart : _ ->
              textParam "threadId" turnStart == Just "smoke-thread"
            _ -> False
      , assert "app-server probe smoke-turn without thread prints created-thread success" $
          outputContainsAll
            [ "ok initialize"
            , "ok thread/start smoke-thread"
            , "ok turn/start smoke-turn"
            , "app-server probe passed"
            ]
            run.probeStdout
      ]

appServerProbeThreadReadFailure :: IO Bool
appServerProbeThreadReadFailure =
  runProbe
    "thread-read-failure"
    threadReadFailureResponse
    ( \endpoint ->
        (baseProbeCli endpoint)
          { appServerProbeCliThreadId = Just existingThreadId
          , appServerProbeCliCreateSmokeThread = True
          , appServerProbeCliStartSmokeTurn = True
          }
    ) \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe thread/read failure exits non-zero" (run.probeExitCode /= ExitSuccess)
      , assert "app-server probe thread/read failure uses formatted request id 2 JSON-RPC text" $
          "app-server JSON-RPC error for request id 2: read boom" `Text.isInfixOf` Text.pack run.probeStderr
      , assert "app-server probe thread/read failure does not print final success" $
          not ("app-server probe passed" `Text.isInfixOf` Text.pack run.probeStdout)
      , assert "app-server probe thread/read failure stops before smoke requests" $
          requestMethods requests == [Just "initialize", Just "thread/read"]
            && requestIds requests == [Just (Number 1), Just (Number 2)]
      ]

appServerProbeThreadStartFailure :: IO Bool
appServerProbeThreadStartFailure =
  runProbe
    "thread-start-failure"
    threadStartFailureResponse
    ( \endpoint ->
        (baseProbeCli endpoint)
          { appServerProbeCliThreadId = Just existingThreadId
          , appServerProbeCliCreateSmokeThread = True
          , appServerProbeCliStartSmokeTurn = True
          }
    ) \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe thread/start failure exits non-zero" (run.probeExitCode /= ExitSuccess)
      , assert "app-server probe thread/start failure uses formatted request id 3 JSON-RPC text" $
          "app-server JSON-RPC error for request id 3: start boom" `Text.isInfixOf` Text.pack run.probeStderr
      , assert "app-server probe thread/start failure does not print final success" $
          not ("app-server probe passed" `Text.isInfixOf` Text.pack run.probeStdout)
      , assert "app-server probe thread/start failure stops before turn/start" $
          requestMethods requests == [Just "initialize", Just "thread/read", Just "thread/start"]
            && requestIds requests == [Just (Number 1), Just (Number 2), Just (Number 3)]
      ]

appServerProbeTurnStartParseFailure :: IO Bool
appServerProbeTurnStartParseFailure =
  runProbe
    "turn-start-parse-failure"
    turnStartParseFailureResponse
    ( \endpoint ->
        (baseProbeCli endpoint)
          { appServerProbeCliThreadId = Just existingThreadId
          , appServerProbeCliCreateSmokeThread = True
          , appServerProbeCliStartSmokeTurn = True
          }
    ) \run -> do
    let requests = commandRequests run.probeRequests
    sequenceAnd
      [ assert "app-server probe turn/start parse failure exits non-zero" (run.probeExitCode /= ExitSuccess)
      , assert "app-server probe turn/start parse failure uses formatted decode text" $
          "app-server JSON decode failed:" `Text.isInfixOf` Text.pack run.probeStderr
      , assert "app-server probe turn/start parse failure does not print final success" $
          not ("app-server probe passed" `Text.isInfixOf` Text.pack run.probeStdout)
      , assert "app-server probe turn/start parse failure reaches turn/start command" $
          requestMethods requests == [Just "initialize", Just "thread/read", Just "thread/start", Just "turn/start"]
            && requestIds requests == [Just (Number 1), Just (Number 2), Just (Number 3), Just (Number 4)]
      ]

data ProbeRun = ProbeRun
  { probeExitCode :: ExitCode
  , probeStdout :: String
  , probeStderr :: String
  , probeRequests :: [Value]
  }

runProbe
  :: String
  -> (Value -> IO Value)
  -> (AppServerEndpoint -> AppServerProbeCli)
  -> (ProbeRun -> IO Bool)
  -> IO Bool
runProbe _label responseFor optionsFor action =
  withEndpointBackedAppServer responseFor \endpoint getRequests -> do
    (exitCode, stdoutText, stderrText) <- captureStdoutStderr (probeAppServer (optionsFor endpoint))
    requests <- getRequests
    action
      ProbeRun
        { probeExitCode = exitCode
        , probeStdout = stdoutText
        , probeStderr = stderrText
        , probeRequests = requests
        }

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
      ( restore (action >> pure ExitSuccess)
          `catch` \(code :: ExitCode) -> pure code
      )
        `finally` restoreStreams
    stdoutText <- hGetContents stdoutRead
    stderrText <- hGetContents stderrRead
    _ <- evaluate (length stdoutText)
    _ <- evaluate (length stderrText)
    hClose stdoutRead
    hClose stderrRead
    pure (exitCode, stdoutText, stderrText)

baseProbeCli :: AppServerEndpoint -> AppServerProbeCli
baseProbeCli endpoint =
  AppServerProbeCli
    { appServerProbeCliEndpoint = endpoint
    , appServerProbeCliThreadId = Nothing
    , appServerProbeCliCreateSmokeThread = False
    , appServerProbeCliStartSmokeTurn = False
    , appServerProbeCliWorkdir = Text.unpack probeWorkdir
    }

successResponse :: Value -> IO Value
successResponse request =
  pure $
    case requestMethod request of
      Just "thread/read" -> jsonRpcResult request threadReadResult
      Just "thread/start" -> jsonRpcResult request threadStartResult
      Just "turn/start" -> jsonRpcResult request turnStartResult
      _ -> jsonRpcResult request (object [])

threadReadFailureResponse :: Value -> IO Value
threadReadFailureResponse request =
  pure $
    case requestMethod request of
      Just "thread/read" -> jsonRpcError request (-32000) "read boom"
      _ -> jsonRpcResult request (object [])

threadStartFailureResponse :: Value -> IO Value
threadStartFailureResponse request =
  pure $
    case requestMethod request of
      Just "thread/read" -> jsonRpcResult request threadReadResult
      Just "thread/start" -> jsonRpcError request (-32000) "start boom"
      _ -> jsonRpcResult request (object [])

turnStartParseFailureResponse :: Value -> IO Value
turnStartParseFailureResponse request =
  pure $
    case requestMethod request of
      Just "thread/read" -> jsonRpcResult request threadReadResult
      Just "thread/start" -> jsonRpcResult request threadStartResult
      Just "turn/start" -> jsonRpcResult request (object ["turn" .= object ["status" .= ("queued" :: Text)]])
      _ -> jsonRpcResult request (object [])

threadReadResult :: Value
threadReadResult =
  object
    [ "thread" .= object ["id" .= unThreadId existingThreadId]
    , "turns" .= ([] :: [Value])
    ]

threadStartResult :: Value
threadStartResult =
  object ["thread" .= object ["id" .= ("smoke-thread" :: Text)]]

turnStartResult :: Value
turnStartResult =
  object ["turn" .= object ["id" .= ("smoke-turn" :: Text)]]

commandRequests :: [Value] -> [Value]
commandRequests =
  filter \request ->
    case requestMethod request of
      Just "initialized" -> False
      Just "initialize" | requestId request == Just (Number 0) -> False
      _ -> True

requestId :: Value -> Maybe Value
requestId =
  lookupValue "id"

requestMethod :: Value -> Maybe Text
requestMethod request =
  case lookupValue "method" request of
    Just (String method) -> Just method
    _ -> Nothing

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

boolParam :: Text -> Value -> Maybe Bool
boolParam key request =
  case lookupValue key =<< requestParams request of
    Just (Bool value) -> Just value
    _ -> Nothing

textAtPath :: [Text] -> Value -> Maybe Text
textAtPath path value =
  case lookupPath path value of
    Just (String text) -> Just text
    _ -> Nothing

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value =
  Just value
lookupPath (key : rest) value =
  lookupValue key value >>= lookupPath rest

turnInputText :: Value -> Maybe Text
turnInputText request = do
  Array inputItems <- lookupValue "input" =<< requestParams request
  case Foldable.toList inputItems of
    firstItem : _ ->
      case lookupValue "text" firstItem of
        Just (String text) -> Just text
        _ -> Nothing
    [] -> Nothing

outputContainsAll :: [Text] -> String -> Bool
outputContainsAll needles output =
  let rendered = Text.pack output
   in all (`Text.isInfixOf` rendered) needles

existingThreadId :: ThreadId
existingThreadId =
  ThreadId "existing-thread"

probeWorkdir :: Text
probeWorkdir =
  "/tmp/moifold-app-server-probe-test"
