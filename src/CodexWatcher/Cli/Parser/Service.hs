{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Service
  ( renderServiceParser
  , stopDaemonParser
  ) where

import CodexWatcher.Cli.Parser.Common
  ( domainOption
  , eventsPathOption
  , intOptionDefault
  , plannerThreadOption
  , pollSecondsOptionDefault
  , repoOption
  , requiredEndpointParser
  , stateDirOption
  , textOption
  , workdirOption
  )
import CodexWatcher.Cli.Types (RenderServiceCli (..), StopDaemonCli (..))
import Options.Applicative

stopDaemonParser :: Parser StopDaemonCli
stopDaemonParser =
  StopDaemonCli
    <$> optional (strOption (long "pid-file" <> metavar "PATH" <> help "Explicit daemon pid file"))
    <*> optional stateDirOption
    <*> optional domainOption

renderServiceParser :: Parser RenderServiceCli
renderServiceParser =
  RenderServiceCli
    <$> textOption "name" "NAME" "Service name"
    <*> domainOption
    <*> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOption
    <*> requiredEndpointParser
    <*> optional (strOption (long "executable" <> metavar "PATH" <> help "Executable path to embed in the service"))
    <*> optional plannerThreadOption
    <*> pollSecondsOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> optional (strOption (long "log-dir" <> metavar "PATH" <> help "Directory for daemon logs"))
    <*> intOptionDefault "restart-seconds" 10 "SECONDS" "systemd restart delay"
    <*> intOptionDefault "rotate" 14 "COUNT" "logrotate retention count"
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
