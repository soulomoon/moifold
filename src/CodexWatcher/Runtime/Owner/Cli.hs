{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Owner.Cli
  ( clearRuntimeLease
  , clearRuntimeLeaseIfOwnedByCurrentProcess
  , renewRuntimeOwnerForExecution
  , validateRuntimeOwnerForExecution
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.ChildDaemon (isPidRunning)
import CodexWatcher.Runtime.Interpreter (ioRuntimeInterpreter)
import CodexWatcher.Runtime.Owner.Store (readRuntimeOwnerMarker, writeRuntimeLease)
import CodexWatcher.Runtime.Owner.Types (RuntimeLease (..), RuntimeOwner (..), RuntimeOwnerMarker (..))
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text
import Data.Time.Clock (NominalDiffTime, addUTCTime, getCurrentTime)
import System.Directory (doesFileExist, removeFile)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>))
import System.Posix.Process (getProcessID)

clearRuntimeLease :: FilePath -> IO ()
clearRuntimeLease stateDir = do
  marker <- readMarkerOrDie stateDir
  ensureClearable marker
  removeRuntimeOwnerFile stateDir
  putStrLn ("cleared inactive runtime lease in " <> stateDir)

clearRuntimeLeaseIfOwnedByCurrentProcess :: FilePath -> ActionExecutionMode -> IO ()
clearRuntimeLeaseIfOwnedByCurrentProcess stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      marker <- readMarkerOrDie stateDir
      currentPid <- Text.pack . show <$> getProcessID
      case marker of
        Just (RuntimeOwnerLeased lease)
          | lease.runtimeLeaseOwner == HaskellRuntime
          , lease.runtimeLeasePid == currentPid ->
              removeRuntimeOwnerFile stateDir
        _ ->
          pure ()

validateRuntimeOwnerForExecution :: FilePath -> ActionExecutionMode -> IO ()
validateRuntimeOwnerForExecution stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      readMarkerOrDie stateDir >>= \case
        Just (RuntimeOwnerLeased lease) -> do
          blocked <- leaseBlocksCurrentProcess lease
          if blocked
            then die ("refusing to execute because runtime owner lease is valid or held by running pid " <> Text.unpack lease.runtimeLeasePid)
            else writeFreshLease stateDir HaskellRuntime
        Nothing ->
          writeFreshLease stateDir HaskellRuntime

renewRuntimeOwnerForExecution :: FilePath -> ActionExecutionMode -> IO ()
renewRuntimeOwnerForExecution stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> writeFreshLease stateDir HaskellRuntime

readMarkerOrDie :: FilePath -> IO (Maybe RuntimeOwnerMarker)
readMarkerOrDie stateDir = do
  marker <- readRuntimeOwnerMarker stateDir
  case marker of
    Left errorMessage ->
      die ("runtime owner marker is invalid: " <> Text.unpack errorMessage)
    Right parsed ->
      pure parsed

ensureClearable :: Maybe RuntimeOwnerMarker -> IO ()
ensureClearable = \case
  Just (RuntimeOwnerLeased lease) -> do
    blocked <- leaseBlocksTakeover lease
    if blocked
      then die ("refusing to clear runtime lease because its pid is running: " <> Text.unpack lease.runtimeLeasePid)
      else pure ()
  Nothing -> pure ()

removeRuntimeOwnerFile :: FilePath -> IO ()
removeRuntimeOwnerFile stateDir = do
  let path = stateDir </> "runtime-owner.json"
  exists <- doesFileExist path
  if exists then removeFile path else pure ()

writeFreshLease :: FilePath -> RuntimeOwner -> IO ()
writeFreshLease stateDir owner = do
  lease <- currentRuntimeLease stateDir owner
  writeRuntimeLease ioRuntimeInterpreter stateDir lease

currentRuntimeLease :: FilePath -> RuntimeOwner -> IO RuntimeLease
currentRuntimeLease stateDir owner = do
  pidText <- Text.pack . show <$> getProcessID
  host <- Text.pack . maybe "unknown-host" id <$> lookupEnv "HOSTNAME"
  now <- getCurrentTime
  fingerprint <- eventLogHeadHash stateDir
  pure
    RuntimeLease
      { runtimeLeaseOwner = owner
      , runtimeLeasePid = pidText
      , runtimeLeaseHost = host
      , runtimeLeaseClaimedAt = now
      , runtimeLeaseExpiresAt = addUTCTime leaseSeconds now
      , runtimeLeaseEventLogHeadHash = fingerprint
      }

leaseSeconds :: NominalDiffTime
leaseSeconds = 3600

leaseBlocksCurrentProcess :: RuntimeLease -> IO Bool
leaseBlocksCurrentProcess lease = do
  currentPid <- Text.pack . show <$> getProcessID
  if lease.runtimeLeasePid == currentPid
    then pure False
    else leaseBlocksTakeover lease

leaseBlocksTakeover :: RuntimeLease -> IO Bool
leaseBlocksTakeover lease =
  isPidRunning lease.runtimeLeasePid

eventLogHeadHash :: FilePath -> IO Text.Text
eventLogHeadHash stateDir = do
  let eventsPath = stateDir </> "events.jsonl"
  exists <- doesFileExist eventsPath
  if not exists
    then pure "missing"
    else do
      bytes <- ByteString.readFile eventsPath
      pure (Text.pack (show (ByteString.length bytes) <> ":" <> show (ByteString.foldl' hashStep (5381 :: Int) bytes)))
 where
  hashStep acc byte =
    (acc * 33 + fromIntegral byte) `mod` 2147483647
