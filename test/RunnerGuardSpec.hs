{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module RunnerGuardSpec
  ( runnerGuardActiveTurnInspectionTests
  ) where

import CodexWatcher.AppServerClient
  ( AppServerClientFailure (..)
  , AppServerEndpoint
  , JsonRpcError (..)
  , formatAppServerClientFailure
  )
import CodexWatcher.Core.Ids (RepoName (..), RequestId (..), ThreadId (..), TurnId (..), unThreadId, unTurnId)
import CodexWatcher.Core.Kinds (Domain (IssuePlanning))
import CodexWatcher.Core.Limits (StaleSeconds, unStaleSeconds)
import CodexWatcher.Domain.IssuePlanning.Types (PlannerConfig (..))
import CodexWatcher.EventLog.Types (WatcherEvent (..))
import CodexWatcher.RunnerGuard
  ( RunnerGuardAction (..)
  , RunnerGuardConfig (..)
  , RunnerGuardProblem (..)
  , checkRunnerGuard
  )
import Data.Aeson
  ( Value (..)
  , encode
  , object
  , (.=)
  )
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (addUTCTime, getCurrentTime)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, removePathForcibly, setModificationTime)
import System.FilePath ((</>))
import System.IO.Error (catchIOError)
import System.Posix.Process (getProcessID)
import TestSupport.AppServer (jsonRpcError, jsonRpcResult, withEndpointBackedAppServer)
import TestSupport.Workflow (assert, lookupValue, maxParallelForTest, sequenceAnd, staleSecondsForTest)

runnerGuardActiveTurnInspectionTests :: IO Bool
runnerGuardActiveTurnInspectionTests =
  sequenceAnd
    [ runnerGuardReadsActiveTurnShape
    , runnerGuardMaterializationPendingThreshold
    , runnerGuardActiveTurnProblemMappings
    , runnerGuardAppServerFailureDetails
    ]

runnerGuardReadsActiveTurnShape :: IO Bool
runnerGuardReadsActiveTurnShape =
  withRunnerGuardFixture "shape" Fresh runningTurnResponse \getRequests config -> do
    problem <- checkRunnerGuard config
    requests <- getRequests
    let readRequests = threadReadRequests requests
    sequenceAnd
      [ assert "runner guard active running turn is healthy while event log is fresh" (problem == Nothing)
      , assert "runner guard issues exactly one active thread/read" (length readRequests == 1)
      , assert "runner guard thread/read uses request id 1, active thread, and includeTurns=true" $
          case readRequests of
            request : _ -> threadReadMatches True request
            [] -> False
      ]

runnerGuardMaterializationPendingThreshold :: IO Bool
runnerGuardMaterializationPendingThreshold =
  sequenceAnd
    [ runMaterialization "fresh" Fresh Nothing
    , runMaterialization "stale" Stale (Just "active planner turn is still materializing")
    ]
 where
  runMaterialization label freshness expectedSummary =
    withRunnerGuardFixture ("materialization-" <> label) freshness materializationResponse \getRequests config -> do
      problem <- checkRunnerGuard config
      requests <- getRequests
      let readRequests = threadReadRequests requests
      sequenceAnd
        [ assert ("runner guard materialization " <> label <> " problem matches stale threshold") $
            case expectedSummary of
              Nothing -> problem == Nothing
              Just summary -> problemSummaryIs summary problem && problemDetailsContainAll ["turn: planner-turn", "thread: planner-thread"] problem
        , assert ("runner guard materialization " <> label <> " first read uses includeTurns=true") $
            case readRequests of
              firstRead : _ -> threadReadMatches True firstRead
              [] -> False
        , assert ("runner guard materialization " <> label <> " fallback read keeps request id 1 and includeTurns=false") $
            case readRequests of
              _ : fallbackRead : _ -> threadReadMatches False fallbackRead
              _ -> False
        ]

runnerGuardActiveTurnProblemMappings :: IO Bool
runnerGuardActiveTurnProblemMappings =
  sequenceAnd (fmap runMappingCase mappingCases)
 where
  runMappingCase testCase =
    withRunnerGuardFixture ("mapping-" <> mappingSlug testCase) Stale (mappingResponse testCase) \_getRequests config -> do
      problem <- checkRunnerGuard config
      sequenceAnd
        [ assert ("runner guard maps " <> Text.unpack (mappingSummary testCase)) (problemMatches (mappingSummary testCase) (mappingDetails testCase) problem)
        , assert ("runner guard action is launch repair for " <> Text.unpack (mappingSummary testCase)) (maybe False ((== LaunchRepairThread) . runnerGuardProblemAction) problem)
        ]

