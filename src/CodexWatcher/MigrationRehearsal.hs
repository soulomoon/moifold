{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.MigrationRehearsal
  ( MigrationRehearsalPlan (..)
  , MigrationReadinessInput (..)
  , MigrationReadinessReport (..)
  , defaultRehearsalTarget
  , migrationReadinessReport
  , renderBackoutCommands
  , shouldCopyStateEntry
  ) where

import CodexWatcher.Migration (RuntimeOwner (..), runtimeOwnerText)
import CodexWatcher.Types (Domain)
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

data MigrationReadinessInput = MigrationReadinessInput
  { readinessSourceOwner :: Maybe RuntimeOwner
  , readinessTargetOwner :: Maybe RuntimeOwner
  , readinessOwnerProblems :: [Text]
  , readinessReplayDomain :: Maybe Domain
  , readinessExpectedDomain :: Domain
  , readinessReplayProblem :: Maybe Text
  , readinessTargetPidExists :: Bool
  }
  deriving stock (Eq, Show, Generic)

data MigrationReadinessReport = MigrationReadinessReport
  { migrationReady :: Bool
  , migrationProblems :: [Text]
  , migrationBackout :: [Text]
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
  ]

migrationReadinessReport :: FilePath -> String -> MigrationReadinessInput -> MigrationReadinessReport
migrationReadinessReport targetStateDir domain input =
  let problems =
        input.readinessOwnerProblems
          <> sourceOwnerProblems input.readinessSourceOwner
          <> targetOwnerProblems input.readinessTargetOwner
          <> replayProblems input
          <> [ "target daemon pid file exists; stop the target daemon before cutover validation"
             | input.readinessTargetPidExists
             ]
   in MigrationReadinessReport
        { migrationReady = null problems
        , migrationProblems = problems
        , migrationBackout = renderBackoutCommands targetStateDir domain
        }

sourceOwnerProblems :: Maybe RuntimeOwner -> [Text]
sourceOwnerProblems = \case
  Just HaskellRuntime ->
    ["source runtime-owner.json is haskell; source should remain node-owned or unmarked for side-by-side migration"]
  _ ->
    []

targetOwnerProblems :: Maybe RuntimeOwner -> [Text]
targetOwnerProblems = \case
  Just HaskellRuntime ->
    []
  Just owner ->
    ["target runtime-owner.json must be haskell, got " <> runtimeOwnerText owner]
  Nothing ->
    ["target runtime-owner.json must be haskell, but the marker is missing"]

replayProblems :: MigrationReadinessInput -> [Text]
replayProblems input =
  maybe [] (\problem -> ["target event replay failed: " <> problem]) input.readinessReplayProblem
    <> case input.readinessReplayDomain of
      Just actualDomain
        | actualDomain /= input.readinessExpectedDomain ->
            [ "target event log domain "
                <> Text.pack (show actualDomain)
                <> " does not match expected "
                <> Text.pack (show input.readinessExpectedDomain)
            ]
      Just _ ->
        []
      Nothing
        | input.readinessReplayProblem == Nothing ->
            ["target event replay did not produce a domain"]
      Nothing ->
        []

quote :: Text -> Text
quote value =
  "\"" <> Text.concatMap quoteChar value <> "\""
 where
  quoteChar '"' = "\\\""
  quoteChar '\\' = "\\\\"
  quoteChar char = Text.singleton char
