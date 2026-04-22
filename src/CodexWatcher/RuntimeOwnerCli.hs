{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RuntimeOwnerCli
  ( claimRuntimeOwner
  , renewRuntimeOwnerForExecution
  , validateRuntimeOwnerForExecution
  ) where

import CodexWatcher.ActionExecutor (ActionExecutionMode (..))
import CodexWatcher.ChildDaemon (isPidRunning)
import CodexWatcher.RuntimeOwner (RuntimeLease (..), RuntimeOwner (..), RuntimeOwnerMarker (..), readRuntimeOwnerMarker, runtimeOwnerText, writeRuntimeLease)
import CodexWatcher.Runtime (ioRuntimeInterpreter)
import Data.ByteString qualified as ByteString
import Data.Text qualified as Text
import Data.Time.Clock (NominalDiffTime, addUTCTime, getCurrentTime)
import System.Directory (doesFileExist)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath ((</>))
import System.Posix.Process (getProcessID)

claimRuntimeOwner :: FilePath -> IO ()
claimRuntimeOwner stateDir = do
  marker <- readMarkerOrDie stateDir
  ensureClaimable marker
  writeFreshLease stateDir HaskellRuntime
  putStrLn ("wrote runtime owner " <> Text.unpack (runtimeOwnerText HaskellRuntime) <> " lease to " <> stateDir)

validateRuntimeOwnerForExecution :: FilePath -> ActionExecutionMode -> IO ()
validateRuntimeOwnerForExecution stateDir executionMode =
  case executionMode of
    DryRunActions -> pure ()
    ExecuteActions -> do
      readMarkerOrDie stateDir >>= \case
        Just (RuntimeOwnerLegacy HaskellRuntime) ->
          writeFreshLease stateDir HaskellRuntime
        Just (RuntimeOwnerLeased lease) -> do
          blocked <- leaseBlocksCurrentProcess lease
          if blocked
            then die ("refusing to execute because runtime owner lease is valid or held by running pid " <> Text.unpack lease.runtimeLeasePid)
            else writeFreshLease stateDir HaskellRuntime
        Nothing ->
          die "refusing to execute because runtime-owner.json is missing; claim this state directory before execute mode"

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

ensureClaimable :: Maybe RuntimeOwnerMarker -> IO ()
ensureClaimable = \case
  Just (RuntimeOwnerLeased lease) -> do
    blocked <- leaseBlocksTakeover lease
    if blocked
      then die ("refusing to claim runtime owner because an active lease is valid or its pid is running: " <> Text.unpack lease.runtimeLeasePid)
      else pure ()
  _ ->
    pure ()

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
leaseBlocksTakeover lease = do
  now <- getCurrentTime
  running <- isPidRunning lease.runtimeLeasePid
  pure (running || now < lease.runtimeLeaseExpiresAt)

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
