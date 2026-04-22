module CodexWatcher.CliPaths
  ( defaultCliPidPath
  , cliPidFileName
  ) where

import CodexWatcher.Cli (CliDomain, cliDomainToDomain)
import CodexWatcher.WatcherPaths qualified as WatcherPaths

cliPidFileName :: CliDomain -> FilePath
cliPidFileName =
  WatcherPaths.pidFileNameForDomain . cliDomainToDomain

defaultCliPidPath :: CliDomain -> FilePath -> FilePath
defaultCliPidPath cliDomain =
  WatcherPaths.defaultPidPath (cliDomainToDomain cliDomain)
