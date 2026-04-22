{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.JsonPath
  ( boolAtPath
  , decodeAtPath
  , decodeValue
  , lookupPath
  , renderedTextAtPath
  , textAtPath
  , valueText
  ) where

import Data.Aeson (FromJSON, Result (..), Value (..), fromJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text

lookupPath :: [Text] -> Value -> Maybe Value
lookupPath [] value = Just value
lookupPath (key : rest) (Object objectValue) = KeyMap.lookup (Key.fromText key) objectValue >>= lookupPath rest
lookupPath _ _ = Nothing

textAtPath :: [Text] -> Value -> Maybe Text
textAtPath path value =
  valueText =<< lookupPath path value

renderedTextAtPath :: [Text] -> Value -> Maybe Text
renderedTextAtPath path value =
  case lookupPath path value of
    Just (String text) -> Just text
    Just other -> Just (Text.pack (show other))
    Nothing -> Nothing

boolAtPath :: [Text] -> Value -> Maybe Bool
boolAtPath path value =
  case lookupPath path value of
    Just (Bool bool) -> Just bool
    _ -> Nothing

decodeAtPath :: FromJSON a => [Text] -> Value -> Either Text a
decodeAtPath path value =
  maybe (Left ("missing JSON path: " <> Text.intercalate "." path)) decodeValue (lookupPath path value)

decodeValue :: FromJSON a => Value -> Either Text a
decodeValue value =
  case fromJSON value of
    Error errorMessage -> Left (Text.pack errorMessage)
    Success parsed -> Right parsed

valueText :: Value -> Maybe Text
valueText (String text) = Just text
valueText _ = Nothing
