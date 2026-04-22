{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RunnerGuard
  ( RunnerGuardConfig (..)
  , RunnerGuardProblem (..)
  , RunnerGuardRepair (..)
  , checkRunnerGuard
  , runnerGuardRepairPrompt
  , startRunnerGuardRepairThread
  ) where

import CodexWatcher.AppServerClient
  ( AppServerEndpoint
  , AppServerTurn (..)
  , defaultAppServerClientOptions
  , formatAppServerClientFailure
  , latestTurnById
  , parseThreadReadTurns
  , parseThreadStartThreadId
  , parseTurnStartTurnId
  , sendOneAppServerRequest
  )
import CodexWatcher.AppServerProtocol
  ( ThreadStartOptions (..)
  , TurnStartOptions (..)
  , threadNameSetRequest
  , threadReadRequest
  , threadStartRequest
  , turnStartRequest
  )
import CodexWatcher.EventLog (EventReplayResult (..), ReplayFailure (..), WatcherEvent (..), eventName, loadEventLogFile, replayEventLog)
import CodexWatcher.Runtime (CommandReport (..), RuntimeCommand (KillZero), commandText, runRuntimeCommand)
import CodexWatcher.TurnClassifier (TurnCompletion (..), classifyTurnCompletion)
import CodexWatcher.Types
import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , Value (..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (NominalDiffTime, diffUTCTime, getCurrentTime)
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getModificationTime)

data RunnerGuardConfig = RunnerGuardConfig
  { guardRepo :: RepoName
  , guardEventsPath :: FilePath
  , guardStateDir :: FilePath
  , guardWatcherPidFile :: FilePath
  , guardAppServerEndpoint :: AppServerEndpoint
  , guardStaleSeconds :: Int
  , guardRepairCwd :: FilePath
  , guardRestartWatcherCommand :: Text
  , guardRestartGuardCommand :: Text
  }
  deriving stock (Eq, Show, Generic)

data RunnerGuardProblem = RunnerGuardProblem
  { runnerGuardProblemSummary :: Text
  , runnerGuardProblemDetails :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON RunnerGuardProblem where
  toJSON problem' =
    object
      [ "summary" .= problem'.runnerGuardProblemSummary
      , "details" .= problem'.runnerGuardProblemDetails
      ]

instance FromJSON RunnerGuardProblem where
  parseJSON = withObject "RunnerGuardProblem" \objectValue ->
    RunnerGuardProblem
      <$> objectValue .: "summary"
      <*> objectValue .:? "details" .!= []

data RunnerGuardRepair = RunnerGuardRepair
  { runnerGuardRepairThreadId :: ThreadId
  , runnerGuardRepairTurnId :: TurnId
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON RunnerGuardRepair where
  toJSON repair =
    object
      [ "threadId" .= unThreadId repair.runnerGuardRepairThreadId
      , "turnId" .= unTurnId repair.runnerGuardRepairTurnId
      ]

checkRunnerGuard :: RunnerGuardConfig -> IO (Maybe RunnerGuardProblem)
checkRunnerGuard config = do
  complete <- issuePlanningEventLogComplete config.guardEventsPath
  if complete
    then pure Nothing
    else do
      pidProblem <- checkWatcherPid config.guardWatcherPidFile
      eventProblem <- checkEventLogAndActiveTurn config
      pure (combineProblems (catMaybes [pidProblem, eventProblem]))

startRunnerGuardRepairThread :: RunnerGuardConfig -> RunnerGuardProblem -> IO RunnerGuardRepair
startRunnerGuardRepairThread config problem' = do
  threadResponse <-
    sendOrFail
      ( threadStartRequest
          1
          ThreadStartOptions
            { threadCwd = config.guardRepairCwd
            , threadApprovalPolicy = "never"
            , threadSandbox = "danger-full-access"
            , threadModel = "gpt-5.4"
            , threadDeveloperInstructions = repairDeveloperInstructions
            }
      )
  threadId <- either (failText . formatAppServerClientFailure) pure (parseThreadStartThreadId threadResponse)
  _ <-
    sendOrFail
      (threadNameSetRequest 2 threadId ("runner-guard repair " <> unRepoName config.guardRepo))
  turnResponse <-
    sendOrFail
      ( turnStartRequest
          3
          TurnStartOptions
            { turnThreadId = threadId
            , turnCwd = config.guardRepairCwd
            , turnEffort = "xhigh"
            , turnModel = "gpt-5.4"
            , turnApprovalPolicy = "never"
            , turnSandboxPolicy = "danger-full-access"
            , turnInput = runnerGuardRepairPrompt config problem'
            , turnOutputSchema = Nothing
            , turnCollaborationMode = Nothing
            }
      )
  turnId <- either (failText . formatAppServerClientFailure) pure (parseTurnStartTurnId turnResponse)
  pure RunnerGuardRepair {runnerGuardRepairThreadId = threadId, runnerGuardRepairTurnId = turnId}
 where
  sendOrFail request = do
    result <- sendOneAppServerRequest config.guardAppServerEndpoint defaultAppServerClientOptions request
    either (failText . formatAppServerClientFailure) pure result

repairDeveloperInstructions :: Text
repairDeveloperInstructions =
  Text.unlines
    [ "You are the runner guard repair worker for the Haskell codex watcher runtime."
    , "Fix root causes directly. Do not ask the user to do local steps."
    , "Use gpt-5.4 xhigh level rigor: inspect code, patch, run tests, commit, push, then restart the watcher and guard."
    ]

runnerGuardRepairPrompt :: RunnerGuardConfig -> RunnerGuardProblem -> Text
runnerGuardRepairPrompt config problem' =
  Text.unlines
    [ "Runner guard detected a problem in the issue planning watcher."
    , ""
    , "Problem summary:"
    , problem'.runnerGuardProblemSummary
    , ""
    , "Problem details:"
    , bulletList problem'.runnerGuardProblemDetails
    , ""
    , "Repository to repair:"
    , Text.pack config.guardRepairCwd
    , ""
    , "Required workflow:"
    , "1. Inspect the Haskell watcher runtime and the current watcher state."
    , "2. Fix the code or operational state that caused the guard problem."
    , "3. Run: cabal test all && cabal build all && git diff --check"
    , "4. Commit and push any code changes."
    , "5. Restart the issue planning watcher with this exact command:"
    , config.guardRestartWatcherCommand
    , "6. Start the runner guard again with this exact command:"
    , config.guardRestartGuardCommand
    , ""
    , "Safety constraints:"
    , "- Do not delete watcher state; archive bad state directories if a clean restart is needed."
    , "- Avoid launching duplicate watcher/guard processes. Stop stale pids first when necessary."
    , "- If the issue is an app-server protocol mismatch, add a regression test before restarting."
    ]

checkWatcherPid :: FilePath -> IO (Maybe RunnerGuardProblem)
checkWatcherPid pidPath = do
  exists <- doesFileExist pidPath
  if not exists
    then pure (Just (problem "issue planning watcher pid file is missing" ["pid file: " <> Text.pack pidPath]))
    else do
      pidText <- Text.strip . Text.pack <$> readFile pidPath
      if Text.null pidText
        then pure (Just (problem "issue planning watcher pid file is empty" ["pid file: " <> Text.pack pidPath]))
        else do
          report <- runRuntimeCommand (KillZero pidText)
          pure
            if report.ok
              then Nothing
              else Just (problem "issue planning watcher process is not running" ["pid file: " <> Text.pack pidPath, "pid: " <> pidText, "kill -0 output: " <> commandText report])

checkEventLogAndActiveTurn :: RunnerGuardConfig -> IO (Maybe RunnerGuardProblem)
checkEventLogAndActiveTurn config = do
  exists <- doesFileExist config.guardEventsPath
  if not exists
    then pure (Just (problem "issue planning event log is missing" ["events: " <> Text.pack config.guardEventsPath]))
    else do
      loaded <- loadEventLogFile config.guardEventsPath
      case loaded of
        Left error' ->
          pure (Just (problem "issue planning event log cannot be decoded" [Text.pack error']))
        Right events ->
          case replayEventLog events of
            Left failure ->
              pure (Just (eventReplayProblem failure))
            Right replay ->
              checkReplayState config events replay.replayState

issuePlanningEventLogComplete :: FilePath -> IO Bool
issuePlanningEventLogComplete eventsPath = do
  exists <- doesFileExist eventsPath
  if not exists
    then pure False
    else do
      loaded <- loadEventLogFile eventsPath
      case loaded of
        Left _ -> pure False
        Right events ->
          case replayEventLog events of
            Left _ -> pure False
            Right replay ->
              pure (someDomain replay.replayState == IssuePlanning && somePhase replay.replayState == Complete)

checkReplayState :: RunnerGuardConfig -> [WatcherEvent] -> SomeWatcherState -> IO (Maybe RunnerGuardProblem)
checkReplayState config events = \case
  SomeWatcherState (BlockedState reason) ->
    pure (Just (problem "issue planning watcher is blocked" ["reason: " <> unBlockedReason reason]))
  SomeWatcherState (StoppedState reason) ->
    pure (Just (problem "issue planning watcher is stopped" ["reason: " <> unStopReason reason]))
  SomeWatcherState (PlanningReady {}) ->
    staleProblem config "issue planning watcher has not started a planner turn" ["last event: " <> lastEventName events]
  SomeWatcherState (PlanningTurnActive _ activeTurn) ->
    checkActivePlannerTurn config activeTurn
  SomeWatcherState (CompleteState {}) ->
    pure Nothing
  state ->
    pure (Just (problem "issue planning guard saw an unexpected watcher domain/state" ["state: " <> Text.pack (show state)]))

checkActivePlannerTurn :: RunnerGuardConfig -> ActiveTurn -> IO (Maybe RunnerGuardProblem)
checkActivePlannerTurn config activeTurn = do
  response <- sendOneAppServerRequest config.guardAppServerEndpoint defaultAppServerClientOptions (threadReadRequest 1 activeTurn.activeThreadId True)
  case response of
    Left failure ->
      pure (Just (problem "guard cannot read planner app-server thread" ["thread: " <> unThreadId activeTurn.activeThreadId, formatAppServerClientFailure failure]))
    Right value ->
      case threadSystemError value of
        Just status ->
          pure (Just (problem "planner app-server thread is in systemError" ["thread: " <> unThreadId activeTurn.activeThreadId, "status: " <> status]))
        Nothing ->
          case parseThreadReadTurns value of
            Left failure ->
              pure (Just (problem "guard cannot parse planner app-server turns" [formatAppServerClientFailure failure]))
            Right turns ->
              case latestTurnById activeTurn.activeTurnId turns of
                Nothing ->
                  pure (Just (problem "active planner turn is missing from app-server thread" ["turn: " <> unTurnId activeTurn.activeTurnId, "thread: " <> unThreadId activeTurn.activeThreadId]))
                Just turn ->
                  checkTurn config turn

checkTurn :: RunnerGuardConfig -> AppServerTurn -> IO (Maybe RunnerGuardProblem)
checkTurn config turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      staleProblem config "active planner turn is stale" ["turn: " <> unTurnId turn.appServerTurnId, "status: " <> turn.appServerTurnStatus]
    TurnFailed reason ->
      pure (Just (problem "active planner turn failed" ["turn: " <> unTurnId turn.appServerTurnId, "reason: " <> reason]))
    TurnCompleted Nothing ->
      pure (Just (problem "active planner turn completed without output" ["turn: " <> unTurnId turn.appServerTurnId]))
    TurnCompleted (Just output)
      | Text.null (Text.strip output) ->
          pure (Just (problem "active planner turn completed with blank output" ["turn: " <> unTurnId turn.appServerTurnId]))
      | otherwise ->
          staleProblem config "completed planner turn has not been observed by watcher" ["turn: " <> unTurnId turn.appServerTurnId, "status: " <> turn.appServerTurnStatus]

staleProblem :: RunnerGuardConfig -> Text -> [Text] -> IO (Maybe RunnerGuardProblem)
staleProblem config summary' details = do
  ageSeconds <- eventLogAgeSeconds config.guardEventsPath
  pure
    if ageSeconds > fromIntegral config.guardStaleSeconds
      then Just (problem summary' (details <> ["event log idle seconds: " <> Text.pack (show (floor ageSeconds :: Integer)), "stale threshold seconds: " <> Text.pack (show config.guardStaleSeconds)]))
      else Nothing

eventLogAgeSeconds :: FilePath -> IO NominalDiffTime
eventLogAgeSeconds path = do
  modified <- getModificationTime path
  now <- getCurrentTime
  pure (diffUTCTime now modified)

threadSystemError :: Value -> Maybe Text
threadSystemError value =
  let status = textPath ["thread", "status", "type"] value <|> textPath ["status", "type"] value <|> textPath ["thread", "status"] value <|> textPath ["status"] value
   in case Text.toLower . Text.strip <$> status of
        Just "systemerror" -> status
        Just "system_error" -> status
        _ -> Nothing

textPath :: [Text] -> Value -> Maybe Text
textPath [] (String text) = Just text
textPath [] value = Just (Text.pack (show value))
textPath (key : rest) (Object objectValue) = KeyMap.lookup (Key.fromText key) objectValue >>= textPath rest
textPath _ _ = Nothing

eventReplayProblem :: ReplayFailure -> RunnerGuardProblem
eventReplayProblem failure =
  problem
    "issue planning event log replay failed"
    [ "event index: " <> Text.pack (show failure.eventIndex)
    , "event: " <> eventName failure.event
    , "reason: " <> failure.reason
    ]

combineProblems :: [RunnerGuardProblem] -> Maybe RunnerGuardProblem
combineProblems [] = Nothing
combineProblems [single] = Just single
combineProblems problems =
  Just
    RunnerGuardProblem
      { runnerGuardProblemSummary = "multiple issue planning guard problems"
      , runnerGuardProblemDetails =
          concatMap
            (\problem' -> problem'.runnerGuardProblemSummary : problem'.runnerGuardProblemDetails)
            problems
      }

problem :: Text -> [Text] -> RunnerGuardProblem
problem summary' details =
  RunnerGuardProblem
    { runnerGuardProblemSummary = summary'
    , runnerGuardProblemDetails = details
    }

lastEventName :: [WatcherEvent] -> Text
lastEventName [] = "none"
lastEventName events = eventName (last events)

bulletList :: [Text] -> Text
bulletList [] = "- none"
bulletList items = Text.unlines (fmap ("- " <>) items)

failText :: Text -> IO a
failText = fail . Text.unpack
