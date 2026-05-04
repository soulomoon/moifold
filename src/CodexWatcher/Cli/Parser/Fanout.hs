{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Fanout
  ( issueFanoutParser
  ) where

import CodexWatcher.Cli.Parser.Common
  ( issueNumbersReader
  , maxParallelOption
  , optionalEndpointParser
  , pollSecondsOption
  , repoOption
  , textOptionDefault
  )
import CodexWatcher.Cli.Types (IssueFanoutCli (..))
import Options.Applicative

issueFanoutParser :: Parser IssueFanoutCli
issueFanoutParser =
  IssueFanoutCli
    <$> repoOption
    <*> strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root")
    <*> maxParallelOption "max-parallel" "N" "Maximum concurrent implementers"
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active"))
    <*> switch (long "execute" <> help "Write child watcher state instead of printing it")
    <*> optionalEndpointParser
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for child workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Child branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Child app-server thread prefix"
    <*> optional (pollSecondsOption "poll-seconds" "SECONDS" "Child polling interval")
