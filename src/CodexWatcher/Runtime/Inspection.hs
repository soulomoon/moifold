{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Inspection
  ( RuntimeEventReplay (..)
  , RuntimeInspection (..)
  , RuntimeInspectionConfig (..)
  , checkRuntimeEventReplay
  , inspectRuntime
  , projectStateFiles
  , readRuntimePid
  , stateFileSpecs
  ) where

import CodexWatcher.ChildDaemon (isPidRunning, readPidFile)
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types (EventReplayResult (..), ReplayFailure)
import CodexWatcher.EventLog.Types qualified as EventLogTypes
import CodexWatcher.Healthcheck.Types
  ( EventReplayReport (..)
  , PidReport (..)
  , SDomain (..)
  , watcherDomainMatches
  , watcherDomainValue
  )
import CodexWatcher.Runtime.Compatibility (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.Runtime.File (readJsonValue)
import CodexWatcher.Core.State (SomeWatcherState, someDomain, somePhase)
import Data.Aeson (Value (..), object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Directory (doesFileExist)
import System.FilePath (takeFileName, (</>))

data RuntimeInspectionConfig domain = RuntimeInspectionConfig
  { runtimeInspectionDomain :: SDomain domain
  , runtimeInspectionStateDir :: FilePath
  , runtimeInspectionPidPath :: FilePath
  , runtimeInspectionEventsPath :: Maybe FilePath
  }
  deriving stock (Generic)

data RuntimeEventReplay = RuntimeEventReplay
  { runtimeEventReplayReport :: EventReplayReport
  , runtimeEventReplayResult :: Maybe EventReplayResult
  , runtimeEventReplayState :: Maybe SomeWatcherState
  }
  deriving stock (Generic)

data RuntimeInspection = RuntimeInspection
  { runtimeInspectionPid :: PidReport
  , runtimeInspectionEventReplay :: RuntimeEventReplay
  , runtimeInspectionProjectedStates :: Value
  }
  deriving stock (Generic)

inspectRuntime :: RuntimeInspectionConfig domain -> IO RuntimeInspection
inspectRuntime config = do
  pid <- readRuntimePid config.runtimeInspectionPidPath
  eventReplay <- checkRuntimeEventReplay config.runtimeInspectionDomain config.runtimeInspectionEventsPath
  projectedStates <-
    projectStateFiles
      config.runtimeInspectionDomain
      config.runtimeInspectionStateDir
      eventReplay.runtimeEventReplayState
  pure
    RuntimeInspection
      { runtimeInspectionPid = pid
      , runtimeInspectionEventReplay = eventReplay
      , runtimeInspectionProjectedStates = projectedStates
      }

readRuntimePid :: FilePath -> IO PidReport
readRuntimePid pidPath = do
  pid <- readPidFile pidPath
  running <- maybe (pure False) isPidRunning pid
  pure PidReport {pidPath, pid, running}

checkRuntimeEventReplay :: SDomain domain -> Maybe FilePath -> IO RuntimeEventReplay
checkRuntimeEventReplay kind (Just path) = do
  exists <- doesFileExist path
  if not exists
    then pure (runtimeEventReplayWithoutState (skippedEventReplay "events log does not exist" (Just path)))
    else do
      loaded <- loadEventLogFile path
      pure case loaded of
        Left error' ->
          runtimeEventReplayWithoutState (failedEventReplay path (Text.pack error'))
        Right events ->
          case replayEventLog events of
            Left failure ->
              runtimeEventReplayWithoutState (failedEventReplay path (Text.pack (formatReplayFailureForHealthcheck failure)))
            Right replay
              | not (watcherDomainMatches kind replay.replayState) ->
                  runtimeEventReplayWithoutState
                    ( failedEventReplay
                        path
                        ( "events replayed as "
                            <> Text.pack (show (someDomain replay.replayState))
                            <> " but config is "
                            <> Text.pack (show (watcherDomainValue kind))
                        )
                    )
              | otherwise ->
                  RuntimeEventReplay
                    { runtimeEventReplayReport =
                        EventReplayReport
                          { skipped = False
                          , ok = True
                          , reason = Nothing
                          , eventsPath = Just path
                          , domain = Just (Text.pack (show (someDomain replay.replayState)))
                          , phase = Just (Text.pack (show (somePhase replay.replayState)))
                          , eventCount = Just (length events)
                          , effectBatchCount = Just (length replay.replayEffects)
                          }
                    , runtimeEventReplayResult = Just replay
                    , runtimeEventReplayState = Just replay.replayState
                    }
checkRuntimeEventReplay _kind Nothing =
  pure (runtimeEventReplayWithoutState (skippedEventReplay "missing eventsPath" Nothing))

projectStateFiles :: SDomain kind -> FilePath -> Maybe SomeWatcherState -> IO Value
projectStateFiles kind stateDir replayState =
  object <$> traverse projectStateFile (stateFileSpecs kind)
 where
  writes = maybe [] (compatibilityStateWrites stateDir) replayState

  projectStateFile (key, fileName) = do
    value <-
      if fileName == "runtime-owner.json"
        then readOptionalValueFile (stateDir </> fileName)
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

runtimeEventReplayWithoutState :: EventReplayReport -> RuntimeEventReplay
runtimeEventReplayWithoutState report =
  RuntimeEventReplay
    { runtimeEventReplayReport = report
    , runtimeEventReplayResult = Nothing
    , runtimeEventReplayState = Nothing
    }

skippedEventReplay :: Text -> Maybe FilePath -> EventReplayReport
skippedEventReplay reason' path =
  EventReplayReport
    { skipped = True
    , ok = False
    , reason = Just reason'
    , eventsPath = path
    , domain = Nothing
    , phase = Nothing
    , eventCount = Nothing
    , effectBatchCount = Nothing
    }

failedEventReplay :: FilePath -> Text -> EventReplayReport
failedEventReplay path reason' =
  EventReplayReport
    { skipped = False
    , ok = False
    , reason = Just reason'
    , eventsPath = Just path
    , domain = Nothing
    , phase = Nothing
    , eventCount = Nothing
    , effectBatchCount = Nothing
    }

formatReplayFailureForHealthcheck :: ReplayFailure -> String
formatReplayFailureForHealthcheck failure =
  "event replay failed at event "
    <> show (EventLogTypes.eventIndex failure)
    <> " ("
    <> show (EventLogTypes.event failure)
    <> "): "
    <> Text.unpack (EventLogTypes.reason failure)
