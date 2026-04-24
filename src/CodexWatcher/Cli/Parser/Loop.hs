{-# LANGUAGE OverloadedStrings #-}

module CodexWatcher.Cli.Parser.Loop
  ( loopParser
  ) where

import CodexWatcher.Cli.Parser.Common
  ( eventsPathOption
  , intOption
  , issueNumbersReader
  , plannerThreadOption
  , pollSecondsOption
  , pollSecondsOptionDefault
  , repoOption
  , requiredEndpointParser
  , scopeIssuesParser
  , stateDirOption
  , textOptionDefault
  , workdirOptionDefault
  )
import CodexWatcher.Cli.Types (LoopCli (..))
import CodexWatcher.Core.Kinds (Domain)
import Options.Applicative

loopParser :: Domain -> Parser LoopCli
loopParser domain =
  LoopCli
    <$> pure domain
    <*> eventsPathOption
    <*> stateDirOption
    <*> repoOption
    <*> workdirOptionDefault
    <*> requiredEndpointParser
    <*> pollSecondsOptionDefault "poll-seconds" 30 "SECONDS" "Polling interval for daemon loop"
    <*> switch (long "execute" <> help "Append observed events and execute compiled effects")
    <*> switch (long "loop" <> help "Continue polling until stopped")
    <*> optional (intOption "iterations" "N" "Maximum loop iterations")
    <*> optional (strOption (long "pid-file" <> metavar "PATH" <> help "Override daemon pid file"))
    <*> optional plannerThreadOption
    <*> scopeIssuesParser
    <*> optional (strOption (long "implementers-root" <> metavar "PATH" <> help "Issue implementer child state root"))
    <*> optional (option (issueNumbersReader "--open-issues") (long "open-issues" <> metavar "1,2" <> help "Open issue numbers to consider during planning fanout"))
    <*> optional (option (issueNumbersReader "--active-issues") (long "active-issues" <> metavar "1,2" <> help "Issue numbers already active during planning fanout"))
    <*> optional (strOption (long "implementer-workdir-root" <> metavar "PATH" <> help "Root for issue implementer child workdirs"))
    <*> optional (strOption (long "workdir-root" <> metavar "PATH" <> help "Root for generated workdirs"))
    <*> textOptionDefault "branch-prefix" "codex/issue-" "PREFIX" "Issue implementer branch prefix"
    <*> textOptionDefault "thread-prefix" "issue-worker-" "PREFIX" "Issue implementer thread prefix"
    <*> switch (long "start-children" <> help "Print or start child watcher loop commands after planning fanout")
    <*> optional (pollSecondsOption "child-poll-seconds" "SECONDS" "Child polling interval override")
