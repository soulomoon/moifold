{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.RuntimeOwner
  ( RuntimeOwner (..)
  , parseRuntimeOwner
  , readRuntimeOwner
  , runtimeOwnerJson
  , runtimeOwnerText
  , writeRuntimeOwner
  ) where

import CodexWatcher.Runtime
import CodexWatcher.JsonPath (lookupPath)
import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Directory (doesFileExist)
import System.FilePath ((</>))

data RuntimeOwner
  = HaskellRuntime
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

writeRuntimeOwner :: RuntimeInterpreter m -> FilePath -> RuntimeOwner -> m ()
writeRuntimeOwner interpreter stateDir owner =
  interpreter.runtimeWriteJsonValue (stateDir </> "runtime-owner.json") (runtimeOwnerJson owner)

readRuntimeOwner :: FilePath -> IO (Either Text (Maybe RuntimeOwner))
readRuntimeOwner stateDir = do
  let path = stateDir </> "runtime-owner.json"
  exists <- doesFileExist path
  if not exists
    then pure (Right Nothing)
    else do
      loaded <- readJsonValue path
      pure (loaded >>= runtimeOwnerFromJson)

runtimeOwnerFromJson :: Value -> Either Text (Maybe RuntimeOwner)
runtimeOwnerFromJson Null = Right Nothing
runtimeOwnerFromJson value@(Object _) =
  case lookupPath ["owner"] value of
    Nothing -> Right Nothing
    Just (String owner) -> Just <$> parseRuntimeOwner owner
    Just _ -> Left "runtime owner field must be a string"
runtimeOwnerFromJson _ =
  Left "runtime owner marker must be a JSON object"
