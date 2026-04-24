{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module CodexWatcher.WatcherPaths
  ( defaultEventsPath
  , defaultPidPath
  , defaultPidPathForKnownDomain
  , pidFileNameForDomain
  , pidFileNameForKnownDomain
  ) where

import CodexWatcher.Core.Types (Domain (..), KnownDomain, knownDomain, withDomain)
import Data.Proxy (Proxy (..))
import System.FilePath ((</>))

pidFileNameForDomain :: Domain -> FilePath
pidFileNameForDomain domain =
  withDomain domain pidFileNameForKnownDomain

pidFileNameForKnownDomain :: forall domain. KnownDomain domain => Proxy domain -> FilePath
pidFileNameForKnownDomain _ =
  case knownDomain @domain of
    PrReview -> "watcher.pid"
    IssueImplement -> "issue-watcher.pid"
    IssuePlanning -> "issue-planning-watcher.pid"

defaultPidPath :: Domain -> FilePath -> FilePath
defaultPidPath domain stateDir =
  stateDir </> pidFileNameForDomain domain

defaultPidPathForKnownDomain :: KnownDomain domain => Proxy domain -> FilePath -> FilePath
defaultPidPathForKnownDomain proxy stateDir =
  stateDir </> pidFileNameForKnownDomain proxy

defaultEventsPath :: FilePath -> FilePath
defaultEventsPath stateDir =
  stateDir </> "events.jsonl"
