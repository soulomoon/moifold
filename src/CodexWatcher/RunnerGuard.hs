{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RunnerGuard
  ( RunnerGuardConfig (..)
  , RunnerGuardAction (..)
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
  , parseTurnStartTurnId
  , sendOneAppServerRequest
  , startThreadWithEndpoint
  )
import CodexWatcher.AppServerProtocol
  ( threadNameSetRequest
  , threadReadRequest
  , turnStartRequest
  )
import CodexWatcher.EventLog (EventReplayResult (..), ReplayFailure (..), WatcherEvent (..), eventName, loadEventLogFile, replayEventLog)
import CodexWatcher.ChildDaemon (isPidRunning, readPidFile)
import CodexWatcher.JsonPath (renderedTextAtPath)
import CodexWatcher.RuntimeDefaults (defaultThreadStartOptions, defaultTurnStartOptions)
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
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (NominalDiffTime, diffUTCTime, getCurrentTime)
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getModificationTime)

data RunnerGuardConfig = RunnerGuardConfig
  { guardRepo :: RepoName
  , guardDomain :: Domain
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

data RunnerGuardAction
  = RestartWatcher
  | LaunchRepairThread
  deriving stock (Eq, Show, Generic)

instance ToJSON RunnerGuardAction where
  toJSON = \case
    RestartWatcher -> String "restart_watcher"
    LaunchRepairThread -> String "launch_repair_thread"

instance FromJSON RunnerGuardAction where
  parseJSON = \case
    String "restart_watcher" -> pure RestartWatcher
    String "launch_repair_thread" -> pure LaunchRepairThread
    _ -> fail "unsupported runner guard action"

data RunnerGuardProblem = RunnerGuardProblem
  { runnerGuardProblemAction :: RunnerGuardAction
  , runnerGuardProblemSummary :: Text
  , runnerGuardProblemDetails :: [Text]
  }
  deriving stock (Eq, Show, Generic)

instance ToJSON RunnerGuardProblem where
  toJSON problem' =
    object
      [ "action" .= problem'.runnerGuardProblemAction
      , "summary" .= problem'.runnerGuardProblemSummary
      , "details" .= problem'.runnerGuardProblemDetails
      ]

instance FromJSON RunnerGuardProblem where
  parseJSON = withObject "RunnerGuardProblem" \objectValue ->
    RunnerGuardProblem
      <$> objectValue .:? "action" .!= LaunchRepairThread
      <*> objectValue .: "summary"
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
  complete <- watcherEventLogTerminal config.guardDomain config.guardEventsPath
  if complete
    then pure Nothing
    else do
      pidProblem <- checkWatcherPid config.guardWatcherPidFile
      eventProblem <- checkEventLogAndActiveTurn config
      pure (combineProblems (catMaybes [pidProblem, eventProblem]))

startRunnerGuardRepairThread :: RunnerGuardConfig -> RunnerGuardProblem -> IO RunnerGuardRepair
startRunnerGuardRepairThread config problem' = do
  threadId <-
    either (failText . formatAppServerClientFailure) pure
      =<< startThreadWithEndpoint
        config.guardAppServerEndpoint
        defaultAppServerClientOptions
        1
        (defaultThreadStartOptions config.guardRepairCwd repairDeveloperInstructions)
  _ <-
    sendOrFail
      (threadNameSetRequest 2 threadId ("runner-guard repair " <> unRepoName config.guardRepo))
  turnResponse <-
    sendOrFail
      ( turnStartRequest
          3
          (defaultTurnStartOptions threadId config.guardRepairCwd (runnerGuardRepairPrompt config problem'))
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
    [ "Runner guard detected a problem in the " <> guardDomainText config <> " watcher."
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
    , "5. Restart the watcher with this exact command:"
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
  maybePid <- readPidFile pidPath
  case maybePid of
    Nothing ->
      pure (Just (restartProblem "watcher pid file is missing or empty" ["pid file: " <> Text.pack pidPath]))
    Just pidText -> do
      running <- isPidRunning pidText
      pure
        if running
          then Nothing
          else Just (restartProblem "watcher process is not running" ["pid file: " <> Text.pack pidPath, "pid: " <> pidText])

checkEventLogAndActiveTurn :: RunnerGuardConfig -> IO (Maybe RunnerGuardProblem)
checkEventLogAndActiveTurn config = do
  exists <- doesFileExist config.guardEventsPath
  if not exists
    then pure (Just (repairProblem "watcher event log is missing" ["events: " <> Text.pack config.guardEventsPath]))
    else do
      loaded <- loadEventLogFile config.guardEventsPath
      case loaded of
        Left error' ->
          pure (Just (repairProblem "watcher event log cannot be decoded" [Text.pack error']))
        Right events ->
          case replayEventLog events of
            Left failure ->
              pure (Just (eventReplayProblem failure))
            Right replay ->
              if someDomain replay.replayState /= config.guardDomain
                then
                  pure
                    ( Just
                        ( repairProblem
                            "watcher event log domain does not match guard domain"
                            [ "expected: " <> guardDomainText config
                            , "actual: " <> Text.pack (show (someDomain replay.replayState))
                            ]
                        )
                    )
                else checkReplayState config events replay.replayState

watcherEventLogTerminal :: Domain -> FilePath -> IO Bool
watcherEventLogTerminal expectedDomain eventsPath = do
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
              pure (someDomain replay.replayState == expectedDomain && somePhase replay.replayState == Complete)

checkReplayState :: RunnerGuardConfig -> [WatcherEvent] -> SomeWatcherState -> IO (Maybe RunnerGuardProblem)
checkReplayState config events = \case
  SomeWatcherState (BlockedState reason) ->
    pure (Just (repairProblem "watcher is blocked" ["reason: " <> unBlockedReason reason]))
  SomeWatcherState (StoppedState reason) ->
    pure (Just (repairProblem "watcher is stopped" ["reason: " <> unStopReason reason]))
  SomeWatcherState (PlanningReady {}) ->
    staleProblem config "planning watcher has not started a planner turn" ["last event: " <> lastEventName events]
  SomeWatcherState (PlanningTurnActive _ activeTurn) ->
    checkActiveTurn config "planner" activeTurn
  SomeWatcherState (PlanningWaitingForReadyIssues {}) ->
    pure Nothing
  SomeWatcherState (IssueReadyToPlan {}) ->
    staleProblem config "issue implementer has not started plan turn" ["last event: " <> lastEventName events]
  SomeWatcherState (IssueInPlanMode _ _ (WorkerActive activeTurn)) ->
    checkActiveTurn config "issue plan worker" activeTurn
  SomeWatcherState (IssuePlanReady {}) ->
    staleProblem config "issue implementer has not synced plan to PR body" ["last event: " <> lastEventName events]
  SomeWatcherState (IssueImplementationReady {}) ->
    staleProblem config "issue implementer has not started implementation or PR detection" ["last event: " <> lastEventName events]
  SomeWatcherState (IssueImplementing _ _ (WorkerActive activeTurn)) ->
    checkActiveTurn config "issue implementation worker" activeTurn
  SomeWatcherState (IssueHandoffReady {}) ->
    pure Nothing
  SomeWatcherState (IssueHandoffInitialized {}) ->
    pure Nothing
  SomeWatcherState (IssueWaitingForPrMerge {}) ->
    pure Nothing
  SomeWatcherState (IssueWaitingForIssueClose {}) ->
    pure Nothing
  SomeWatcherState (PrCheckingReviews {}) ->
    staleProblem config "PR review watcher has not checked review threads" ["last event: " <> lastEventName events]
  SomeWatcherState (PrFixingReviews _ _ (WorkerActive activeTurn) _) ->
    checkActiveTurn config "PR review worker" activeTurn
  SomeWatcherState (PrReviewingClean _ _ _ (ReviewerActive activeTurn)) ->
    checkActiveTurn config "PR reviewer" activeTurn
  SomeWatcherState (PrWaitingForMergeability {}) ->
    pure Nothing
  SomeWatcherState (PrMerging {}) ->
    pure Nothing
  SomeWatcherState (CompleteState {}) ->
    pure Nothing

checkActiveTurn :: RunnerGuardConfig -> Text -> ActiveTurn -> IO (Maybe RunnerGuardProblem)
checkActiveTurn config role activeTurn = do
  response <- sendOneAppServerRequest config.guardAppServerEndpoint defaultAppServerClientOptions (threadReadRequest 1 activeTurn.activeThreadId True)
  case response of
    Left failure ->
      pure (Just (repairProblem ("guard cannot read " <> role <> " app-server thread") ["thread: " <> unThreadId activeTurn.activeThreadId, formatAppServerClientFailure failure]))
    Right value ->
      case threadSystemError value of
        Just status ->
          pure (Just (repairProblem (role <> " app-server thread is in systemError") ["thread: " <> unThreadId activeTurn.activeThreadId, "status: " <> status]))
        Nothing ->
          case parseThreadReadTurns value of
            Left failure ->
              pure (Just (repairProblem ("guard cannot parse " <> role <> " app-server turns") [formatAppServerClientFailure failure]))
            Right turns ->
              case latestTurnById activeTurn.activeTurnId turns of
                Nothing ->
                  pure (Just (repairProblem ("active " <> role <> " turn is missing from app-server thread") ["turn: " <> unTurnId activeTurn.activeTurnId, "thread: " <> unThreadId activeTurn.activeThreadId]))
                Just turn ->
                  checkTurn config role turn

checkTurn :: RunnerGuardConfig -> Text -> AppServerTurn -> IO (Maybe RunnerGuardProblem)
checkTurn config role turn =
  case classifyTurnCompletion turn of
    TurnStillRunning ->
      staleProblem config ("active " <> role <> " turn is stale") ["turn: " <> unTurnId turn.appServerTurnId, "status: " <> turn.appServerTurnStatus]
    TurnFailed reason ->
      pure (Just (repairProblem ("active " <> role <> " turn failed") ["turn: " <> unTurnId turn.appServerTurnId, "reason: " <> reason]))
    TurnCompleted Nothing ->
      pure (Just (repairProblem ("active " <> role <> " turn completed without output") ["turn: " <> unTurnId turn.appServerTurnId]))
    TurnCompleted (Just output)
      | Text.null (Text.strip output) ->
          pure (Just (repairProblem ("active " <> role <> " turn completed with blank output") ["turn: " <> unTurnId turn.appServerTurnId]))
      | otherwise ->
          staleProblem config ("completed " <> role <> " turn has not been observed by watcher") ["turn: " <> unTurnId turn.appServerTurnId, "status: " <> turn.appServerTurnStatus]

staleProblem :: RunnerGuardConfig -> Text -> [Text] -> IO (Maybe RunnerGuardProblem)
staleProblem config summary' details = do
  ageSeconds <- eventLogAgeSeconds config.guardEventsPath
  pure
    if ageSeconds > fromIntegral config.guardStaleSeconds
      then Just (repairProblem summary' (details <> ["event log idle seconds: " <> Text.pack (show (floor ageSeconds :: Integer)), "stale threshold seconds: " <> Text.pack (show config.guardStaleSeconds)]))
      else Nothing

eventLogAgeSeconds :: FilePath -> IO NominalDiffTime
eventLogAgeSeconds path = do
  modified <- getModificationTime path
  now <- getCurrentTime
  pure (diffUTCTime now modified)

threadSystemError :: Value -> Maybe Text
threadSystemError value =
  let status = renderedTextAtPath ["thread", "status", "type"] value <|> renderedTextAtPath ["status", "type"] value <|> renderedTextAtPath ["thread", "status"] value <|> renderedTextAtPath ["status"] value
   in case Text.toLower . Text.strip <$> status of
        Just "systemerror" -> status
        Just "system_error" -> status
        _ -> Nothing

eventReplayProblem :: ReplayFailure -> RunnerGuardProblem
eventReplayProblem failure =
  repairProblem
    "watcher event log replay failed"
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
      { runnerGuardProblemAction =
          if any ((== LaunchRepairThread) . runnerGuardProblemAction) problems
            then LaunchRepairThread
            else RestartWatcher
      , runnerGuardProblemSummary = "multiple runner guard problems"
      , runnerGuardProblemDetails =
          concatMap
            (\problem' -> problem'.runnerGuardProblemSummary : problem'.runnerGuardProblemDetails)
            problems
      }

restartProblem :: Text -> [Text] -> RunnerGuardProblem
restartProblem summary' details =
  RunnerGuardProblem
    { runnerGuardProblemAction = RestartWatcher
    , runnerGuardProblemSummary = summary'
    , runnerGuardProblemDetails = details
    }

repairProblem :: Text -> [Text] -> RunnerGuardProblem
repairProblem summary' details =
  RunnerGuardProblem
    { runnerGuardProblemAction = LaunchRepairThread
    , runnerGuardProblemSummary = summary'
    , runnerGuardProblemDetails = details
    }

lastEventName :: [WatcherEvent] -> Text
lastEventName [] = "none"
lastEventName events = eventName (last events)

bulletList :: [Text] -> Text
bulletList [] = "- none"
bulletList items = Text.unlines (fmap ("- " <>) items)

guardDomainText :: RunnerGuardConfig -> Text
guardDomainText config =
  Text.pack (show config.guardDomain)

failText :: Text -> IO a
failText = fail . Text.unpack
