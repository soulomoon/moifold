{-# LANGUAGE OverloadedStrings #-}

module JsonPathSpec
  ( prop_jsonPathHelpersDecodeNestedValues
  ) where

import CodexWatcher.JsonPath qualified as JsonPath
import Data.Aeson (object, (.=))
import Data.Text (Text)

prop_jsonPathHelpersDecodeNestedValues :: Bool
prop_jsonPathHelpersDecodeNestedValues =
  let value = object ["root" .= object ["name" .= ("watcher" :: Text), "ready" .= True]]
   in JsonPath.textAtPath ["root", "name"] value == Just "watcher"
        && JsonPath.boolAtPath ["root", "ready"] value == Just True
        && (JsonPath.decodeAtPath ["root", "name"] value :: Either Text Text) == Right "watcher"
