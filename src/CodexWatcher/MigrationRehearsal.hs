{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.MigrationRehearsal
  ( MigrationRehearsalPlan (..)
  , defaultRehearsalTarget
  , renderBackoutCommands
  , shouldCopyStateEntry
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.FilePath (takeFileName, (</>))

data MigrationRehearsalPlan = MigrationRehearsalPlan
  { rehearsalSourceStateDir :: FilePath
  , rehearsalTargetStateDir :: FilePath
  , rehearsalDomain :: String
  , rehearsalEventsPath :: FilePath
  , rehearsalServiceName :: Text
  }
  deriving stock (Eq, Show, Generic)

defaultRehearsalTarget :: FilePath -> FilePath -> FilePath
defaultRehearsalTarget rehearsalRoot sourceStateDir =
  rehearsalRoot </> takeFileName sourceStateDir

shouldCopyStateEntry :: FilePath -> Bool
shouldCopyStateEntry path =
  takeFileName path `notElem` excludedNames
 where
  excludedNames =
    [ "runtime-owner.json"
    , "watcher.pid"
    , "issue-watcher.pid"
    , "issue-planning-watcher.pid"
    , "daemon.log"
    , "daemon.err.log"
    ]

renderBackoutCommands :: FilePath -> String -> [Text]
renderBackoutCommands stateDir domain =
  [ "codex-watcher-hs stop-daemon --state-dir " <> quote (Text.pack stateDir) <> " --domain " <> Text.pack domain
  , "codex-watcher-hs mark-runtime-owner --state-dir " <> quote (Text.pack stateDir) <> " --owner node"
  ]

quote :: Text -> Text
quote value =
  "\"" <> Text.concatMap quoteChar value <> "\""
 where
  quoteChar '"' = "\\\""
  quoteChar '\\' = "\\\\"
  quoteChar char = Text.singleton char
