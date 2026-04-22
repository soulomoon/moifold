{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Migration
  ( RuntimeOwner (..)
  , parseRuntimeOwner
  , runtimeOwnerJson
  , runtimeOwnerText
  , writeRuntimeOwner
  ) where

import CodexWatcher.Runtime
import Data.Aeson (Value, object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.FilePath ((</>))

data RuntimeOwner
  = NodeRuntime
  | HaskellRuntime
  deriving stock (Eq, Show, Generic)

runtimeOwnerText :: RuntimeOwner -> Text
runtimeOwnerText = \case
  NodeRuntime -> "node"
  HaskellRuntime -> "haskell"

parseRuntimeOwner :: Text -> Either Text RuntimeOwner
parseRuntimeOwner owner =
  case Text.toLower (Text.strip owner) of
    "node" -> Right NodeRuntime
    "haskell" -> Right HaskellRuntime
    other -> Left ("unsupported runtime owner: " <> other)

runtimeOwnerJson :: RuntimeOwner -> Value
runtimeOwnerJson owner =
  object ["owner" .= runtimeOwnerText owner]

writeRuntimeOwner :: RuntimeInterpreter m -> FilePath -> RuntimeOwner -> m ()
writeRuntimeOwner interpreter stateDir owner =
  interpreter.runtimeWriteJsonValue (stateDir </> "runtime-owner.json") (runtimeOwnerJson owner)
