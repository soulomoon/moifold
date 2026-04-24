{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Owner.Store
  ( readRuntimeOwner
  , readRuntimeOwnerMarker
  , runtimeLeaseJson
  , writeRuntimeLease
  ) where

import CodexWatcher.JsonPath (lookupPath)
import CodexWatcher.Runtime.File (readJsonValue)
import CodexWatcher.Runtime.Interpreter (RuntimeInterpreter (..))
import CodexWatcher.Runtime.Owner.Types
import Data.Aeson (Value (..), object, withObject, (.:), (.=))
import Data.Aeson.Types (parseEither)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesFileExist)
import System.FilePath ((</>))

runtimeLeaseJson :: RuntimeLease -> Value
runtimeLeaseJson lease =
  object
    [ "lease"
        .= object
          [ "runtime" .= runtimeOwnerText lease.runtimeLeaseOwner
          , "pid" .= lease.runtimeLeasePid
          , "hostname" .= lease.runtimeLeaseHost
          , "claimedAt" .= lease.runtimeLeaseClaimedAt
          , "expiresAt" .= lease.runtimeLeaseExpiresAt
          , "eventLogHeadHash" .= lease.runtimeLeaseEventLogHeadHash
          ]
    ]

writeRuntimeLease :: RuntimeInterpreter m -> FilePath -> RuntimeLease -> m ()
writeRuntimeLease interpreter stateDir lease =
  interpreter.runtimeWriteJsonValue (stateDir </> "runtime-owner.json") (runtimeLeaseJson lease)

readRuntimeOwner :: FilePath -> IO (Either Text (Maybe RuntimeOwner))
readRuntimeOwner stateDir = do
  marker <- readRuntimeOwnerMarker stateDir
  pure case marker of
    Left reason -> Left reason
    Right Nothing -> Right Nothing
    Right (Just (RuntimeOwnerLeased lease)) -> Right (Just lease.runtimeLeaseOwner)

readRuntimeOwnerMarker :: FilePath -> IO (Either Text (Maybe RuntimeOwnerMarker))
readRuntimeOwnerMarker stateDir = do
  let path = stateDir </> "runtime-owner.json"
  exists <- doesFileExist path
  if not exists
    then pure (Right Nothing)
    else do
      loaded <- readJsonValue path
      pure (loaded >>= runtimeOwnerMarkerFromJson)

runtimeOwnerMarkerFromJson :: Value -> Either Text (Maybe RuntimeOwnerMarker)
runtimeOwnerMarkerFromJson Null = Right Nothing
runtimeOwnerMarkerFromJson value@(Object _) =
  case lookupPath ["lease"] value of
    Just leaseValue -> Just . RuntimeOwnerLeased <$> runtimeLeaseFromJson leaseValue
    Nothing -> Left "runtime owner marker must contain a lease object"
runtimeOwnerMarkerFromJson _ =
  Left "runtime owner marker must be a JSON object"

runtimeLeaseFromJson :: Value -> Either Text RuntimeLease
runtimeLeaseFromJson value =
  case parseEither parser value of
    Left reason -> Left (Text.pack reason)
    Right lease -> Right lease
 where
  parser =
    withObject "RuntimeLease" \objectValue ->
      RuntimeLease
        <$> (objectValue .: "runtime" >>= either (fail . Text.unpack) pure . parseRuntimeOwner)
        <*> objectValue .: "pid"
        <*> objectValue .: "hostname"
        <*> objectValue .: "claimedAt"
        <*> objectValue .: "expiresAt"
        <*> objectValue .: "eventLogHeadHash"
