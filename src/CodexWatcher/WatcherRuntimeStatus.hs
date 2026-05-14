{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.WatcherRuntimeStatus
  ( WatcherTerminalReason (..)
  , WatcherRuntimeStatus (..)
  , WatcherRuntimeStatusConfig (..)
  , statusIsActiveRunning
  , statusIsActiveStopped
  , statusIsMissing
  , statusIsTerminal
  , watcherRuntimeStatus
  ) where

import CodexWatcher.Core.Kinds (Domain, KnownDomain, domainSing)
import CodexWatcher.Core.Reason (BlockedReason (..), StopReason (..))
import CodexWatcher.Core.State (SomeWatcherState (..), WatcherState (..), isTerminalState)
import CodexWatcher.EventLog.Types (EventReplayResult (..))
import CodexWatcher.Healthcheck.Types (PidReport (..))
import CodexWatcher.Runtime.Inspection (RuntimeEventReplay (..), checkRuntimeEventReplay, readRuntimePid)
import Data.Text (Text)
import GHC.Generics (Generic)
import System.Directory (doesFileExist)

data WatcherTerminalReason
  = TerminalComplete
  | TerminalBlocked Text
  | TerminalStopped Text
  deriving stock (Eq, Show, Generic)

data WatcherRuntimeStatus
  = WatcherMissing
  | WatcherActiveStopped
  | WatcherActiveRunning
  | WatcherTerminal WatcherTerminalReason
  deriving stock (Eq, Show, Generic)

data WatcherRuntimeStatusConfig (domain :: Domain) = WatcherRuntimeStatusConfig
  { watcherRuntimeConfigPath :: FilePath
  , watcherRuntimeEventsPath :: FilePath
  , watcherRuntimePidPath :: FilePath
  , watcherRuntimeMissingIsTerminal :: IO Bool
  , watcherRuntimeReplayTerminalIsTerminal :: EventReplayResult -> IO Bool
  }

watcherRuntimeStatus :: forall domain. KnownDomain domain => WatcherRuntimeStatusConfig domain -> IO WatcherRuntimeStatus
watcherRuntimeStatus config = do
  configExists <- doesFileExist config.watcherRuntimeConfigPath
  eventsExists <- doesFileExist config.watcherRuntimeEventsPath
  if not configExists && not eventsExists
    then do
      terminal <- config.watcherRuntimeMissingIsTerminal
      pure (if terminal then WatcherTerminal TerminalComplete else WatcherMissing)
    else do
      running <- pidRunning config.watcherRuntimePidPath
      if not eventsExists
        then pure (runningStatus running)
        else do
          eventReplay <- checkRuntimeEventReplay (domainSing @domain) (Just config.watcherRuntimeEventsPath)
          case eventReplay.runtimeEventReplayResult of
            Just replay
              | isTerminalState replay.replayState -> do
                  terminal <- config.watcherRuntimeReplayTerminalIsTerminal replay
                  pure (if terminal then WatcherTerminal (terminalReason replay.replayState) else runningStatus running)
            _ -> pure (runningStatus running)

pidRunning :: FilePath -> IO Bool
pidRunning pidPath = do
  PidReport {running} <- readRuntimePid pidPath
  pure running

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
statusIsTerminal WatcherTerminal {} = True
statusIsTerminal _ = False

terminalReason :: SomeWatcherState -> WatcherTerminalReason
terminalReason (SomeWatcherState CompleteState {}) = TerminalComplete
terminalReason (SomeWatcherState (BlockedState reason)) = TerminalBlocked reason.unBlockedReason
terminalReason (SomeWatcherState (StoppedState reason)) = TerminalStopped reason.unStopReason
terminalReason _ = TerminalStopped "terminal state"
