{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.ReplayCli
  ( replayEvents
  , repairInvalidState
  , formatReplayFailure
  ) where

import CodexWatcher.Cli.Types (RepairInvalidStateCli (..))
import CodexWatcher.CompatibilityState (CompatibilityWrite (..), compatibilityStateWrites)
import CodexWatcher.EventLog.File (loadEventLogFile)
import CodexWatcher.EventLog.Replay (replayEventLog)
import CodexWatcher.EventLog.Types
import CodexWatcher.EventLogRepair
import CodexWatcher.Runtime.File (writeJsonValue)
import CodexWatcher.Core.Types
import Control.Monad (when)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text qualified as Text
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import System.Directory (copyFile, createDirectoryIfMissing, doesFileExist, removeFile)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))

replayEvents :: FilePath -> IO ()
replayEvents path = do
  loaded <- loadEventLogFile path
  events <- either die pure loaded
  replay <- either (die . formatReplayFailure) pure (replayEventLog events)
  putStrLn ("domain: " <> show (someDomain replay.replayState))
  putStrLn ("phase: " <> show (somePhase replay.replayState))
  putStrLn ("events: " <> show (length events))
  putStrLn ("effect batches: " <> show (length replay.replayEffects))

repairInvalidState :: RepairInvalidStateCli -> IO ()
repairInvalidState options = do
  loaded <- loadEventLogFile options.repairCliEventsPath
  events <- either die pure loaded
  case replayEventLog events of
    Right replay -> do
      putStrLn "event log is valid; no repair needed"
      putStrLn ("domain: " <> show (someDomain replay.replayState))
      putStrLn ("phase: " <> show (somePhase replay.replayState))
    Left _initialFailure -> do
      plan <- either (die . Text.unpack) pure (repairIssueImplementEventLog events)
      putStrLn ("repair strategy: " <> Text.unpack plan.repairStrategy)
      putStrLn ("failed event index: " <> show plan.repairFailure.eventIndex)
      putStrLn ("inserted events: " <> show (length plan.repairInsertedEvents))
      putStrLn ("dropped events: " <> show (length plan.repairDroppedEvents))
      putStrLn ("repaired phase: " <> show (somePhase plan.repairReplayResult.replayState))
      if options.repairCliExecute
        then do
          archivePath <- archiveEventLog options.repairCliEventsPath
          writeWatcherEventsFile options.repairCliEventsPath plan.repairRepairedEvents
          writeRepairSummary options.repairCliStateDir archivePath plan
          writeCompatibilityFiles options.repairCliStateDir plan.repairReplayResult.replayState
          removeFileIfExists (options.repairCliStateDir </> "block-state.json")
          putStrLn ("archived invalid event log: " <> archivePath)
          putStrLn ("wrote repaired event log: " <> options.repairCliEventsPath)
        else
          putStrLn "dry-run: pass --execute to archive and rewrite events.jsonl"

archiveEventLog :: FilePath -> IO FilePath
archiveEventLog eventsPath = do
  timestamp <- formatTime defaultTimeLocale "%Y%m%dT%H%M%SZ" <$> getCurrentTime
  let archivePath = eventsPath <> ".invalid-" <> timestamp
  copyFile eventsPath archivePath
  pure archivePath

writeWatcherEventsFile :: FilePath -> [WatcherEvent] -> IO ()
writeWatcherEventsFile eventsPath events = do
  createDirectoryIfMissing True (takeDirectory eventsPath)
  LazyByteString.writeFile eventsPath (mconcat (fmap (\event -> encode event <> "\n") events))

writeRepairSummary :: FilePath -> FilePath -> EventLogRepairPlan -> IO ()
writeRepairSummary stateDir archivePath plan =
  writeJsonValue
    (stateDir </> "repair-state.json")
    ( object
        [ "repaired" .= True
        , "strategy" .= plan.repairStrategy
        , "archivePath" .= archivePath
        , "failedEventIndex" .= plan.repairFailure.eventIndex
        , "failedEventType" .= eventName plan.repairFailure.event
        , "failedReason" .= plan.repairFailure.reason
        , "insertedEvents" .= fmap eventName plan.repairInsertedEvents
        , "droppedEvents" .= fmap eventName plan.repairDroppedEvents
        , "finalDomain" .= show (someDomain plan.repairReplayResult.replayState)
        , "finalPhase" .= show (somePhase plan.repairReplayResult.replayState)
        ]
    )

writeCompatibilityFiles :: FilePath -> SomeWatcherState -> IO ()
writeCompatibilityFiles stateDir state =
  mapM_ writeOne (compatibilityStateWrites stateDir state)
 where
  writeOne compatibilityWrite = do
    createDirectoryIfMissing True (takeDirectory compatibilityWrite.compatibilityWritePath)
    writeJsonValue compatibilityWrite.compatibilityWritePath compatibilityWrite.compatibilityWriteValue

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = do
  exists <- doesFileExist path
  when exists (removeFile path)

formatReplayFailure :: ReplayFailure -> String
formatReplayFailure failure =
  "event replay failed at event "
    <> show failure.eventIndex
    <> " ("
    <> show failure.event
    <> "): "
    <> Text.unpack failure.reason
