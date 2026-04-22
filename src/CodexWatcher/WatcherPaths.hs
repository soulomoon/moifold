{-# LANGUAGE LambdaCase #-}

module CodexWatcher.WatcherPaths
  ( defaultEventsPath
  , defaultPidPath
  , pidFileNameForDomain
  ) where

import CodexWatcher.Types (Domain (..))
import System.FilePath ((</>))

pidFileNameForDomain :: Domain -> FilePath
pidFileNameForDomain = \case
  PrReview -> "watcher.pid"
  IssueImplement -> "issue-watcher.pid"
  IssuePlanning -> "issue-planning-watcher.pid"

defaultPidPath :: Domain -> FilePath -> FilePath
defaultPidPath domain stateDir =
  stateDir </> pidFileNameForDomain domain

defaultEventsPath :: FilePath -> FilePath
defaultEventsPath stateDir =
  stateDir </> "events.jsonl"