runnerGuardAppServerFailureDetails :: IO Bool
runnerGuardAppServerFailureDetails =
  sequenceAnd
    [ withRunnerGuardFixture "json-rpc-failure" Stale readFailureResponse \_getRequests config -> do
        problem <- checkRunnerGuard config
        let expected =
              formatAppServerClientFailure
                (AppServerJsonRpcFailure (RequestId 1) (JsonRpcError (-32000) "boom" Nothing))
        sequenceAnd
          [ assert "runner guard maps app-server read failure summary" (problemSummaryIs "guard cannot read planner app-server thread" problem)
          , assert "runner guard read failure includes formatted JSON-RPC error" (problemDetailsContain expected problem)
          , assert "runner guard read failure includes stable JSON-RPC prefix" (problemDetailsContain "app-server JSON-RPC error for request id 1: boom" problem)
          ]
    , withRunnerGuardFixture "parse-failure" Stale parseFailureResponse \_getRequests config -> do
        problem <- checkRunnerGuard config
        sequenceAnd
          [ assert "runner guard maps app-server parse failure summary" (problemSummaryIs "guard cannot parse planner app-server turns" problem)
          , assert "runner guard parse failure includes formatted decode prefix" (problemDetailsContain "app-server JSON decode failed:" problem)
          ]
    ]

data FixtureFreshness = Fresh | Stale

