{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RuntimeOwner
  ( RuntimeOwner (..)
  , RuntimeOwnerMarker (..)
  , RuntimeLease (..)
  , parseRuntimeOwner
  , readRuntimeOwnerMarker
  , readRuntimeOwner
  , runtimeLeaseJson
  , runtimeOwnerJson
  , runtimeOwnerText
  , writeRuntimeLease
  , writeRuntimeOwner
  ) where

import CodexWatcher.Runtime
import CodexWatcher.JsonPath (lookupPath)
import Data.Aeson (Value (..), object, withObject, (.:), (.=))
import Data.Aeson.Types (parseEither)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import System.Directory (doesFileExist)
import System.FilePath ((</>))

data RuntimeOwner
  = HaskellRuntime
  deriving stock (Eq, Show, Generic)

data RuntimeLease = RuntimeLease
  { runtimeLeaseOwner :: RuntimeOwner
  , runtimeLeasePid :: Text
  , runtimeLeaseHost :: Text
  , runtimeLeaseClaimedAt :: UTCTime
  , runtimeLeaseExpiresAt :: UTCTime
  , runtimeLeaseEventLogHeadHash :: Text
  }
  deriving stock (Eq, Show, Generic)

data RuntimeOwnerMarker
  = RuntimeOwnerLegacy RuntimeOwner
  | RuntimeOwnerLeased RuntimeLease
  deriving stock (Eq, Show, Generic)

runtimeOwnerText :: RuntimeOwner -> Text
runtimeOwnerText = \case
  HaskellRuntime -> "haskell"

parseRuntimeOwner :: Text -> Either Text RuntimeOwner
parseRuntimeOwner owner =
  case Text.toLower (Text.strip owner) of
    "haskell" -> Right HaskellRuntime
    other -> Left ("unsupported runtime owner: " <> other <> "; expected haskell")

runtimeOwnerJson :: RuntimeOwner -> Value
runtimeOwnerJson owner =
  object ["owner" .= runtimeOwnerText owner]

runtimeLeaseJson :: RuntimeLease -> Value
runtimeLeaseJson lease =
  object
    [ "owner" .= runtimeOwnerText lease.runtimeLeaseOwner
    , "lease"
        .= object
          [ "pid" .= lease.runtimeLeasePid
          , "hostname" .= lease.runtimeLeaseHost
          , "claimedAt" .= lease.runtimeLeaseClaimedAt
          , "expiresAt" .= lease.runtimeLeaseExpiresAt
          , "eventLogHeadHash" .= lease.runtimeLeaseEventLogHeadHash
          ]
    ]

writeRuntimeOwner :: RuntimeInterpreter m -> FilePath -> RuntimeOwner -> m ()
writeRuntimeOwner interpreter stateDir owner =
  interpreter.runtimeWriteJsonValue (stateDir </> "runtime-owner.json") (runtimeOwnerJson owner)

writeRuntimeLease :: RuntimeInterpreter m -> FilePath -> RuntimeLease -> m ()
writeRuntimeLease interpreter stateDir lease =
  interpreter.runtimeWriteJsonValue (stateDir </> "runtime-owner.json") (runtimeLeaseJson lease)

readRuntimeOwner :: FilePath -> IO (Either Text (Maybe RuntimeOwner))
readRuntimeOwner stateDir = do
  marker <- readRuntimeOwnerMarker stateDir
  pure case marker of
    Left reason -> Left reason
    Right Nothing -> Right Nothing
    Right (Just (RuntimeOwnerLegacy owner)) -> Right (Just owner)
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
  case lookupPath ["owner"] value of
    Nothing -> Right Nothing
    Just (String ownerText') -> do
      owner <- parseRuntimeOwner ownerText'
      case lookupPath ["lease"] value of
        Nothing -> Right (Just (RuntimeOwnerLegacy owner))
        Just leaseValue -> Just . RuntimeOwnerLeased <$> runtimeLeaseFromJson owner leaseValue
    Just _ -> Left "runtime owner field must be a string"
runtimeOwnerMarkerFromJson _ =
  Left "runtime owner marker must be a JSON object"

runtimeLeaseFromJson :: RuntimeOwner -> Value -> Either Text RuntimeLease
runtimeLeaseFromJson owner value =
  case parseEither parser value of
    Left reason -> Left (Text.pack reason)
    Right lease -> Right lease
 where
  parser =
    withObject "RuntimeLease" \objectValue ->
      RuntimeLease
        <$> pure owner
        <*> objectValue .: "pid"
        <*> objectValue .: "hostname"
        <*> objectValue .: "claimedAt"
        <*> objectValue .: "expiresAt"
        <*> objectValue .: "eventLogHeadHash"
