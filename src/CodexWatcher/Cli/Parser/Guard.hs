{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Guard
  ( guardIssuePlanningParser
  , guardWatcherParser
  ) where

import CodexWatcher.Cli.Parser.Common (pollSecondsOptionDefault, staleSecondsOptionDefault)
import CodexWatcher.Cli.Parser.Loop (loopParser)
import CodexWatcher.Cli.Types (GuardWatcherCli (..))
import CodexWatcher.Core.Types (Domain (..))
import Options.Applicative

guardIssuePlanningParser :: Parser GuardWatcherCli
guardIssuePlanningParser =
  guardWatcherParser IssuePlanning

guardWatcherParser :: Domain -> Parser GuardWatcherCli
guardWatcherParser domain =
  GuardWatcherCli
    <$> loopParser domain
    <*> optional (strOption (long "guard-pid-file" <> metavar "PATH" <> help "Runner guard pid file"))
    <*> pollSecondsOptionDefault "guard-poll-seconds" 60 "SECONDS" "Runner guard polling interval"
    <*> staleSecondsOptionDefault "stale-seconds" 1800 "SECONDS" "Maximum event-log idle time before guard triggers repair"
    <*> optional (strOption (long "repair-cwd" <> metavar "PATH" <> help "Repository cwd for the repair thread"))
