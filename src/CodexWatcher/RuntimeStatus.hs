{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.RuntimeStatus
  ( RuntimeStatus (..)
  , activeRuntimeStatus
  , watcherRuntimeStatus
  ) where

import CodexWatcher.EventLog
import CodexWatcher.Types
import System.Directory (doesFileExist)

data RuntimeStatus
  = Missing
  | ActiveStopped
  | ActiveRunning
  | Terminal
  deriving stock (Eq, Show)

activeRuntimeStatus :: Bool -> RuntimeStatus
activeRuntimeStatus running =
  if running then ActiveRunning else ActiveStopped

watcherRuntimeStatus
  :: FilePath
  -> FilePath
  -> IO Bool
  -> IO RuntimeStatus
  -> (SomeWatcherState -> IO (Maybe RuntimeStatus))
  -> IO RuntimeStatus
watcherRuntimeStatus configPath eventsPath pidRunning missingStatus replayStatus = do
  configExists <- doesFileExist configPath
  eventsExists <- doesFileExist eventsPath
  if not configExists && not eventsExists
    then missingStatus
    else do
      running <- pidRunning
      if not eventsExists
        then pure (activeRuntimeStatus running)
        else do
          loaded <- loadEventLogFile eventsPath
          case loaded of
            Left _failure ->
              pure (activeRuntimeStatus running)
            Right events ->
              case replayEventLog events of
                Left _failure ->
                  pure (activeRuntimeStatus running)
                Right replay -> do
                  status <- replayStatus replay.replayState
                  maybe (pure (activeRuntimeStatus running)) pure status