withRunnerGuardFixture
  :: String
  -> FixtureFreshness
  -> (Value -> IO Value)
  -> (IO [Value] -> RunnerGuardConfig 'IssuePlanning -> IO Bool)
  -> IO Bool
withRunnerGuardFixture label freshness responseFor action =
  withEndpointBackedAppServer responseFor \endpoint getRequests -> do
    let stateDir = "/tmp/moifold-runner-guard-active-turn-" <> label
        eventsPath = stateDir </> "events.jsonl"
        pidPath = stateDir </> "watcher.pid"
        config = runnerGuardConfig endpoint stateDir eventsPath pidPath
    cleanup stateDir
    createDirectoryIfMissing True stateDir
    writeWatcherPid pidPath
    writeEvents eventsPath activePlanningEvents
    setEventLogFreshness eventsPath freshness config.guardStaleSeconds
    result <- action getRequests config
    cleanup stateDir
    pure result

runnerGuardConfig :: AppServerEndpoint -> FilePath -> FilePath -> FilePath -> RunnerGuardConfig 'IssuePlanning
runnerGuardConfig endpoint stateDir eventsPath pidPath =
  RunnerGuardConfig
    { guardRepo = RepoName "owner/name"
    , guardEventsPath = eventsPath
    , guardStateDir = stateDir
    , guardWatcherPidFile = pidPath
    , guardAppServerEndpoint = endpoint
    , guardStaleSeconds = staleSecondsForTest 1
    , guardRepairCwd = stateDir
    , guardRestartWatcherCommand = "restart watcher"
    , guardRestartGuardCommand = "restart guard"
    }

activePlanningEvents :: [WatcherEvent]
activePlanningEvents =
  [ IssuePlanningInitialized (PlannerConfig (RepoName "owner/name") (maxParallelForTest 8) [])
  , IssuePlanningTurnStarted activeThreadId activeTurnId
  ]

writeEvents :: FilePath -> [WatcherEvent] -> IO ()
writeEvents eventsPath events =
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

writeWatcherPid :: FilePath -> IO ()
writeWatcherPid pidPath = do
  pid <- getProcessID
  writeFile pidPath (show pid <> "\n")

setEventLogFreshness :: FilePath -> FixtureFreshness -> StaleSeconds -> IO ()
setEventLogFreshness eventsPath freshness staleSeconds = do
  now <- getCurrentTime
  let modified =
        case freshness of
          Fresh -> now
          Stale -> addUTCTime (fromIntegral (negate (unStaleSeconds staleSeconds + 5))) now
  setModificationTime eventsPath modified

cleanup :: FilePath -> IO ()
cleanup path = do
  exists <- doesDirectoryExist path
  if exists
    then removePathForcibly path `catchIOError` \_ -> pure ()
    else pure ()

runningTurnResponse :: Value -> IO Value
runningTurnResponse request =
  pure (jsonRpcResult request (threadReadResult [turnObject activeTurnId "running" Nothing]))

materializationResponse :: Value -> IO Value
materializationResponse request
  | requestIncludeTurns request == Just True =
      pure (jsonRpcError request (-32000) "turns not materialized yet")
  | otherwise =
      pure (jsonRpcResult request (threadReadResult []))

readFailureResponse :: Value -> IO Value
readFailureResponse request =
  pure (jsonRpcError request (-32000) "boom")

parseFailureResponse :: Value -> IO Value
parseFailureResponse request =
  pure (jsonRpcResult request (object ["turns" .= ("not a turn array" :: Text)]))

data MappingCase = MappingCase
  { mappingSlug :: String
  , mappingResponse :: Value -> IO Value
  , mappingSummary :: Text
  , mappingDetails :: [Text]
  }

mappingCases :: [MappingCase]
mappingCases =
  [ MappingCase
      "system-error"
      (\request -> pure (jsonRpcResult request systemErrorThreadReadResult))
      "planner app-server thread is in systemError"
      ["thread: planner-thread", "status: systemError"]
  , MappingCase
      "missing-active-turn"
      (\request -> pure (jsonRpcResult request (threadReadResult [turnObject (TurnId "other-turn") "running" Nothing])))
      "active planner turn is missing from app-server thread"
      ["turn: planner-turn", "thread: planner-thread"]
  , MappingCase
      "failed-turn"
      (\request -> pure (jsonRpcResult request (threadReadResult [turnObject activeTurnId "failed" (Just "blocked by tests")])))
      "active planner turn failed"
      ["turn: planner-turn", "reason: blocked by tests"]
  , MappingCase
      "completed-without-output"
      (\request -> pure (jsonRpcResult request (threadReadResult [turnObject activeTurnId "completed" Nothing])))
      "active planner turn completed without output"
      ["turn: planner-turn"]
  , MappingCase
      "blank-output"
      (\request -> pure (jsonRpcResult request (threadReadResult [turnObject activeTurnId "completed" (Just "   \n")])) )
      "active planner turn completed with blank output"
      ["turn: planner-turn"]
  , MappingCase
      "completed-unobserved"
      (\request -> pure (jsonRpcResult request (threadReadResult [turnObject activeTurnId "completed" (Just "done")])) )
      "completed planner turn has not been observed by watcher"
      ["turn: planner-turn", "status: completed", "stale threshold seconds:"]
  ]

threadReadResult :: [Value] -> Value
threadReadResult turns =
  object
    [ "thread" .= object ["id" .= unThreadId activeThreadId, "status" .= object ["type" .= ("running" :: Text)]]
    , "turns" .= turns
    ]

systemErrorThreadReadResult :: Value
systemErrorThreadReadResult =
  object
    [ "thread" .= object ["id" .= unThreadId activeThreadId, "status" .= object ["type" .= ("systemError" :: Text)]]
    , "turns" .= [turnObject activeTurnId "running" Nothing]
    ]

turnObject :: TurnId -> Text -> Maybe Text -> Value
turnObject turnId status output =
  object
    [ "id" .= unTurnId turnId
    , "status" .= status
    , "output" .= output
    ]

threadReadRequests :: [Value] -> [Value]
threadReadRequests =
  filter \request -> requestMethod request == Just "thread/read"

threadReadMatches :: Bool -> Value -> Bool
threadReadMatches includeTurns request =
  requestId request == Just (Number 1)
    && requestMethod request == Just "thread/read"
    && (lookupValue "threadId" =<< requestParams request) == Just (String "planner-thread")
    && (lookupValue "includeTurns" =<< requestParams request) == Just (Bool includeTurns)

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

requestIncludeTurns :: Value -> Maybe Bool
requestIncludeTurns request =
  case lookupValue "includeTurns" =<< requestParams request of
    Just (Bool includeTurns) -> Just includeTurns
    _ -> Nothing

problemMatches :: Text -> [Text] -> Maybe RunnerGuardProblem -> Bool
problemMatches summary details problem =
  problemSummaryIs summary problem && problemDetailsContainAll details problem

problemSummaryIs :: Text -> Maybe RunnerGuardProblem -> Bool
problemSummaryIs summary = \case
  Just problem -> problem.runnerGuardProblemSummary == summary
  Nothing -> False

problemDetailsContainAll :: [Text] -> Maybe RunnerGuardProblem -> Bool
problemDetailsContainAll details problem =
  all (`problemDetailsContain` problem) details

problemDetailsContain :: Text -> Maybe RunnerGuardProblem -> Bool
problemDetailsContain needle = \case
  Just problem -> any (needle `Text.isInfixOf`) problem.runnerGuardProblemDetails
  Nothing -> False

activeThreadId :: ThreadId
activeThreadId = ThreadId "planner-thread"

activeTurnId :: TurnId
activeTurnId = TurnId "planner-turn"
