{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module CodexWatcher.Runtime.Json
  ( commandJsonValue
  , decodeJsonText
  , parseCommandJson
  ) where

import CodexWatcher.Runtime (CommandReport (..), commandText)
import Data.Aeson (FromJSON, Value, eitherDecodeStrict')
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text.Encoding

commandJsonValue :: CommandReport -> Either Text Value
commandJsonValue report =
  decodeJsonText "command stdout" report.stdout

parseCommandJson :: (Text -> Either Text a) -> CommandReport -> Either Text a
parseCommandJson parser report
  | report.ok = parser report.stdout
  | otherwise = Left (commandText report)

decodeJsonText :: FromJSON a => Text -> Text -> Either Text a
decodeJsonText label text =
  case eitherDecodeStrict' (Text.Encoding.encodeUtf8 text) of
    Left errorMessage -> Left (label <> " JSON decode failed: " <> Text.pack errorMessage)
    Right value -> Right value
