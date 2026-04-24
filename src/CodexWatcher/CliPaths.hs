module CodexWatcher.CliPaths
  ( defaultCliPidPath
  , cliPidFileName
  ) where

import CodexWatcher.Core.Types (Domain, withDomain)
import CodexWatcher.WatcherPaths qualified as WatcherPaths

cliPidFileName :: Domain -> FilePath
cliPidFileName cliDomain =
  withDomain cliDomain WatcherPaths.pidFileNameForKnownDomain

defaultCliPidPath :: Domain -> FilePath -> FilePath
defaultCliPidPath cliDomain =
  withDomain cliDomain WatcherPaths.defaultPidPathForKnownDomain
