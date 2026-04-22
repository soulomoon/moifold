{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.WatcherRuntimeStatus
  ( WatcherRuntimeStatus (..)
  , WatcherRuntimeStatusConfig (..)
  , statusIsActiveRunning
  , statusIsActiveStopped
  , statusIsMissing
  , statusIsTerminal
  , watcherRuntimeStatus
  ) where

import CodexWatcher.ChildDaemon (readPidFile, isPidRunning)
import CodexWatcher.EventLog (EventReplayResult (..), loadEventLogFile, replayEventLog)
import CodexWatcher.Types (Domain, isTerminalPhase, someDomain, somePhase)
import GHC.Generics (Generic)
import System.Directory (doesFileExist)

data WatcherRuntimeStatus
  = WatcherMissing
  | WatcherActiveStopped
  | WatcherActiveRunning
  | WatcherTerminal
  deriving stock (Eq, Show, Generic)

data WatcherRuntimeStatusConfig = WatcherRuntimeStatusConfig
  { watcherRuntimeExpectedDomain :: Domain
  , watcherRuntimeConfigPath :: FilePath
  , watcherRuntimeEventsPath :: FilePath
  , watcherRuntimePidPath :: FilePath
  , watcherRuntimeMissingIsTerminal :: IO Bool
  , watcherRuntimeReplayTerminalIsTerminal :: EventReplayResult -> IO Bool
  }

watcherRuntimeStatus :: WatcherRuntimeStatusConfig -> IO WatcherRuntimeStatus
watcherRuntimeStatus config = do
  configExists <- doesFileExist config.watcherRuntimeConfigPath
  eventsExists <- doesFileExist config.watcherRuntimeEventsPath
  if not configExists && not eventsExists
    then do
      terminal <- config.watcherRuntimeMissingIsTerminal
      pure (if terminal then WatcherTerminal else WatcherMissing)
    else do
      running <- pidRunning config.watcherRuntimePidPath
      if not eventsExists
        then pure (runningStatus running)
        else do
          loaded <- loadEventLogFile config.watcherRuntimeEventsPath
          case loaded of
            Left _failure ->
              pure (runningStatus running)
            Right events ->
              case replayEventLog events of
                Left _failure ->
                  pure (runningStatus running)
                Right replay
                  | someDomain replay.replayState == config.watcherRuntimeExpectedDomain
                  , isTerminalPhase (somePhase replay.replayState) -> do
                      terminal <- config.watcherRuntimeReplayTerminalIsTerminal replay
                      pure (if terminal then WatcherTerminal else WatcherActiveRunning)
                  | running ->
                      pure WatcherActiveRunning
                  | otherwise ->
                      pure WatcherActiveStopped

pidRunning :: FilePath -> IO Bool
pidRunning pidPath = do
  maybePid <- readPidFile pidPath
  case maybePid of
    Nothing -> pure False
    Just pidText -> isPidRunning pidText

runningStatus :: Bool -> WatcherRuntimeStatus
runningStatus running =
  if running then WatcherActiveRunning else WatcherActiveStopped

statusIsMissing :: WatcherRuntimeStatus -> Bool
statusIsMissing WatcherMissing = True
statusIsMissing _ = False

statusIsActiveStopped :: WatcherRuntimeStatus -> Bool
statusIsActiveStopped WatcherActiveStopped = True
statusIsActiveStopped _ = False

statusIsActiveRunning :: WatcherRuntimeStatus -> Bool
statusIsActiveRunning WatcherActiveRunning = True
statusIsActiveRunning _ = False

statusIsTerminal :: WatcherRuntimeStatus -> Bool
statusIsTerminal WatcherTerminal = True
statusIsTerminal _ = False
