module CodexWatcher.CliPaths
  ( defaultCliPidPath
  , cliPidFileName
  ) where

import CodexWatcher.Core.Kinds (Domain)
import CodexWatcher.Core.State (withDomain)
import CodexWatcher.WatcherPaths qualified as WatcherPaths

cliPidFileName :: Domain -> FilePath
cliPidFileName cliDomain =
  withDomain cliDomain WatcherPaths.pidFileNameForKnownDomain

defaultCliPidPath :: Domain -> FilePath -> FilePath
defaultCliPidPath cliDomain =
  withDomain cliDomain WatcherPaths.defaultPidPathForKnownDomain
