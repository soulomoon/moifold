{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Runtime.Owner.Types
  ( RuntimeLease (..)
  , RuntimeOwner (..)
  , RuntimeOwnerMarker (..)
  , parseRuntimeOwner
  , runtimeOwnerText
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)

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
  = RuntimeOwnerLeased RuntimeLease
  deriving stock (Eq, Show, Generic)

runtimeOwnerText :: RuntimeOwner -> Text
runtimeOwnerText = \case
  HaskellRuntime -> "haskell"

parseRuntimeOwner :: Text -> Either Text RuntimeOwner
parseRuntimeOwner owner =
  case Text.toLower (Text.strip owner) of
    "haskell" -> Right HaskellRuntime
    other -> Left ("unsupported runtime owner: " <> other <> "; expected haskell")
