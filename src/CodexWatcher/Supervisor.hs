{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Supervisor
  ( WatcherServiceConfig (..)
  , renderLogrotateConfig
  , renderSystemdService
  , systemdQuote
  ) where

import Data.Char (isAlphaNum)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)

data WatcherServiceConfig = WatcherServiceConfig
  { serviceName :: Text
  , serviceDescription :: Text
  , serviceExecutable :: FilePath
  , serviceArguments :: [String]
  , serviceWorkingDirectory :: FilePath
  , serviceLogDirectory :: FilePath
  , serviceRestartSeconds :: Int
  , serviceLogRotateCount :: Int
  }
  deriving stock (Eq, Show, Generic)

renderSystemdService :: WatcherServiceConfig -> Text
renderSystemdService config =
  Text.unlines
    [ "[Unit]"
    , "Description=" <> config.serviceDescription
    , "After=network-online.target"
    , "Wants=network-online.target"
    , ""
    , "[Service]"
    , "Type=simple"
    , "WorkingDirectory=" <> Text.pack config.serviceWorkingDirectory
    , "ExecStart=" <> Text.unwords (systemdQuote <$> (config.serviceExecutable : config.serviceArguments))
    , "Restart=always"
    , "RestartSec=" <> Text.pack (show (max 1 config.serviceRestartSeconds))
    , "StandardOutput=append:" <> logPath ".log"
    , "StandardError=append:" <> logPath ".err.log"
    , ""
    , "[Install]"
    , "WantedBy=default.target"
    ]
 where
  logPath suffix = Text.pack config.serviceLogDirectory <> "/" <> config.serviceName <> suffix

renderLogrotateConfig :: WatcherServiceConfig -> Text
renderLogrotateConfig config =
  Text.unlines
    [ Text.pack config.serviceLogDirectory <> "/" <> config.serviceName <> "*.log {"
    , "  daily"
    , "  rotate " <> Text.pack (show (max 1 config.serviceLogRotateCount))
    , "  compress"
    , "  missingok"
    , "  notifempty"
    , "  copytruncate"
    , "}"
    ]

systemdQuote :: String -> Text
systemdQuote value
  | null value = "\"\""
  | all safeChar value = Text.pack value
  | otherwise = "\"" <> Text.concatMap quoteChar (Text.pack value) <> "\""
 where
  safeChar char =
    isAlphaNum char || char `elem` ("-_/.:=@+" :: String)
  quoteChar '"' = "\\\""
  quoteChar '\\' = "\\\\"
  quoteChar char = Text.singleton char
