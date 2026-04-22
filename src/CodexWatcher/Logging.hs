{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Logging
  ( WatcherLog (..)
  , WatcherLogLevel (..)
  , WatcherLogger
  , jsonLineWatcherLogger
  , logTextValue
  , logWatcher
  , noopWatcherLogger
  , redactLogText
  , watcherLog
  , watcherLogJson
  , watcherLogJsonLine
  , watcherLogLevelText
  , watcherLoggerFromFunction
  ) where

import Colog.Core (LogAction (..))
import Data.Aeson (ToJSON (..), Value (..), encode, object, (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Pair)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time.Clock (UTCTime, getCurrentTime)
import GHC.Generics (Generic)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)

data WatcherLogLevel
  = Debug
  | Info
  | Warn
  | Error
  deriving stock (Eq, Show, Generic)

data WatcherLog = WatcherLog
  { watcherLogLevel :: WatcherLogLevel
  , watcherLogEvent :: Text
  , watcherLogMessage :: Text
  , watcherLogContext :: Value
  }
  deriving stock (Eq, Show, Generic)

type WatcherLogger m = LogAction m WatcherLog

watcherLog :: WatcherLogLevel -> Text -> Text -> [Pair] -> WatcherLog
watcherLog level event message contextFields =
  WatcherLog
    { watcherLogLevel = level
    , watcherLogEvent = event
    , watcherLogMessage = message
    , watcherLogContext = sanitizeValue (object contextFields)
    }

watcherLoggerFromFunction :: (WatcherLog -> m ()) -> WatcherLogger m
watcherLoggerFromFunction =
  LogAction

noopWatcherLogger :: Applicative m => WatcherLogger m
noopWatcherLogger =
  LogAction \_ -> pure ()

logWatcher :: WatcherLogger m -> WatcherLog -> m ()
logWatcher logger =
  unLogAction logger

jsonLineWatcherLogger :: FilePath -> WatcherLogger IO
jsonLineWatcherLogger path =
  LogAction \entry -> do
    createDirectoryIfMissing True (takeDirectory path)
    timestamp <- getCurrentTime
    LazyByteString.appendFile path (watcherLogJsonLine timestamp entry)

watcherLogJsonLine :: UTCTime -> WatcherLog -> LazyByteString.ByteString
watcherLogJsonLine timestamp entry =
  encode (watcherLogJson timestamp entry) <> "\n"

watcherLogJson :: UTCTime -> WatcherLog -> Value
watcherLogJson timestamp entry =
  object
    [ "timestamp" .= timestamp
    , "severity" .= watcherLogLevelText entry.watcherLogLevel
    , "event" .= entry.watcherLogEvent
    , "message" .= entry.watcherLogMessage
    , "context" .= sanitizeValue entry.watcherLogContext
    ]

watcherLogLevelText :: WatcherLogLevel -> Text
watcherLogLevelText = \case
  Debug -> "debug"
  Info -> "info"
  Warn -> "warn"
  Error -> "error"

instance ToJSON WatcherLogLevel where
  toJSON =
    String . watcherLogLevelText

logTextValue :: Text -> Value
logTextValue =
  String . redactLogText

redactLogText :: Text -> Text
redactLogText =
  capLogText . Text.unwords . fmap redactWord . Text.words
 where
  redactWord word
    | any (`Text.isInfixOf` word) tokenPrefixes = "<redacted-token>"
    | otherwise = word

  tokenPrefixes =
    ["ghp_", "github_pat_", "gho_", "ghu_", "ghs_", "ghr_"]

capLogText :: Text -> Text
capLogText text
  | Text.length text <= maxLogTextLength = text
  | otherwise = Text.take maxLogTextLength text <> "...<truncated>"

maxLogTextLength :: Int
maxLogTextLength = 2048

sanitizeValue :: Value -> Value
sanitizeValue = \case
  Object objectValue ->
    Object (KeyMap.map sanitizeValue objectValue)
  Array arrayValue ->
    Array (fmap sanitizeValue arrayValue)
  String text ->
    logTextValue text
  value ->
    value
